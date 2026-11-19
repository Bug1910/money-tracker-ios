// 角色：管「同步資料夾」的管家。
// 1. 記住使用者選的資料夾（存 bookmark，下次開 App 不用重選）
// 2. 讀 snapshot.json：透過 NSFileCoordinator 讀，雲端硬碟（如 Google 雲端硬碟）
//    的檔案若還沒下載到手機，系統會先下載再交給我們
// 3. 手動記帳（v6）：先存進手機本機的「待寫入佇列」（pending_entries.json，App 私有資料夾），
//    再嘗試追加到雲端資料夾的 entries.json；寫失敗（沒選資料夾、雲端沒同步）佇列不動，下次開 App／讀取時自動重試，所以資料不會丟。
//    寫入以 id 去重，重複補寫不會記兩次。
// 4. 刪除／復原：只動「還沒被電腦配對」的筆；寫入全部排在同一條序列佇列，不會互相踩。
// 出錯時把系統錯誤原文（domain／code／說明）放在設定頁，方便實機除錯。
import Foundation

enum FolderError: LocalizedError {
    case noFolder
    case notArray

    var errorDescription: String? {
        switch self {
        case .noFolder: return "尚未選擇資料夾"
        case .notArray: return "entries.json 內容不是陣列，未寫入"
        }
    }
}

final class FolderStore: ObservableObject {
    @Published var folderName: String?
    @Published var snapshot: Snapshot?
    @Published var readAt: Date?
    /// entries.json 目前的內容
    @Published var entries: [Entry] = []
    /// 手機本機待寫入佇列（還沒進雲端資料夾的記帳）
    @Published var pending: [Entry] = []
    /// 記帳／補寫的白話提示（nil ＝ 一切正常）
    @Published var notice: String?
    /// 剛刪掉的那一筆，畫面顯示「復原」用
    @Published var lastRemoved: Entry?
    @Published var message: String?
    @Published var isError = false
    @Published var busy = false

    private let bookmarkKey = "folderBookmark"
    /// 所有讀寫資料夾的動作都排這條序列佇列，避免同時改同一個檔
    private let ioQueue = DispatchQueue(label: "app.folder.io", qos: .userInitiated)
    private var flushing = false

    init() {
        if let url = try? resolveFolder() {
            folderName = url.lastPathComponent
        }
        pending = FolderStore.loadPending()
    }

    /// 畫面用的記帳清單：entries.json ＋ 還在佇列裡的（佇列裡已被寫進檔案的不重複算）
    var visibleEntries: [Entry] {
        let ids: Set<String> = Set(entries.map { (e: Entry) -> String in e.id })
        return entries + pending.filter { (e: Entry) -> Bool in !ids.contains(e.id) }
    }

    func isPending(_ entry: Entry) -> Bool {
        return pending.contains(where: { (e: Entry) -> Bool in e.id == entry.id })
    }

    // MARK: - 選資料夾

    func setFolder(_ url: URL) {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        do {
            // iOS 的 bookmark 不需要 .withSecurityScope（那是 macOS 專用）
            let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            folderName = url.lastPathComponent
            snapshot = nil
            readAt = nil
            AppLog.write("選擇資料夾")
            showInfo("已選擇資料夾")
        } catch {
            showError(error)
            return
        }
        reload()
    }

