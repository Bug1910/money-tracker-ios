// 角色：首頁，打開 App 第一眼看的東西（DESIGN_v2 第二版）。
// 第一屏只有兩件事：「可動用」一個大數字（底下一行每日額度、收合的算式）＋「待處理」清單。
// 往下捲才是：未出帳卡費 → 必定開支 → 本月剩餘 → 帳戶合計 → 資料日期。
// 算式每一列都是下面某一塊，點了就捲過去；需要去帳款頁的（全部待處理、手動記帳）切分頁。
// 後端欄位缺少時的退路：沒有 liquid → 本月剩餘搬到最上面＋待處理多一列「設定」；
// 沒有 cards／fixed_outflows → 那一塊不顯示；沒有 actions → 從舊欄位（due／pending／card_move／stale 帳戶）湊。
import SwiftUI

/// 可以被算式／待處理點過去的區塊
enum HomeAnchor: Hashable {
    case liquid
    case actions
    case cards
    case fixed
    case budget
    case accounts
}

/// 點一列要去哪
enum HomeDestination {
    case stay
    case anchor(HomeAnchor)
    case todo
}

/// 算式表的一列
struct FormulaLine: Identifiable {
    let label: String
    let amount: Double?
    let note: String?
    let isResult: Bool
    let destination: HomeDestination
    var id: String { label }
}

struct HomeView: View {
    let snapshot: Snapshot
    let entries: [Entry]
    /// 切到「帳款」分頁
    let openTodo: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 唯一自訂尺寸：44 隨 Dynamic Type 放大，最多 60
    @ScaledMetric(relativeTo: .largeTitle) private var bigNumberSize: CGFloat = 44
    @State private var showFormula: Bool = false
    @State private var showBudgetFormula: Bool = false
    @State private var showAccounts: Bool = false

    private static let maxActionRows: Int = 5

    // MARK: - 算好的數字

    private var liquidFigures: LiquidFigures? {
        LiquidFigures.make(snapshot: snapshot, entries: entries)
    }

    private var budgetFigures: BudgetFigures? {
        BudgetFigures.make(snapshot: snapshot, entries: entries)
    }

    private var failed: Bool { snapshot.reconcileFailed }

    private var staleDays: Int? { snapshot.staleByDays }

    /// 資料過期時金額 40% 透明
    private var amountOpacity: Double { staleDays == nil ? 1.0 : 0.4 }

    /// 後端沒給 liquid（且不是對帳失敗）→ 本月剩餘搬到最上面
    private var budgetAtTop: Bool { liquidFigures == nil && !failed }

    private var bigFont: Font {
        Font.system(size: min(bigNumberSize, 60), weight: .semibold, design: .rounded).monospacedDigit()
    }

    private var paydayText: String {
        guard let payday = snapshot.liquid?.nextPayday, !payday.isEmpty else { return "" }
        return Formats.shortDate(payday)
    }

    // MARK: - 待處理清單

    /// 後端 actions；沒有就從舊欄位湊。App 自己補的「設定」列放最前面，其餘照期限排。
    private var allActions: [Snapshot.ActionItem] {
        var head: [Snapshot.ActionItem] = []
        if failed {
            head.append(Snapshot.ActionItem(kind: "setup", title: "對帳未通過，電腦端重跑", date: "", amount: nil, count: nil, target: ""))
        } else if liquidFigures == nil {
            head.append(Snapshot.ActionItem(kind: "setup", title: "電腦端尚未提供可動用資料", date: "", amount: nil, count: nil, target: ""))
        } else if let lf = liquidFigures, (lf.liquid.daysToPayday ?? 0) <= 0 {
            head.append(Snapshot.ActionItem(kind: "setup", title: "未設定發薪日", date: "", amount: nil, count: nil, target: ""))
        }
        let rest: [Snapshot.ActionItem] = snapshot.actions ?? legacyActions
        return head + HomeView.sortActions(rest)
    }

