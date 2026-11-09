// 角色：看懂電腦端產生的 snapshot.json（金錢快照）的翻譯官。
// 電腦端把帳本算成一包只有彙總數字的 JSON，這裡把它讀成 Swift 結構給各畫面用。
// 每一欄都用「寬鬆讀法」：欄位缺少或型別不對只會讓該欄變空，不會讓 App 當掉。
// v5 新增（DESIGN_v2）：liquid（可動用）、cards（卡費）、fixed_outflows（必定開支）、actions（待處理）、
// accounts[].available、generated_time、reconcile_issues、stale_days；全部 optional，後端還沒給就退回舊畫面。
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
    /// "HH:mm"，配合 generatedAt 顯示頁尾「資料日期 MM/DD HH:mm」
    let generatedTime: String?
    let currentMonth: String?
    let reconcileOk: Bool?
    /// 對帳沒過時的帳戶名清單（只有名稱）
    let reconcileIssues: [String]
    /// 電腦端定義幾天算過期；沒有就用 App 預設
    let staleDaysOverride: Int?
    let freeMoney: FreeMoney?
    let assets: Assets?
    /// 可動用（nil ＝ 後端尚未提供 → 首頁退回本月剩餘在最上面）
    let liquid: Liquid?
    /// nil ＝ 欄位不存在（區塊不顯示）；空陣列 ＝ 有欄位但沒有卡費
    let cards: [Card]?
    let fixedOutflows: [FixedOutflow]?
    let actions: [ActionItem]?
    let months: [MonthBlock]
    let due: [DueItem]
    let pending: [PendingItem]
    let subscriptions: [Subscription]
    let cardMove: [String]
    /// 電腦端已配對進帳本的手動記帳 id；舊快照沒有這欄就是空陣列
    let matchedEntryIds: [String]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case generatedTime = "generated_time"
        case currentMonth = "current_month"
        case reconcileOk = "reconcile_ok"
        case reconcileIssues = "reconcile_issues"
        case staleDaysOverride = "stale_days"
        case freeMoney = "free_money"
        case assets, months, due, pending, subscriptions, liquid, cards, actions
        case fixedOutflows = "fixed_outflows"
        case cardMove = "card_move"
        case matchedEntryIds = "matched_entry_ids"
    }

    init(from decoder: Decoder) throws {
        // 最外層一定要是 JSON 物件；裡面每一欄容錯
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = c.lenient(String.self, .generatedAt)
        generatedTime = c.lenient(String.self, .generatedTime)
        currentMonth = c.lenient(String.self, .currentMonth)
        reconcileOk = c.lenient(Bool.self, .reconcileOk)
        reconcileIssues = c.lenient([String].self, .reconcileIssues) ?? []
        staleDaysOverride = c.lenient(Int.self, .staleDaysOverride)
        freeMoney = c.lenient(FreeMoney.self, .freeMoney)
        assets = c.lenient(Assets.self, .assets)
        liquid = c.lenient(Liquid.self, .liquid)
        cards = c.lenient([Card].self, .cards)
        fixedOutflows = c.lenient([FixedOutflow].self, .fixedOutflows)
        actions = c.lenient([ActionItem].self, .actions)
        months = c.lenient([MonthBlock].self, .months) ?? []
        due = c.lenient([DueItem].self, .due) ?? []
        pending = c.lenient([PendingItem].self, .pending) ?? []
        subscriptions = c.lenient([Subscription].self, .subscriptions) ?? []
        cardMove = c.lenient([String].self, .cardMove) ?? []
        matchedEntryIds = c.lenient([String].self, .matchedEntryIds) ?? []
    }

    /// 這筆手動記帳電腦端配對進帳本了嗎（以快照清單為準；entries.json 自己的 matched 欄位也算）
    func isMatched(_ entry: Entry) -> Bool {
        return entry.matched || matchedEntryIds.contains(entry.id)
    }

    /// 資料超過幾天算過期（App 預設；快照有 stale_days 就用快照的）
    static let defaultStaleDays: Int = 3

    var staleDays: Int {
        if let d = staleDaysOverride, d > 0 { return d }
        return Snapshot.defaultStaleDays
    }

    /// 對帳沒過（紅線：對帳全 OK 才報數字）
    var reconcileFailed: Bool { reconcileOk == false }

    /// 資料過期幾天；nil ＝ 沒過期（或日期不明）
    var staleByDays: Int? {
        guard let stamp = generatedAt, let days = Formats.daysFromToday(stamp) else { return nil }
        if -days > staleDays { return -days }
        return nil
    }

    /// 數字不可信的原因；nil 代表可信。
    var dataIssue: String? {
        if reconcileFailed { return "對帳未通過" }
        guard let stamp = generatedAt, Formats.daysFromToday(stamp) != nil else { return "資料日期不明" }
        if let n = staleByDays { return "資料已 \(n) 天未更新" }
        return nil
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

    /// 可動用：每一欄都可能缺；available 缺就當整塊沒有
    struct Liquid: Decodable {
        let available: Double?
        let accountsAvailable: Double?
        let cardsUnbilledTotal: Double?
        let cardsStatementDueTotal: Double?
        let fixedOutflowsTotal: Double?
        let actionsDueTotal: Double?
        /// 本期儲蓄目標還差多少（後端有算才有；規格外欄位，有才顯示）
        let savingsGap: Double?
        let reserve: Double?
        let nextPayday: String?
        let daysToPayday: Int?
        let dailyAllowance: Double?

        enum CodingKeys: String, CodingKey {
            case available, reserve
            case accountsAvailable = "accounts_available"
            case cardsUnbilledTotal = "cards_unbilled_total"
            case cardsStatementDueTotal = "cards_statement_due_total"
            case fixedOutflowsTotal = "fixed_outflows_total"
            case actionsDueTotal = "actions_due_total"
            case savingsGap = "savings_gap"
            case nextPayday = "next_payday"
            case daysToPayday = "days_to_payday"
            case dailyAllowance = "daily_allowance"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            available = c.lenient(Double.self, .available)
            accountsAvailable = c.lenient(Double.self, .accountsAvailable)
            cardsUnbilledTotal = c.lenient(Double.self, .cardsUnbilledTotal)
            cardsStatementDueTotal = c.lenient(Double.self, .cardsStatementDueTotal)
            fixedOutflowsTotal = c.lenient(Double.self, .fixedOutflowsTotal)
            actionsDueTotal = c.lenient(Double.self, .actionsDueTotal)
            savingsGap = c.lenient(Double.self, .savingsGap)
            reserve = c.lenient(Double.self, .reserve)
            nextPayday = c.lenient(String.self, .nextPayday)
            daysToPayday = c.lenient(Int.self, .daysToPayday)
            dailyAllowance = c.lenient(Double.self, .dailyAllowance)
        }
    }

    /// 一張卡：未出帳、已出帳未繳
    struct Card: Decodable, Identifiable {
        let name: String
        /// "credit" / "debit"；簽帳金融卡不列進卡費（已反映在帳戶可用餘額）
        let kind: String
        let unbilled: Double
        let closingDate: String
        let statementAmount: Double?
        let statementDueDate: String
        let statementPaid: Bool
        let asOf: String
        let stale: Bool
        var id: String { name }

        var isCredit: Bool { kind != "debit" }
        /// 已出帳且還沒繳的金額；nil ＝ 沒有要顯示的
        var statementDue: Double? {
            guard let amt = statementAmount, !statementPaid, amt > 0 else { return nil }
            return amt
        }

        enum CodingKeys: String, CodingKey {
            case name, kind, unbilled, stale
            case closingDate = "closing_date"
            case statementAmount = "statement_amount"
            case statementDueDate = "statement_due_date"
            case statementPaid = "statement_paid"
            case asOf = "as_of"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = c.lenient(String.self, .name) ?? "—"
            kind = c.lenient(String.self, .kind) ?? "credit"
            unbilled = c.lenient(Double.self, .unbilled) ?? 0
            closingDate = c.lenient(String.self, .closingDate) ?? ""
            statementAmount = c.lenient(Double.self, .statementAmount)
            statementDueDate = c.lenient(String.self, .statementDueDate) ?? ""
            statementPaid = c.lenient(Bool.self, .statementPaid) ?? false
            asOf = c.lenient(String.self, .asOf) ?? ""
            stale = c.lenient(Bool.self, .stale) ?? false
        }
    }

    /// 必定開支一筆（到下次發薪日前會扣的固定支出）
    struct FixedOutflow: Decodable, Identifiable {
        let title: String
        let amount: Double
        let date: String
        let account: String
        let auto: Bool
        let paid: Bool
        var id: String { date + title }

        enum CodingKeys: String, CodingKey {
            case title, amount, date, account, auto, paid
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            title = c.lenient(String.self, .title) ?? "—"
            amount = c.lenient(Double.self, .amount) ?? 0
            date = c.lenient(String.self, .date) ?? ""
            account = c.lenient(String.self, .account) ?? ""
            auto = c.lenient(Bool.self, .auto) ?? true
            paid = c.lenient(Bool.self, .paid) ?? false
        }
    }

    /// 待處理一筆：kind 決定左側標籤，target 決定點了去哪
    struct ActionItem: Decodable, Identifiable {
        let kind: String
        let title: String
        let date: String
        let amount: Double?
        let count: Int?
        let target: String
        var id: String { kind + "|" + title + "|" + date }

        enum CodingKeys: String, CodingKey {
            case kind, title, date, amount, count, target
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            kind = c.lenient(String.self, .kind) ?? "todo"
            title = c.lenient(String.self, .title) ?? "—"
            date = c.lenient(String.self, .date) ?? ""
            amount = c.lenient(Double.self, .amount)
            count = c.lenient(Int.self, .count)
            target = c.lenient(String.self, .target) ?? ""
        }

        /// App 自己補的列（對帳未通過、未設定發薪日、後端缺欄位、舊快照退回）
        init(kind: String, title: String, date: String, amount: Double?, count: Int?, target: String) {
            self.kind = kind
            self.title = title
            self.date = date
            self.amount = amount
            self.count = count
            self.target = target
        }

        /// 左側 2～4 字標籤（規格 3.2）；不認得的 kind 當「待辦」
        var label: String {
            switch kind {
            case "pay": return "待繳"
            case "transfer": return "待轉帳"
            case "confirm": return "待確認"
            case "data": return "待補資料"
            case "setup": return "設定"
            default: return "待辦"
            }
        }
    }

    struct Assets: Decodable {
        let total: Double?
        let accounts: [Account]
        let notCounted: [String]

        enum CodingKeys: String, CodingKey {
            case total, accounts
            case notCounted = "not_counted"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            total = c.lenient(Double.self, .total)
            accounts = c.lenient([Account].self, .accounts) ?? []
            notCounted = c.lenient([String].self, .notCounted) ?? []
        }
    }

    struct Account: Decodable, Identifiable {
        let name: String
        let balance: Double
        /// 可用餘額（含未入帳簽帳扣款）；沒有就退回 balance
        let available: Double?
        let asOf: String
        let stale: Bool
        var id: String { name }

        var shownBalance: Double { available ?? balance }

        enum CodingKeys: String, CodingKey {
            case name, balance, stale, available
            case asOf = "as_of"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = c.lenient(String.self, .name) ?? "—"
            balance = c.lenient(Double.self, .balance) ?? 0
            available = c.lenient(Double.self, .available)
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
