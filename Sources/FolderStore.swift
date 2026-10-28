// 角色：管「同步資料夾」的管家。
// 1. 記住使用者選的資料夾（存 bookmark，下次開 App 不用重選）
// 2. 讀 snapshot.json：透過 NSFileCoordinator 讀，雲端硬碟（如 Google 雲端硬碟）
//    的檔案若還沒下載到手機，系統會先下載再交給我們
// 3. 寫入測試：在 entries.json 陣列尾端追加一筆 1 元的測試紀錄
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
        run(work: { (folder: URL) -> Snapshot in
            let data = try FolderStore.coordinatedRead(folder.appendingPathComponent("snapshot.json"))
            return try JSONDecoder().decode(Snapshot.self, from: data)
        }, success: { snap in
            self.snapshot = snap
            self.readAt = Date()
            self.showInfo("讀取完成")
        })
    }

    // MARK: - 寫入測試

    func writeTest() {
        run(work: { folder in
            try FolderStore.appendTestEntry(folder.appendingPathComponent("entries.json"))
        }, success: { count in
            self.showInfo("已寫入 entries.json（共 \(count) 筆）")
        })
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

    static func appendTestEntry(_ url: URL) throws -> Int {
        var coordError: NSError?
        var result = Result<Int, Error>.failure(CocoaError(.fileWriteUnknown))
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forMerging, error: &coordError) { writeURL in
            result = Result<Int, Error>(catching: {
                var list: [Any] = []
                if FileManager.default.fileExists(atPath: writeURL.path) {
                    let data = try Data(contentsOf: writeURL)
                    if !data.isEmpty {
                        let object = try JSONSerialization.jsonObject(with: data, options: [])
                        guard let array = object as? [Any] else { throw FolderError.notArray }
                        list = array
                    }
                }
                list.append(FolderStore.makeTestEntry())
                let out = try JSONSerialization.data(withJSONObject: list, options: [.prettyPrinted, .sortedKeys])
                // 不用 .atomic：原子寫入是「寫暫存檔再換名」，雲端硬碟可能當成刪檔＋新檔兩個動作同步
                try out.write(to: writeURL, options: [])
                return list.count
            })
        }
        if let coordError = coordError {
            throw coordError
        }
        return try result.get()
    }

    private static func makeTestEntry() -> [String: Any] {
        let now = Date()
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone.current
        day.dateFormat = "yyyy-MM-dd"
        let stamp = ISO8601DateFormatter()
        stamp.timeZone = TimeZone.current
        stamp.formatOptions = [.withInternetDateTime]
        return [
            "id": UUID().uuidString,
            "amount": 1,
            "necessary": false,
            "date": day.string(from: now),
            "created_at": stamp.string(from: now),
            "matched": false
        ]
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
