// 角色：事項頁（v6）。需要他動手或確認的事集中一處：待處理、近期帳單、待確認、訂閱、帳戶更新。
// 只有「帳單逾期」用紅色；其他一律中性色。待確認只顯示日期＋金額＋類別，不顯示店名（隱私規則）。
import SwiftUI

struct ItemsView: View {
    let snapshot: Snapshot

    private var sortedDue: [Snapshot.DueItem] {
        snapshot.due.sorted { (a: Snapshot.DueItem, b: Snapshot.DueItem) -> Bool in a.date < b.date }
    }

    private var actions: [Snapshot.ActionItem] {
        return snapshot.actions ?? []
    }

    private func freshness(_ account: Snapshot.Account) -> String {
        guard !account.asOf.isEmpty, let days = Formats.daysFromToday(account.asOf) else { return "未更新" }
        if days >= 0 { return "已更新" }
        return "\(-days) 天沒更新"
    }

    /// 逾期＝日期在今天之前且還沒繳（疑似已繳的不算）
    private func isOverdue(_ item: Snapshot.DueItem) -> Bool {
        guard !item.paidGuess, let d = Formats.daysFromToday(item.date) else { return false }
        return d < 0
    }

    private var hasAnything: Bool {
        return !actions.isEmpty || !snapshot.due.isEmpty || !snapshot.pending.isEmpty || !snapshot.subscriptions.isEmpty
    }

    var body: some View {
        List {
            if !hasAnything {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(Theme.accent)
                        Text("目前沒有事項").font(.headline).foregroundStyle(Theme.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .accessibilityElement(children: .combine)
                }
                .listRowBackground(Theme.card)
            }

            if !actions.isEmpty {
                Section("待處理") {
                    ForEach(actions) { (item: Snapshot.ActionItem) in
                        actionRow(item)
                    }
                }
                .listRowBackground(Theme.card)
            }

            if !sortedDue.isEmpty {
                Section("近期帳單") {
                    ForEach(sortedDue) { (item: Snapshot.DueItem) in
                        dueRow(item)
                    }
                }
                .listRowBackground(Theme.card)
            }

            if !snapshot.pending.isEmpty {
                Section {
                    ForEach(snapshot.pending) { (item: Snapshot.PendingItem) in
                        HStack {
                            Text(Formats.shortDate(item.date)).foregroundStyle(Theme.text2)
                            Text(item.category).foregroundStyle(Theme.text)
                            Spacer()
                            Text(Formats.money(item.amount)).monospacedDigit().foregroundStyle(Theme.text)
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("待確認")
                } footer: {
                    Text("這幾筆還缺分類或用途，電腦端整理時會問")
                }
                .listRowBackground(Theme.card)
            }

            if !snapshot.subscriptions.isEmpty {
                Section("訂閱") {
                    ForEach(snapshot.subscriptions) { (sub: Snapshot.Subscription) in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(sub.name).foregroundStyle(Theme.text)
                                Spacer()
                                Text("\(Formats.money(sub.amount)) / \(sub.period)")
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.text)
                            }
                            if !sub.note.isEmpty {
                                Text(sub.note).font(.footnote).foregroundStyle(Theme.text2)
                            }
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                    }
                }
                .listRowBackground(Theme.card)
            }

            if let assets = snapshot.assets, !assets.accounts.isEmpty {
                Section {
                    ForEach(assets.accounts) { (account: Snapshot.Account) in
                        HStack {
                            Image(systemName: account.stale ? "clock.badge.exclamationmark" : "checkmark.circle")
                                .foregroundStyle(account.stale ? Theme.stale : Theme.accent)
                                .accessibilityHidden(true)
                            Text(account.name).foregroundStyle(Theme.text)
                            Spacer()
                            Text(freshness(account)).font(.footnote).foregroundStyle(Theme.text2)
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("帳戶更新")
                } footer: {
                    Text("超過 30 天沒更新會標示")
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
    }

    private func actionRow(_ item: Snapshot.ActionItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(item.label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .overlay(Capsule().stroke(Theme.line.opacity(0.5), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).foregroundStyle(Theme.text)
                if !item.date.isEmpty {
                    let overdue: Bool = (item.kind == "pay") && ((Formats.daysFromToday(item.date) ?? 0) < 0)
                    Text(Formats.shortDate(item.date) + "・" + Formats.relativeDays(item.date))
                        .font(.footnote)
                        .foregroundStyle(overdue ? Theme.over : Theme.text2)
                }
            }
            Spacer()
            if let amount = item.amount {
                Text(Formats.money(amount)).monospacedDigit().foregroundStyle(Theme.text)
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func dueRow(_ item: Snapshot.DueItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).foregroundStyle(Theme.text)
                Text(Formats.shortDate(item.date) + "・" + Formats.relativeDays(item.date))
                    .font(.footnote)
                    .foregroundStyle(isOverdue(item) ? Theme.over : Theme.text2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formats.money(item.amount)).monospacedDigit().foregroundStyle(Theme.text)
                if item.paidGuess {
                    Text("疑似已繳").font(.footnote).foregroundStyle(Theme.text2)
                }
            }
        }
        .frame(minHeight: 44)
        .opacity(item.paidGuess ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
    }
}
