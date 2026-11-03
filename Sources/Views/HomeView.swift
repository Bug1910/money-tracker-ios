// 角色：首頁，打開 App 第一眼看的東西。
// 由上到下照重要性排：剩餘預算 → 待繳帳款（14 天內）→ 本月收支 → 前五支出 → 待補資料 → 帳戶合計。
// 最在意的「還剩多少錢可以花」放最上面，超過基準會變紅並顯示提醒。
import SwiftUI

struct HomeView: View {
    let snapshot: Snapshot
    let entries: [Entry]

    private var figures: BudgetFigures? {
        BudgetFigures.make(snapshot: snapshot, entries: entries)
    }

    private var dueSoon: [Snapshot.DueItem] {
        let list: [Snapshot.DueItem] = snapshot.due.filter { (item: Snapshot.DueItem) -> Bool in
            guard let days = Formats.daysFromToday(item.date) else { return false }
            return days <= 14
        }
        return list.sorted { (a: Snapshot.DueItem, b: Snapshot.DueItem) -> Bool in a.date < b.date }
    }

    private var nextDueText: String {
        let later: [Snapshot.DueItem] = snapshot.due.filter { (d: Snapshot.DueItem) -> Bool in
            guard let days = Formats.daysFromToday(d.date) else { return false }
            return days > 14
        }
        let ordered: [Snapshot.DueItem] = later.sorted { (a: Snapshot.DueItem, b: Snapshot.DueItem) -> Bool in a.date < b.date }
        if let next = ordered.first {
            return "近期無待繳，下一筆 \(Formats.shortDate(next.date)) \(next.title)"
        }
        return "近期無待繳，無後續帳款"
    }

    private var topFive: [Snapshot.CategoryAmount] {
        guard let month = snapshot.thisMonth else { return [] }
        let sorted: [Snapshot.CategoryAmount] = month.categories.sorted { (a: Snapshot.CategoryAmount, b: Snapshot.CategoryAmount) -> Bool in
            a.amount > b.amount
        }
        return Array(sorted.prefix(5))
    }

    var body: some View {
        List {
            budgetSection
            dueSection
            monthSection
            topSection
            pendingSection
            assetSection
        }
    }

    // MARK: 剩餘預算

