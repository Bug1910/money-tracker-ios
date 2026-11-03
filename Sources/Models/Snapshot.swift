// 角色：看懂電腦端產生的 snapshot.json（金錢快照）的翻譯官。
// 電腦端把帳本算成一包只有彙總數字的 JSON，這裡把它讀成 Swift 結構給各畫面用。
// 每一欄都用「寬鬆讀法」：欄位缺少或型別不對只會讓該欄變空，不會讓 App 當掉。
import Foundation

private extension KeyedDecodingContainer {
    /// 讀不到或型別不對就回 nil，不丟錯。
    func lenient<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        let value: T? = try? self.decodeIfPresent(type, forKey: key)
        return value
    }
}

struct Snapshot: Decodable {
    let generatedAt: String?
    let currentMonth: String?
    let freeMoney: FreeMoney?
    let assets: Assets?
    let months: [MonthBlock]
    let due: [DueItem]
    let pending: [PendingItem]
    let subscriptions: [Subscription]
    let cardMove: [String]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case currentMonth = "current_month"
        case freeMoney = "free_money"
        case assets, months, due, pending, subscriptions
        case cardMove = "card_move"
    }

    init(from decoder: Decoder) throws {
        // 最外層一定要是 JSON 物件；裡面每一欄容錯
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = c.lenient(String.self, .generatedAt)
        currentMonth = c.lenient(String.self, .currentMonth)
        freeMoney = c.lenient(FreeMoney.self, .freeMoney)
        assets = c.lenient(Assets.self, .assets)
        months = c.lenient([MonthBlock].self, .months) ?? []
        due = c.lenient([DueItem].self, .due) ?? []
        pending = c.lenient([PendingItem].self, .pending) ?? []
        subscriptions = c.lenient([Subscription].self, .subscriptions) ?? []
        cardMove = c.lenient([String].self, .cardMove) ?? []
    }

    /// 本月那一塊
    var thisMonth: MonthBlock? {
        if let key = currentMonth {
            let found: MonthBlock? = months.first(where: { (m: MonthBlock) -> Bool in m.month == key })
            if found != nil { return found }
        }
        return months.last
    }

    struct FreeMoney: Decodable {
        let income: Double?
        let necessarySpent: Double?
        let necessaryDue: Double?
        let savingTarget: Double?
        let freeBudget: Double?
        let otherSpent: Double?
        let freeLeft: Double?
        let status: String?

        enum CodingKeys: String, CodingKey {
            case income, status
            case necessarySpent = "necessary_spent"
            case necessaryDue = "necessary_due"
            case savingTarget = "saving_target"
            case freeBudget = "free_budget"
            case otherSpent = "other_spent"
            case freeLeft = "free_left"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            income = c.lenient(Double.self, .income)
            necessarySpent = c.lenient(Double.self, .necessarySpent)
            necessaryDue = c.lenient(Double.self, .necessaryDue)
            savingTarget = c.lenient(Double.self, .savingTarget)
            freeBudget = c.lenient(Double.self, .freeBudget)
            otherSpent = c.lenient(Double.self, .otherSpent)
            freeLeft = c.lenient(Double.self, .freeLeft)
            status = c.lenient(String.self, .status)
        }
    }

    struct Assets: Decodable {
        let total: Double?
        let accounts: [Account]

        enum CodingKeys: String, CodingKey {
            case total, accounts
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            total = c.lenient(Double.self, .total)
            accounts = c.lenient([Account].self, .accounts) ?? []
        }
    }

    struct Account: Decodable, Identifiable {
        let name: String
        let balance: Double
        let asOf: String
        let stale: Bool
        var id: String { name }

        enum CodingKeys: String, CodingKey {
            case name, balance, stale
            case asOf = "as_of"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = c.lenient(String.self, .name) ?? "—"
            balance = c.lenient(Double.self, .balance) ?? 0
            asOf = c.lenient(String.self, .asOf) ?? ""
            stale = c.lenient(Bool.self, .stale) ?? false
        }
    }

    struct MonthBlock: Decodable, Identifiable {
        let month: String
        let income: Double
        let spending: Double
        let left: Double
        let settled: Bool
        let categories: [CategoryAmount]
        var id: String { month }

        enum CodingKeys: String, CodingKey {
            case month, income, spending, left, settled, categories
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            month = c.lenient(String.self, .month) ?? ""
            income = c.lenient(Double.self, .income) ?? 0
            spending = c.lenient(Double.self, .spending) ?? 0
            left = c.lenient(Double.self, .left) ?? 0
            settled = c.lenient(Bool.self, .settled) ?? false
            categories = c.lenient([CategoryAmount].self, .categories) ?? []
        }
    }

    struct CategoryAmount: Decodable, Identifiable {
        let name: String
        let amount: Double
        let pct: Double?
        let necessary: Bool
        var id: String { name }

        enum CodingKeys: String, CodingKey {
            case name, amount, pct, necessary
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = c.lenient(String.self, .name) ?? "—"
            amount = c.lenient(Double.self, .amount) ?? 0
            pct = c.lenient(Double.self, .pct)
            necessary = c.lenient(Bool.self, .necessary) ?? false
        }
    }

    struct DueItem: Decodable, Identifiable {
        let title: String
        let date: String
        let amount: Double?
        let paidGuess: Bool
        var id: String { date + title }

        enum CodingKeys: String, CodingKey {
            case title, date, amount
            case paidGuess = "paid_guess"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = c.lenient(String.self, .title) ?? "—"
            date = c.lenient(String.self, .date) ?? ""
            amount = c.lenient(Double.self, .amount)
            paidGuess = c.lenient(Bool.self, .paidGuess) ?? false
        }
    }

    /// 待補資料：只取日期＋金額＋類別（隱私規則：不顯示店名與問題原文）
    struct PendingItem: Decodable, Identifiable {
        let date: String
        let amount: Double
        let category: String
        var id: String { date + category + String(amount) }

        enum CodingKeys: String, CodingKey {
            case date, amount, category
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            date = c.lenient(String.self, .date) ?? ""
            amount = c.lenient(Double.self, .amount) ?? 0
            category = c.lenient(String.self, .category) ?? "—"
        }
    }

    struct Subscription: Decodable, Identifiable {
        let name: String
        let amount: Double
        let period: String
        let note: String
        var id: String { name + period }

        enum CodingKeys: String, CodingKey {
            case name, amount, period, note
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = c.lenient(String.self, .name) ?? "—"
            amount = c.lenient(Double.self, .amount) ?? 0
            period = c.lenient(String.self, .period) ?? ""
            note = c.lenient(String.self, .note) ?? ""
        }
    }
}