    /// 排序：逾期 → 今天 → 日期近 → 無日期（日期字串 YYYY-MM-DD 直接比大小）
    private static func sortActions(_ list: [Snapshot.ActionItem]) -> [Snapshot.ActionItem] {
        let dated: [Snapshot.ActionItem] = list.filter { (a: Snapshot.ActionItem) -> Bool in !a.date.isEmpty }
        let undated: [Snapshot.ActionItem] = list.filter { (a: Snapshot.ActionItem) -> Bool in a.date.isEmpty }
        let sortedDated: [Snapshot.ActionItem] = dated.sorted { (a: Snapshot.ActionItem, b: Snapshot.ActionItem) -> Bool in a.date < b.date }
        return sortedDated + undated
    }

    /// 舊快照（沒有 actions 欄位）：待繳→待繳／待辦、待補資料→待確認 N 筆、搬卡→待辦、過期帳戶→待補資料
    private var legacyActions: [Snapshot.ActionItem] {
        var out: [Snapshot.ActionItem] = []
        for d in snapshot.due where !d.paidGuess {
            let kind: String = (d.amount ?? 0) > 0 ? "pay" : "todo"
            out.append(Snapshot.ActionItem(kind: kind, title: d.title, date: d.date, amount: d.amount, count: nil, target: "due"))
        }
        if !snapshot.pending.isEmpty {
            out.append(Snapshot.ActionItem(kind: "confirm", title: "待確認交易", date: "", amount: nil, count: snapshot.pending.count, target: "pending"))
        }
        for line in snapshot.cardMove {
            out.append(Snapshot.ActionItem(kind: "todo", title: line, date: "", amount: nil, count: nil, target: ""))
        }
        if let assets = snapshot.assets {
            for account in assets.accounts where account.stale {
                out.append(Snapshot.ActionItem(kind: "data", title: account.name + "資料過期", date: "", amount: nil, count: nil, target: "accounts"))
            }
        }
        return out
    }

    private func destination(for target: String) -> HomeDestination {
        switch target {
        case "cards": return .anchor(.cards)
        case "fixed": return .anchor(.fixed)
        case "accounts": return .anchor(.accounts)
        case "due", "pending": return .todo
        default: return .stay
        }
    }

    // MARK: - 算式

    /// 直式減法表：每列對應下面一塊；後端沒給的欄位顯示「—」，不用 0 冒充
    private func formulaLines(_ lf: LiquidFigures) -> [FormulaLine] {
        let l: Snapshot.Liquid = lf.liquid
        var lines: [FormulaLine] = []
        lines.append(FormulaLine(label: "帳戶合計（可用餘額）", amount: l.accountsAvailable, note: nil, isResult: false, destination: .anchor(.accounts)))
        lines.append(FormulaLine(label: "− 未出帳卡費", amount: l.cardsUnbilledTotal, note: nil, isResult: false, destination: .anchor(.cards)))
        lines.append(FormulaLine(label: "− 已出帳未繳", amount: l.cardsStatementDueTotal, note: nil, isResult: false, destination: .anchor(.cards)))
        let fixedLabel: String = paydayText.isEmpty ? "− 必定開支" : "− 必定開支（至 \(paydayText)）"
        lines.append(FormulaLine(label: fixedLabel, amount: l.fixedOutflowsTotal, note: nil, isResult: false, destination: .anchor(.fixed)))
        lines.append(FormulaLine(label: "− 待繳款項", amount: l.actionsDueTotal, note: nil, isResult: false, destination: .anchor(.actions)))
        if let gap = l.savingsGap, gap > 0 {
            lines.append(FormulaLine(label: "− 儲蓄缺口", amount: gap, note: "本期儲蓄目標未達部分", isResult: false, destination: .stay))
        }
        lines.append(FormulaLine(label: "− 保留金", amount: l.reserve, note: "設定在電腦端", isResult: false, destination: .stay))
        if lf.unsyncedAll > 0 {
            lines.append(FormulaLine(label: "− 手動記帳（待入帳）", amount: lf.unsyncedAll, note: nil, isResult: false, destination: .todo))
        }
        lines.append(FormulaLine(label: "＝ 可動用", amount: lf.available, note: nil, isResult: true, destination: .stay))
        return lines
    }