    @ViewBuilder
    private var budgetSection: some View {
        if let f = figures {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("剩餘預算")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                    Text(Formats.money(f.left))
                        .font(.largeTitle.bold().monospacedDigit())
                        .foregroundStyle(Color.primary)
                        .opacity(snapshot.dataIssue == nil ? 1.0 : 0.4)
                    if let issue = snapshot.dataIssue {
                        Label("資料待更新（\(issue)）", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.bold())
                            .foregroundStyle(Color.primary)
                    }
                    DisclosureGroup("預算 \(Formats.money(f.budget)) − 已花 \(Formats.money(f.budget - f.left))") {
                        necessaryDetail(f)
                    }
                    .font(.subheadline)
                    HStack {
                        Text(Palette.label(for: f.status))
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Palette.color(for: f.status).opacity(0.15))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    if f.status == .over {
                        Text("已超過本月非必要支出基準")
                            .font(.footnote)
                            .foregroundStyle(Color.primary)
                    }
                    if f.unsyncedOther > 0 {
                        Text("含手動記帳 \(Formats.money(f.unsyncedOther))（尚未入帳）")
                            .font(.caption)
                            .foregroundStyle(Color.primary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// 算式展開：收入、必要支出、必要待繳、儲蓄目標，以及必要類別有哪些
    @ViewBuilder
    private func necessaryDetail(_ f: BudgetFigures) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let free = snapshot.freeMoney {
                AmountRow(title: "收入", amount: free.income)
                AmountRow(title: "必要支出", amount: free.necessarySpent)
                AmountRow(title: "必要待繳", amount: free.necessaryDue)
                AmountRow(title: "儲蓄目標", amount: free.savingTarget)
            }
            let names: [String] = necessaryNames
            if !names.isEmpty {
                Text("必要類別：" + names.joined(separator: "、"))
                    .font(.footnote)
                    .foregroundStyle(Color.primary)
            }
        }
    }

    private var necessaryNames: [String] {
        guard let month = snapshot.thisMonth else { return [] }
        let list: [Snapshot.CategoryAmount] = month.categories.filter { (c: Snapshot.CategoryAmount) -> Bool in c.necessary }
        return list.map { (c: Snapshot.CategoryAmount) -> String in c.name }
    }

    // MARK: 待繳帳款

    @ViewBuilder
    private var dueSection: some View {
        Section("待繳帳款（14 天內）") {
            if dueSoon.isEmpty {
                Text(nextDueText).foregroundStyle(Color.primary)
            } else {
                ForEach(dueSoon) { (item: Snapshot.DueItem) in
                    DueRow(item: item)
                }
            }
        }
    }

    // MARK: 本月收支

    @ViewBuilder
    private var monthSection: some View {
        if let month = snapshot.thisMonth {
            Section("本月收支") {
                AmountRow(title: "收入", amount: month.income)
                AmountRow(title: "支出", amount: month.spending)
                AmountRow(title: "結餘", amount: month.left, emphasize: true)
            }
        }
    }

    // MARK: 前五支出

    @ViewBuilder
    private var topSection: some View {
        if !topFive.isEmpty {
            Section("前五支出") {
                ForEach(topFive) { (item: Snapshot.CategoryAmount) in
                    AmountRow(title: item.name, amount: item.amount)
                }
            }
        }
    }

    // MARK: 待補資料

    @ViewBuilder
    private var pendingSection: some View {
        if !snapshot.pending.isEmpty {
            Section("待補資料（\(snapshot.pending.count) 筆）") {
                ForEach(Array(snapshot.pending.prefix(3))) { (item: Snapshot.PendingItem) in
                    HStack {
                        Text(Formats.shortDate(item.date))
                            .foregroundStyle(Color.primary)
                        Text(item.category)
                        Spacer()
                        Text(Formats.money(item.amount)).monospacedDigit()
                    }
                }
                if snapshot.pending.count > 3 {
                    Text("其餘見「帳款」").font(.footnote).foregroundStyle(Color.primary)
                }
            }
        }
    }

    // MARK: 帳戶合計（較不重要，放最後）

    @ViewBuilder
    private var assetSection: some View {
        if let assets = snapshot.assets {
            Section("帳戶合計") {
                AmountRow(title: "合計", amount: assets.total, emphasize: true)
                    .opacity(snapshot.dataIssue == nil ? 1.0 : 0.4)
                if assets.notCounted.count > 0 {
                    Label("未計入：" + assets.notCounted.joined(separator: "、"), systemImage: "minus.circle")
                        .font(.footnote)
                        .foregroundStyle(Color.primary)
                }
                Text("資料日期 \(snapshot.generatedAt ?? "—")")
                    .font(.footnote)
                    .foregroundStyle(Color.primary)
            }
        }
    }
}

/// 一筆待繳帳款：標題、到期日（幾天後）、金額；疑似已繳的變淡
struct DueRow: View {
    let item: Snapshot.DueItem

    private var dayText: String {
        guard let days = Formats.daysFromToday(item.date) else { return item.date }
        if days < 0 { return "逾期 \(-days) 天" }
        if days == 0 { return "今天" }
        return "\(days) 天後"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                Text("\(Formats.shortDate(item.date))・\(dayText)")
                    .font(.caption)
                    .foregroundStyle(Color.primary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formats.money(item.amount)).monospacedDigit()
                if item.paidGuess {
                    Text("疑似已繳").font(.caption).foregroundStyle(Color.primary)
                }
            }
        }
        .opacity(item.paidGuess ? 0.6 : 1.0)
    }
}
