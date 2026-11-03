// 角色：App 自己的「日誌員」。
// 把開 App、讀取、記帳、錯誤這些事件一行一行記進 App 的 Documents/logs/app_YYYYMMDD.log，
// 每行開頭帶時間；超過 7 天的舊檔在啟動時自動刪。設定頁可看最近 50 行。
// 🔴 隱私：只記事件名稱、筆數、錯誤代碼；不記金額、店名、帳號、資料夾路徑、備註內容。
import Foundation

enum AppLog {
    private static let queue = DispatchQueue(label: "app.log")
    private static let keepDays: Int = 7

    private static var directory: URL {
        let docs: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("logs", isDirectory: true)
    }

    private static func dayStamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    private static func fileURL(for date: Date) -> URL {
        return directory.appendingPathComponent("app_" + dayStamp(date) + ".log")
    }

    /// 寫一行；失敗就算了（日誌壞掉不能拖垮 App）
    static func write(_ message: String) {
        let now = Date()
        queue.async {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let line: String = f.string(from: now) + " " + message + "\n"
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                let url: URL = fileURL(for: now)
                if let data = line.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: url.path) {
                        let handle = try FileHandle(forWritingTo: url)
                        defer { try? handle.close() }
                        try handle.seekToEnd()
                        try handle.write(contentsOf: data)
                    } else {
                        try data.write(to: url)
                    }
                }
            } catch {
                // 不再遞迴寫 log
            }
        }
    }

    /// 只記錯誤的 domain 與 code，不記說明文字（說明可能含檔名路徑）
    static func writeError(_ context: String, _ error: Error) {
        let ns = error as NSError
        write("錯誤 " + context + " " + ns.domain + " " + String(ns.code))
    }

    /// 刪掉超過 7 天的舊日誌
    static func purgeOld() {
        queue.async {
            let cutoff: Date = Date().addingTimeInterval(-Double(keepDays) * 86400)
            let urls: [URL] = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [])) ?? []
            for url in urls where url.pathExtension == "log" {
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                if let modified = values?.contentModificationDate, modified < cutoff {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    /// 最近 count 行（跨日期由新檔往舊檔補）
    static func recent(_ count: Int) -> [String] {
        return queue.sync { () -> [String] in
            let urls: [URL] = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])) ?? []
            let logs: [URL] = urls.filter { (u: URL) -> Bool in u.pathExtension == "log" }
                .sorted { (a: URL, b: URL) -> Bool in a.lastPathComponent > b.lastPathComponent }
            var lines: [String] = []
            for url in logs {
                let text: String = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let part: [String] = text.split(separator: "\n").map { (s: Substring) -> String in String(s) }
                lines = part + lines
                if lines.count >= count { break }
            }
            return Array(lines.suffix(count))
        }
    }
}