    private func go(_ proxy: ScrollViewProxy, _ destination: HomeDestination) {
        switch destination {
        case .stay:
            return
        case .todo:
            openTodo()
        case .anchor(let anchor):
            if reduceMotion {
                proxy.scrollTo(anchor, anchor: .top)
            } else {
                withAnimation {
                    proxy.scrollTo(anchor, anchor: .top)
                }
            }
        }
    }

    // MARK: - 畫面

    var body: some View {
        ScrollViewReader { (proxy: ScrollViewProxy) in
            List {
                if budgetAtTop {
                    budgetSection
                } else {
                    liquidSection(proxy)
                }
                actionsSection(proxy)
                cardsSection
                fixedSection
                if !budgetAtTop {
                    budgetSection
                }
                accountsSection
                footerSection
            }
            .listStyle(.insetGrouped)
        }
    }

    /// 區塊標籤：Subheadline、主文字色、不全大寫；右側可放合計
    private func header(_ title: String, _ anchor: HomeAnchor, total: Double? = nil, totalText: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            if let text = totalText {
                Text(text).monospacedDigit()
            } else if let total = total {
                Text(Formats.money(total)).monospacedDigit().opacity(amountOpacity)
            }
        }
        .font(.subheadline)
        .foregroundStyle(Theme.text)
        .textCase(nil)
        .id(anchor)
    }

    // MARK: 1. 可動用

    @ViewBuilder
    private func liquidSection(_ proxy: ScrollViewProxy) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("可動用")
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                    .id(HomeAnchor.liquid)
                if failed {
                    Text("—")
                        .font(bigFont)
                        .foregroundStyle(Theme.text)
                    Label(reconcileText, systemImage: "exclamationmark.octagon.fill")
                        .font(.body)
                        .foregroundStyle(Theme.over)
                } else if let lf = liquidFigures {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Formats.money(lf.available))
                            .font(bigFont)
                            .foregroundStyle(lf.available < 0 ? Theme.over : Theme.text)
                            .opacity(amountOpacity)
                        if lf.available < 0 {
                            Text("不足")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.over)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(Capsule().stroke(Theme.over, lineWidth: 1))
                        }
                    }
                    if let n = staleDays {
                        Label("資料已 \(n) 天未更新", systemImage: "exclamationmark.triangle.fill")
                            .font(.body)
                            .foregroundStyle(Theme.stale)
                    } else {
                        Text(allowanceText(lf))
                            .font(.body)
                            .foregroundStyle(Theme.text)
                            .monospacedDigit()
                    }
                    DisclosureGroup(isExpanded: $showFormula) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(formulaLines(lf)) { (line: FormulaLine) in
                                FormulaRowView(line: line, opacity: amountOpacity, action: { go(proxy, line.destination) })
                            }
                        }
                    } label: {
                        Text("算式")
                            .font(.body)
                            .foregroundStyle(Theme.accent)
                    }
                    .tint(Theme.accent)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var reconcileText: String {
        if snapshot.reconcileIssues.isEmpty { return "對帳未通過" }
        return "對帳未通過：" + snapshot.reconcileIssues.joined(separator: "、")
    }

    /// 第二行：「每日額度 X・距發薪 N 天（MM/DD）」；沒有發薪日就「未設定發薪日」
    private func allowanceText(_ lf: LiquidFigures) -> String {
        guard let days = lf.liquid.daysToPayday, days > 0 else { return "未設定發薪日" }
        var text: String = "每日額度 \(Formats.money(lf.dailyAllowance))・距發薪 \(days) 天"
        if !paydayText.isEmpty { text += "（\(paydayText)）" }
        return text
    }

    // MARK: 2. 待處理

    @ViewBuilder
    private func actionsSection(_ proxy: ScrollViewProxy) -> some View {
        let list: [Snapshot.ActionItem] = allActions
        Section {
            if list.isEmpty {
                Text("目前無待處理")
                    .foregroundStyle(Theme.text2)
                    .frame(minHeight: 44)
            } else {
                ForEach(Array(list.prefix(HomeView.maxActionRows))) { (item: Snapshot.ActionItem) in
                    ActionRowView(item: item, destination: destination(for: item.target), action: { go(proxy, destination(for: item.target)) })
                }
                if list.count > HomeView.maxActionRows {
                    Button(action: openTodo) {
                        HStack {
                            Spacer()
                            Text("全部待處理（\(list.count)）")
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                        }
                        .foregroundStyle(Theme.accent)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            header("待處理（\(list.count)）", .actions)
        }
    }

    // MARK: 3. 未出帳卡費（欄位不存在就整塊不顯示）

    @ViewBuilder
    private var cardsSection: some View {
        if let cards = snapshot.cards {
            let credit: [Snapshot.Card] = cards.filter { (c: Snapshot.Card) -> Bool in c.isCredit }
            let withStatement: [Snapshot.Card] = credit.filter { (c: Snapshot.Card) -> Bool in c.statementDue != nil }
            let unbilledTotal: Double = credit.reduce(0) { (sum: Double, c: Snapshot.Card) -> Double in sum + c.unbilled }
            let statementTotal: Double = withStatement.reduce(0) { (sum: Double, c: Snapshot.Card) -> Double in sum + (c.statementDue ?? 0) }
            Section {
                if credit.isEmpty {
                    Text("目前無未出帳卡費")
                        .foregroundStyle(Theme.text2)
                        .frame(minHeight: 44)
                } else {
                    ForEach(credit) { (card: Snapshot.Card) in
                        CardRowView(name: card.name, kindText: "未出帳", amount: card.unbilled,
                                    dateText: card.closingDate.isEmpty ? "" : "結帳 \(Formats.shortDate(card.closingDate))",
                                    stale: card.stale, opacity: amountOpacity)
                    }
                    ForEach(withStatement) { (card: Snapshot.Card) in
                        CardRowView(name: card.name, kindText: "已出帳未繳", amount: card.statementDue,
                                    dateText: card.statementDueDate.isEmpty ? "" : "繳款 \(Formats.shortDate(card.statementDueDate))",
                                    stale: card.stale, opacity: amountOpacity)
                    }
                }
            } header: {
                header("未出帳卡費", .cards, total: credit.isEmpty ? nil : unbilledTotal + statementTotal)
            }
        }
    }

    // MARK: 4. 必定開支（至 MM/DD 發薪）

    @ViewBuilder
    private var fixedSection: some View {
        if let items = snapshot.fixedOutflows {
            let unpaid: [Snapshot.FixedOutflow] = items.filter { (f: Snapshot.FixedOutflow) -> Bool in !f.paid }
            let total: Double = unpaid.reduce(0) { (sum: Double, f: Snapshot.FixedOutflow) -> Double in sum + f.amount }
            let sorted: [Snapshot.FixedOutflow] = items.sorted { (a: Snapshot.FixedOutflow, b: Snapshot.FixedOutflow) -> Bool in a.date < b.date }
            Section {
                if items.isEmpty {
                    Text("目前無必定開支")
                        .foregroundStyle(Theme.text2)
                        .frame(minHeight: 44)
                } else {
                    ForEach(sorted) { (item: Snapshot.FixedOutflow) in
                        FixedRowView(item: item, opacity: amountOpacity)
                    }
                }
            } header: {
                header(paydayText.isEmpty ? "必定開支" : "必定開支（至 \(paydayText) 發薪）", .fixed, total: items.isEmpty ? nil : total)
            }
        }
    }

    // MARK: 5. 本月剩餘（v1 剩餘預算改名縮小；沒有 liquid 時搬到最上面）

    @ViewBuilder
    private var budgetSection: some View {
        if let f = budgetFigures {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    Text("剩餘 \(Formats.money(f.left))／預算 \(Formats.money(f.budget))")
                        .font(budgetAtTop ? Font.title2.weight(.semibold) : Font.body)
                        .monospacedDigit()
                        .foregroundStyle(Theme.text)
                        .opacity(amountOpacity)
                    Spacer()
                    StatusCapsule(status: f.status)
                }
                .frame(minHeight: 44)
                if budgetAtTop, let issue = snapshot.dataIssue {
                    Label(issue, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.stale)
                }
                DisclosureGroup(isExpanded: $showBudgetFormula) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(budgetLines(f)) { (line: FormulaLine) in
                            FormulaRowView(line: line, opacity: amountOpacity, action: {})
                        }
                    }
                } label: {
                    Text("算式")
                        .font(.body)
                        .foregroundStyle(Theme.accent)
                }
                .tint(Theme.accent)
                if f.unsyncedOther > 0 {
                    Text("含手動記帳 \(Formats.money(f.unsyncedOther))（待入帳）")
                        .font(.footnote)
                        .foregroundStyle(Theme.text2)
                }
            } header: {
                header("本月剩餘", .budget)
            }
        }
    }

    /// 本月剩餘的算式：收入 − 必要支出 − 必要待繳 − 儲蓄目標 − 非必要支出
    private func budgetLines(_ f: BudgetFigures) -> [FormulaLine] {
        var lines: [FormulaLine] = []
        if let free = snapshot.freeMoney {
            lines.append(FormulaLine(label: "收入", amount: free.income, note: nil, isResult: false, destination: .stay))
            lines.append(FormulaLine(label: "− 必要支出", amount: free.necessarySpent, note: nil, isResult: false, destination: .stay))
            lines.append(FormulaLine(label: "− 必要待繳", amount: free.necessaryDue, note: nil, isResult: false, destination: .stay))
            lines.append(FormulaLine(label: "− 儲蓄目標", amount: free.savingTarget, note: nil, isResult: false, destination: .stay))
            let other: Double? = free.otherSpent.map { (v: Double) -> Double in v + f.unsyncedOther }
            lines.append(FormulaLine(label: "− 非必要支出", amount: other, note: nil, isResult: false, destination: .stay))
        }
        lines.append(FormulaLine(label: "＝ 剩餘", amount: f.left, note: nil, isResult: true, destination: .stay))
        return lines
    }

    // MARK: 6. 帳戶合計

    @ViewBuilder
    private var accountsSection: some View {
        if let assets = snapshot.assets {
            let total: Double? = snapshot.liquid?.accountsAvailable ?? assets.total
            Section {
                HStack {
                    Text("合計").foregroundStyle(Theme.text)
                    Spacer()
                    Text(failed ? "—" : Formats.money(total))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.text)
                        .opacity(amountOpacity)
                }
                .frame(minHeight: 44)
                if !assets.accounts.isEmpty {
                    DisclosureGroup(isExpanded: $showAccounts) {
                        ForEach(assets.accounts) { (account: Snapshot.Account) in
                            AccountRowView(account: account, hideAmount: failed, opacity: amountOpacity)
                        }
                    } label: {
                        Text("各帳戶（\(assets.accounts.count)）")
                            .font(.body)
                            .foregroundStyle(Theme.accent)
                    }
                    .tint(Theme.accent)
                }
                if !assets.notCounted.isEmpty {
                    Label("未計入：" + assets.notCounted.joined(separator: "、"), systemImage: "minus.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.text2)
                }
            } header: {
                header("帳戶合計", .accounts)
            }
        }
    }

    // MARK: 7. 資料日期

    private var footerText: String {
        guard let day = snapshot.generatedAt, !day.isEmpty else { return "資料日期 —" }
        var text: String = "資料日期 " + Formats.shortDate(day)
        if let time = snapshot.generatedTime, !time.isEmpty { text += " " + time }
        return text
    }

    @ViewBuilder
    private var footerSection: some View {
        Section {
            Text(footerText)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(staleDays == nil ? Theme.text2 : Theme.stale)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        }
    }
}

