// 角色：待辦頁，把「需要他動手或確認的事」集中一處。
// 分五塊：待繳帳款（全部）、待補資料、訂閱、搬卡清單、帳戶對帳（綠燈＝資料新、橘燈＝太久沒更新）、手動記帳紀錄。
// 待補資料只顯示日期＋金額＋類別，不顯示店名（隱私規則）。
import SwiftUI

struct TodoView: View {
    let snapshot: Snapshot
    let entries: [Entry]

    private var sortedDue: [Snapshot.DueItem] {
        snapshot.due.sorted { (a: Snapshot.DueItem, b: Snapshot.DueItem) -> Bool in a.date < b.date }
    }

    private var recentEntries: [Entry] {
        let sorted: [Entry] = entries.sorted { (a: Entry, b: Entry) -> Bool in a.createdAt > b.createdAt }
        return Array(sorted.prefix(10))
    }

    var body: some View {
        List {
            Section("待繳帳款") {
                if sortedDue.isEmpty {
                    Text("無待繳").foregroundStyle(Color.secondary)
                } else {
                    ForEach(sortedDue) { (item: Snapshot.DueItem) in
                        DueRow(item: item)
                    }
                }
            }

            if !snapshot.pending.isEmpty {
                Section("待補資料") {
                    ForEach(snapshot.pending) { (item: Snapshot.PendingItem) in
                        HStack {
                            Text(Formats.shortDate(item.date))
                                .foregroundStyle(Color.secondary)
                            Text(item.category)
                            Spacer()
                            Text(Formats.money(item.amount)).monospacedDigit()
                        }
                    }
                }
            }

            if !snapshot.subscriptions.isEmpty {
                Section("訂閱") {
                    ForEach(snapshot.subscriptions) { (sub: Snapshot.Subscription) in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(sub.name)
                                Spacer()
                                Text("\(Formats.money(sub.amount)) / \(sub.period)")
                                    .monospacedDigit()
                            }
                            if !sub.note.isEmpty {
                                Text(sub.note)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
            }

            if !snapshot.cardMove.isEmpty {
                Section("搬卡清單") {
                    ForEach(snapshot.cardMove, id: \.self) { (line: String) in
                        Text(line)
                    }
                }
            }

            if let assets = snapshot.assets {
                Section("帳戶對帳") {
                    ForEach(assets.accounts) { (account: Snapshot.Account) in
                        HStack {
                            Circle()
                                .fill(account.stale ? Color.orange : Color.green)
                                .frame(width: 10, height: 10)
                            Text(account.name)
                            Spacer()
                            Text(account.asOf.isEmpty ? "—" : Formats.shortDate(account.asOf))
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    Text("橘燈＝超過 30 天未更新")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }

            if !recentEntries.isEmpty {
                Section("手動記帳") {
                    ForEach(recentEntries) { (entry: Entry) in
                        HStack {
                            Text(Formats.shortDate(entry.date))
                                .foregroundStyle(Color.secondary)
                            Text(entry.category.isEmpty ? "未分類" : entry.category)
                            Spacer()
                            Text(Formats.money(entry.amount)).monospacedDigit()
                            Text(entry.matched ? "已入帳" : "待入帳")
                                .font(.caption)
                                .foregroundStyle(entry.matched ? Color.green : Color.orange)
                        }
                    }
                }
            }
        }
    }
}
