// 角色：管「同步資料夾」的管家。
// 1. 記住使用者選的資料夾（存 bookmark，下次開 App 不用重選）
// 2. 讀 snapshot.json：透過 NSFileCoordinator 讀，雲端硬碟（如 Google 雲端硬碟）
//    的檔案若還沒下載到手機，系統會先下載再交給我們
// 3. 手動記帳：在 entries.json 陣列尾端追加一筆紀錄；同時讀回全部紀錄給畫面顯示
// 出錯時把系統錯誤原文（domain／code／說明）顯示出來，方便實機除錯。
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
    @Published var entries: [Entry] = []
    @Published var message: String?
    @Published var isError = false
    @Published var busy = false

    private let bookmarkKey = "folderBookmark"

    init() {
        if let url = try? resolveFolder() {
            folderName = url.lastPathComponent
        }
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
            self.showInfo("讀取完成")
        })
    }

    struct LoadResult {
        let snapshot: Snapshot
        let entries: [Entry]
    }

    // MARK: - 手動記帳

    /// 新增一筆記帳；寫完後 onDone 會在主執行緒被呼叫（成功與否都會）
    func addEntry(_ entry: Entry, onDone: @escaping (Bool) -> Void) {
        let folder: URL
        do {
            folder = try resolveFolder()
        } catch {
            showError(error)
            onDone(false)
            return
        }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = folder.startAccessingSecurityScopedResource()
            let result = Result<[Entry], Error>(catching: { () throws -> [Entry] in
                let url = folder.appendingPathComponent("entries.json")
                try FolderStore.appendEntry(url, entry: entry)
                return try FolderStore.readEntries(url)
            })
            if ok { folder.stopAccessingSecurityScopedResource() }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success(let list):
                    self.entries = list
                    self.showInfo("已寫入 entries.json（共 \(list.count) 筆）")
                    onDone(true)
                case .failure(let error):
                    self.showError(error)
                    onDone(false)
                }
            }
        }
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
        DispatchQueue.global(qos: .userInitiated).async {
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

    /// 在陣列尾端追加一筆；用原始 JSON 物件讀寫，電腦端寫的其他欄位原樣保留
    static func appendEntry(_ url: URL, entry: Entry) throws {
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
                list.append(entry.toJSON())
                let out = try JSONSerialization.data(withJSONObject: list, options: [.prettyPrinted, .sortedKeys])
                // 不用 .atomic：原子寫入是「寫暫存檔再換名」，雲端硬碟可能當成刪檔＋新檔兩個動作同步
                try out.write(to: writeURL, options: [])
            })
        }
        if let coordError = coordError {
            throw coordError
        }
        try result.get()
    }

    private func showInfo(_ text: String) {
        message = text
        isError = false
    }

    func showError(_ error: Error) {
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