// MARK: - 列元件

/// 算式一列：標籤、金額、右側箭頭（可點的才有）；整列可點
struct FormulaRowView: View {
    let line: FormulaLine
    let opacity: Double
    let action: () -> Void

    private var tappable: Bool {
        if case .stay = line.destination { return false }
        return true
    }

    /// 列的內容；可點的包在 Button 裡，不可點的直接放（不用 disabled，免得被畫成灰色）
    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(line.label)
                    .font(line.isResult ? .headline : .body)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(Formats.money(line.amount))
                    .font(line.isResult ? .headline.monospacedDigit() : .body.monospacedDigit())
                    .foregroundStyle(Theme.text)
                    .opacity(opacity)
                if tappable {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            if let note = line.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Theme.text2)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    var body: some View {
        if tappable {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("按兩下前往")
        } else {
            content
                .accessibilityElement(children: .combine)
        }
    }
}

/// 待處理一列：左側類型膠囊、標題、右側金額與日期（或 N 筆）；整列可點
struct ActionRowView: View {
    let item: Snapshot.ActionItem
    let destination: HomeDestination
    let action: () -> Void

    private var tappable: Bool {
        if case .stay = destination { return false }
        return true
    }

    private var subText: String {
        if !item.date.isEmpty { return Formats.relativeDays(item.date) }
        if let n = item.count { return "\(n) 筆" }
        return "—"
    }

