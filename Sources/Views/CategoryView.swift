// 角色：分類頁，把一個月的花費依類別由大到小排成橫條。
// 每列＝類別名、橫條（長度＝跟最大類別比）、金額、百分比。刻意不用圓餅圖（使用者定案）。
// 上方可切換月份；必要類別用藍色、其餘用橘色，一眼分得出。
import SwiftUI

struct CategoryView: View {
    let snapshot: Snapshot
    @State private var selectedMonth: String = ""

    private var monthKeys: [String] {
        snapshot.months.map { (m: Snapshot.MonthBlock) -> String in m.month }.reversed()
    }

    private var activeMonth: Snapshot.MonthBlock? {
        if let found = snapshot.months.first(where: { (m: Snapshot.MonthBlock) -> Bool in m.month == selectedMonth }) {
            return found
        }
        return snapshot.thisMonth
    }

    private var sortedCategories: [Snapshot.CategoryAmount] {
        guard let month = activeMonth else { return [] }
        return month.categories.sorted { (a: Snapshot.CategoryAmount, b: Snapshot.CategoryAmount) -> Bool in
            a.amount > b.amount
        }
    }

    var body: some View {
        List {
            Section {
                Picker("月份", selection: $selectedMonth) {
                    ForEach(monthKeys, id: \.self) { (key: String) in
                        Text(key).tag(key)
                    }
                }
                if let month = activeMonth {
                    AmountRow(title: "支出合計", amount: month.spending, emphasize: true)
                }
            }

            Section("支出分類") {
                if sortedCategories.isEmpty {
                    Text("本月無支出").foregroundStyle(Color.primary)
                } else {
                    let maxAmount: Double = sortedCategories.first?.amount ?? 1
                    ForEach(sortedCategories) { (item: Snapshot.CategoryAmount) in
                        CategoryRow(item: item, maxAmount: maxAmount)
                    }
                }
            }
        }
        .onAppear {
            if selectedMonth.isEmpty {
                selectedMonth = snapshot.thisMonth?.month ?? ""
            }
        }
    }
}

struct CategoryRow: View {
    let item: Snapshot.CategoryAmount
    let maxAmount: Double

    private var ratio: Double {
        if maxAmount <= 0 || item.amount <= 0 { return 0 }
        return item.amount / maxAmount
    }

    private var pctText: String {
        guard let pct = item.pct else { return "—" }
        return String(format: "%.1f%%", pct)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name)
                if item.necessary {
                    Text("必要")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                Text(Formats.money(item.amount)).monospacedDigit()
                Text(pctText)
                    .font(.caption)
                    .foregroundStyle(Color.primary)
                    .frame(width: 52, alignment: .trailing)
            }
            RatioBar(ratio: ratio, color: item.necessary ? Color.blue : Color.orange)
        }
        .padding(.vertical, 2)
    }
}