    private func resolveFolder() throws -> URL {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            throw FolderError.noFolder
        }
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            // 過期的 bookmark 這一次還能用，順手換一份新的
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(fresh, forKey: bookmarkKey)
            }
        }
        return url
    }

    // MARK: - 讀取

    func reload() {
        AppLog.write("讀取開始")
        run(work: { (folder: URL) -> LoadResult in
            let data = try FolderStore.coordinatedRead(folder.appendingPathComponent("snapshot.json"))
            let snap = try JSONDecoder().decode(Snapshot.self, from: data)
            // entries.json 還不存在（沒記過帳）是正常狀況，當成空的
            let list: [Entry] = (try? FolderStore.readEntries(folder.appendingPathComponent("entries.json"))) ?? []
            return LoadResult(snapshot: snap, entries: list)
        }, success: { (result: LoadResult) -> Void in
            self.snapshot = result.snapshot
            self.entries = result.entries
            self.readAt = Date()
            AppLog.write("讀取完成 記帳筆數 " + String(result.entries.count))
            self.showInfo("讀取完成")
            self.flushPending()
        })
    }

    struct LoadResult {
        let snapshot: Snapshot
        let entries: [Entry]
    }

    // MARK: - 手動記帳（先進本機佇列，再補寫雲端）

    /// 記一筆。立刻回傳（畫面可以馬上顯示成功）；寫雲端資料夾在背景做，失敗會留在佇列等下次。
    @discardableResult
    func record(amount: Int, necessary: Bool, category: String, note: String, date: Date) -> Entry {
        let now = Date()
        let entry = Entry(
            id: UUID().uuidString,
            amount: Double(amount),
            necessary: necessary,
            date: Formats.dayString(date),
            createdAt: Formats.stampString(now),
            matched: false,
            category: category,
            note: note
        )
        pending.append(entry)
        FolderStore.savePending(pending)
        AppLog.write("記帳加入佇列 佇列 " + String(pending.count) + " 筆")
        flushPending()
        return entry
    }

    /// 把佇列裡的記帳寫進 entries.json；失敗就留著，下次再試
    func flushPending() {
        if pending.isEmpty || flushing { return }
        let folder: URL
        do {
            folder = try resolveFolder()
        } catch {
            notice = "尚未選擇資料夾，已先存在手機。到「設定」選好資料夾後會自動補寫。"
            return
        }
        flushing = true
        let batch: [Entry] = pending
        ioQueue.async {
            let ok = folder.startAccessingSecurityScopedResource()
            let result = Result<[Entry], Error>(catching: { () throws -> [Entry] in
                let url = folder.appendingPathComponent("entries.json")
                try FolderStore.appendEntries(url, entries: batch)
                return try FolderStore.readEntries(url)
            })
            if ok { folder.stopAccessingSecurityScopedResource() }
            DispatchQueue.main.async {
                self.flushing = false
                switch result {
                case .success(let list):
                    let done: Set<String> = Set(batch.map { (e: Entry) -> String in e.id })
                    self.pending.removeAll(where: { (e: Entry) -> Bool in done.contains(e.id) })
                    FolderStore.savePending(self.pending)
                    self.entries = list
                    self.notice = nil
                    AppLog.write("記帳寫入完成 共 " + String(list.count) + " 筆")
                    if !self.pending.isEmpty { self.flushPending() }
                case .failure(let error):
                    AppLog.writeError("記帳寫入", error)
                    self.notice = "雲端資料夾暫時寫不進去，已先存在手機，之後會自動補寫。"
                }
            }
        }
    }

    // MARK: - 刪除／復原

    /// 刪掉一筆（只限還沒被電腦配對的）；lastRemoved 會留著給「復原」
    func remove(_ entry: Entry) {
        if let snap = snapshot, snap.isMatched(entry) { return }
        if entry.matched { return }
        lastRemoved = entry
        if isPending(entry) {
            pending.removeAll(where: { (e: Entry) -> Bool in e.id == entry.id })
            FolderStore.savePending(pending)
        }
        let before: [Entry] = entries
        entries.removeAll(where: { (e: Entry) -> Bool in e.id == entry.id })
        AppLog.write("刪除一筆記帳")
        guard let folder = try? resolveFolder() else { return }
        let target: String = entry.id
        ioQueue.async {
            let ok = folder.startAccessingSecurityScopedResource()
            let result = Result<[Entry], Error>(catching: { () throws -> [Entry] in
                let url = folder.appendingPathComponent("entries.json")
                if FileManager.default.fileExists(atPath: url.path) {
                    try FolderStore.removeEntry(url, id: target)
                }
                return try FolderStore.readEntries(url)
            })
            if ok { folder.stopAccessingSecurityScopedResource() }
            DispatchQueue.main.async {
                switch result {
                case .success(let list):
                    self.entries = list
                case .failure(let error):
                    AppLog.writeError("刪除記帳", error)
                    self.entries = before
                    self.lastRemoved = nil
                    self.notice = "刪除沒有成功，雲端資料夾暫時寫不進去，請稍後再試。"
                }
            }
        }
    }

    /// 復原剛刪的那一筆（同一個 id 放回佇列再補寫；寫入以 id 去重）
    func undoRemove() {
        guard let entry = lastRemoved else { return }
        lastRemoved = nil
        if !pending.contains(where: { (e: Entry) -> Bool in e.id == entry.id }) {
            pending.append(entry)
            FolderStore.savePending(pending)
        }
        AppLog.write("復原一筆記帳")
        flushPending()
    }

    // MARK: - 共用

    /// 在背景執行緒開啟資料夾權限做事，做完回主執行緒更新畫面。
    private func run<T>(work: @escaping (URL) throws -> T, success: @escaping (T) -> Void) {
        let folder: URL
        do {
            folder = try resolveFolder()
        } catch {
            showError(error)
            return
        }
        busy = true
        ioQueue.async {
            let ok = folder.startAccessingSecurityScopedResource()
            let result = Result<T, Error>(catching: { try work(folder) })
            if ok { folder.stopAccessingSecurityScopedResource() }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success(let value): success(value)
                case .failure(let error): self.showError(error)
                }
            }
        }
    }

    static func coordinatedRead(_ url: URL) throws -> Data {
        var coordError: NSError?
        var result = Result<Data, Error>.failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            result = Result<Data, Error>(catching: { try Data(contentsOf: readURL) })
        }
        if let coordError = coordError {
            throw coordError
        }
        return try result.get()
    }

    static func readEntries(_ url: URL) throws -> [Entry] {
        let data = try coordinatedRead(url)
        if data.isEmpty { return [] }
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let array = object as? [Any] else { throw FolderError.notArray }
        var list: [Entry] = []
        for item in array {
            if let entry = Entry.fromJSON(item) { list.append(entry) }
        }
        return list
    }

    /// 讀出 entries.json 的原始陣列、交給 transform 改、再寫回。
    /// 用原始 JSON 物件讀寫，電腦端寫的其他欄位原樣保留；檔案不存在當空陣列。
    static func updateEntriesFile(_ url: URL, transform: ([Any]) -> [Any]) throws {
        var coordError: NSError?
        var result = Result<Void, Error>.failure(CocoaError(.fileWriteUnknown))
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forMerging, error: &coordError) { writeURL in
            result = Result<Void, Error>(catching: { () throws -> Void in
                var list: [Any] = []
                if FileManager.default.fileExists(atPath: writeURL.path) {
                    let data = try Data(contentsOf: writeURL)
                    if !data.isEmpty {
                        let object = try JSONSerialization.jsonObject(with: data, options: [])
                        guard let array = object as? [Any] else { throw FolderError.notArray }
                        list = array
                    }
                }
                let changed: [Any] = transform(list)
                let out = try JSONSerialization.data(withJSONObject: changed, options: [.prettyPrinted, .sortedKeys])
                // 不用 .atomic：原子寫入是「寫暫存檔再換名」，雲端硬碟可能當成刪檔＋新檔兩個動作同步
                try out.write(to: writeURL, options: [])
            })
        }
        if let coordError = coordError {
            throw coordError
        }
        try result.get()
    }

    private static func idOf(_ item: Any) -> String? {
        guard let dict = item as? [String: Any] else { return nil }
        return dict["id"] as? String
    }

    /// 在陣列尾端追加；檔案裡已有同 id 的就跳過（補寫不會重複）
    static func appendEntries(_ url: URL, entries: [Entry]) throws {
        try updateEntriesFile(url, transform: { (list: [Any]) -> [Any] in
            var out: [Any] = list
            var seen: Set<String> = []
            for item in list {
                if let existing = FolderStore.idOf(item) { seen.insert(existing) }
            }
            for entry in entries {
                if seen.contains(entry.id) { continue }
                out.append(entry.toJSON())
                seen.insert(entry.id)
            }
            return out
        })
    }

    /// 刪掉同 id 且還沒被電腦配對（matched 不是 true）的那一筆
    static func removeEntry(_ url: URL, id: String) throws {
        try updateEntriesFile(url, transform: { (list: [Any]) -> [Any] in
            return list.filter { (item: Any) -> Bool in
                guard let dict = item as? [String: Any], (dict["id"] as? String) == id else { return true }
                return (dict["matched"] as? Bool) == true
            }
        })
    }

    // MARK: - 本機待寫入佇列（App 私有資料夾，不進雲端）

    private static var pendingURL: URL {
        let base: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("pending_entries.json")
    }

    static func loadPending() -> [Entry] {
        guard let data = try? Data(contentsOf: pendingURL), !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let array = object as? [Any] else { return [] }
        var list: [Entry] = []
        for item in array {
            if let entry = Entry.fromJSON(item) { list.append(entry) }
        }
        return list
    }

    static func savePending(_ list: [Entry]) {
        let url: URL = pendingURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            let array: [Any] = list.map { (e: Entry) -> Any in e.toJSON() }
            let data = try JSONSerialization.data(withJSONObject: array, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: [])
        } catch {
            AppLog.writeError("存佇列", error)
        }
    }

    private func showInfo(_ text: String) {
        message = text
        isError = false
    }

    func showError(_ error: Error) {
        AppLog.writeError("操作失敗", error)
        let ns = error as NSError
        var text = "\(ns.domain) \(ns.code)\n\(ns.localizedDescription)"
        if let under = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            text += "\n底層：\(under.domain) \(under.code) \(under.localizedDescription)"
        }
        if error is DecodingError {
            text += "\n\(error)"
        }
        message = text
        isError = true
    }
}