    private var content: some View {
        HStack(alignment: .center, spacing: 10) {
            TagCapsule(text: item.label)
            Text(item.title)
                .font(.body)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.leading)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let amount = item.amount {
                    Text(Formats.money(amount))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.text)
                }
                Text(subText)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.text2)
            }
            if tappable {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    var body: some View {
        if tappable {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("按兩下前往")
        } else {
            content
                .accessibilityElement(children: .combine)
        }
    }
}

/// 卡費一列：卡名、未出帳／已出帳未繳、金額、結帳或繳款日
struct CardRowView: View {
    let name: String
    let kindText: String
    let amount: Double?
    let dateText: String
    let stale: Bool
    let opacity: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if stale {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.stale)
                    }
                    Text(name).foregroundStyle(stale ? Theme.stale : Theme.text)
                }
                Text(dateText.isEmpty ? kindText : "\(kindText)・\(dateText)")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.text2)
            }
            Spacer()
            Text(Formats.money(amount))
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.text)
                .opacity(opacity)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// 必定開支一列：標題、「MM/DD・自動扣款／需手動」、金額；已扣的 60% 透明＋標「已扣」
struct FixedRowView: View {
    let item: Snapshot.FixedOutflow
    let opacity: Double

    private var subText: String {
        let how: String = item.auto ? "自動扣款" : "需手動"
        if item.date.isEmpty { return how }
        return "\(Formats.shortDate(item.date))・\(how)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).foregroundStyle(Theme.text)
                Text(subText)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.text2)
            }
            Spacer()
            HStack(spacing: 6) {
                Text(Formats.money(item.amount))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.text)
                    .opacity(opacity)
                if item.paid {
                    Text("已扣")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text2)
                }
            }
        }
        .frame(minHeight: 44)
        .opacity(item.paid ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
    }
}

/// 帳戶一列：帳戶名、可用餘額、「更新 MM/DD」；過期的整列 stale 色＋警示圖示
struct AccountRowView: View {
    let account: Snapshot.Account
    let hideAmount: Bool
    let opacity: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if account.stale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.stale)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .foregroundStyle(account.stale ? Theme.stale : Theme.text)
                Text(account.asOf.isEmpty ? "未更新" : "更新 \(Formats.shortDate(account.asOf))")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(account.stale ? Theme.stale : Theme.text2)
            }
            Spacer()
            Text(hideAmount ? "—" : Formats.money(account.shownBalance))
                .font(.body.monospacedDigit())
                .foregroundStyle(account.stale ? Theme.stale : Theme.text)
                .opacity(opacity)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
