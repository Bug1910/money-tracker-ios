// 角色：一筆「手動記帳」的資料長相，加上各畫面共用的金額／日期格式化小工具。
// App 只寫 entries.json（電腦端會讀它、配對進帳本）；snapshot.json 是電腦寫的，App 絕不碰。
// 欄位沿用階段 1 的測試紀錄（id／amount／necessary／date／created_at／matched），多加 category 與 note。
import Foundation

struct Entry: Identifiable {
    let id: String
    let amount: Double
    let necessary: Bool
    let date: String
    let createdAt: String
    let matched: Bool
    let category: String
    let note: String

    /// 轉成寫進 entries.json 的字典
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "amount": amount,
            "necessary": necessary,
            "date": date,
            "created_at": createdAt,
            "matched": matched
        ]
        if !category.isEmpty { dict["category"] = category }
        if !note.isEmpty { dict["note"] = note }
        return dict
    }

    /// 從 entries.json 的一筆字典讀回來；缺欄位用預設值
    static func fromJSON(_ obj: Any) -> Entry? {
        guard let dict = obj as? [String: Any] else { return nil }
        let amountNumber: NSNumber? = dict["amount"] as? NSNumber
        return Entry(
            id: (dict["id"] as? String) ?? UUID().uuidString,
            amount: amountNumber?.doubleValue ?? 0,
            necessary: (dict["necessary"] as? Bool) ?? false,
            date: (dict["date"] as? String) ?? "",
            createdAt: (dict["created_at"] as? String) ?? "",
            matched: (dict["matched"] as? Bool) ?? false,
            category: (dict["category"] as? String) ?? "",
            note: (dict["note"] as? String) ?? ""
        )
    }
}

enum Formats {
    static func money(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "—"
    }

    static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func stampString(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone.current
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    /// "2026-11-04" 變 "11/04"
    static func shortDate(_ iso: String) -> String {
        guard iso.count >= 10 else { return iso }
        let start: String.Index = iso.index(iso.startIndex, offsetBy: 5)
        let end: String.Index = iso.index(iso.startIndex, offsetBy: 10)
        let piece: String = String(iso[start..<end])
        return piece.replacingOccurrences(of: "-", with: "/")
    }

    /// "2026-11-04" 變「3 天後」「今天」「逾期 2 天」；格式不對就原樣回傳
    static func relativeDays(_ iso: String) -> String {
        guard let days = daysFromToday(iso) else { return iso }
        if days < 0 { return "逾期 \(-days) 天" }
        if days == 0 { return "今天" }
        return "\(days) 天後"
    }

    /// 距離今天幾天（過期為負數）；格式不對回 nil
    static func daysFromToday(_ iso: String) -> Int? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        guard let target = f.date(from: iso) else { return nil }
        let cal = Calendar.current
        let a: Date = cal.startOfDay(for: Date())
        let b: Date = cal.startOfDay(for: target)
        return cal.dateComponents([.day], from: a, to: b).day
    }
}
