// 角色：分析頁，用圖看趨勢。全部用 SwiftUI 的 Canvas（畫布）自己畫，沒有第三方圖表套件。
// 兩張圖：① 近 6 個月收入／支出並排長條  ② 本月「必要／非必要」支出比例條。
// 圖下方都附文字數字，圖只是輔助，看數字也能懂。
import SwiftUI

struct AnalysisView: View {
    let snapshot: Snapshot

    private var recentMonths: [Snapshot.MonthBlock] {
        Array(snapshot.months.suffix(6))
    }

    private var necessaryTotal: Double {
        guard let month = snapshot.thisMonth else { return 0 }
        var sum: Double = 0
        for item in month.categories where item.necessary && item.amount > 0 {
            sum += item.amount
        }
        return sum
    }

    private var otherTotal: Double {
        guard let month = snapshot.thisMonth else { return 0 }
        var sum: Double = 0
        for item in month.categories where !item.necessary && item.amount > 0 {
            sum += item.amount
        }
        return sum
    }

    var body: some View {
        List {
            Section("收支趨勢（近 6 月）") {
                if recentMonths.isEmpty {
                    Text("尚無資料").foregroundStyle(Color.primary)
                } else {
                    TrendChart(months: recentMonths)
                        .frame(height: 180)
                        .padding(.vertical, 4)
                    HStack(spacing: 16) {
                        LegendDot(color: Color.green, text: "收入")
                        LegendDot(color: Color.orange, text: "支出")
                    }
                    .font(.caption)
                    ForEach(recentMonths.reversed()) { (m: Snapshot.MonthBlock) in
                        HStack {
                            Text(m.month)
                            if !m.settled {
                                Text("統計中").font(.caption2).foregroundStyle(Color.primary)
                            }
                            Spacer()
                            Text("\(Formats.money(m.income)) / \(Formats.money(m.spending))")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(Color.primary)
                        }
                    }
                }
            }

            Section("本月支出結構") {
                let total: Double = necessaryTotal + otherTotal
                if total <= 0 {
                    Text("本月無支出").foregroundStyle(Color.primary)
                } else {
                    RatioBar(ratio: necessaryTotal / total, color: Color.blue)
                    AmountRow(title: "必要支出", amount: necessaryTotal)
                    AmountRow(title: "非必要支出", amount: otherTotal)
                }
            }
        }
    }
}

struct LegendDot: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

/// 並排長條圖：每個月兩根（收入綠、支出橘），底下標月份。
struct TrendChart: View {
    let months: [Snapshot.MonthBlock]

    var body: some View {
        VStack(spacing: 4) {
            Canvas { (context: inout GraphicsContext, size: CGSize) in
                var peak: Double = 1
                for m in months {
                    peak = max(peak, m.income, m.spending)
                }
                let count: Int = max(months.count, 1)
                let groupWidth: CGFloat = size.width / CGFloat(count)
                let barWidth: CGFloat = groupWidth * 0.3
                for (index, m) in months.enumerated() {
                    let left: CGFloat = groupWidth * CGFloat(index) + groupWidth * 0.15
                    let incomeHeight: CGFloat = size.height * CGFloat(max(m.income, 0) / peak)
                    let spendHeight: CGFloat = size.height * CGFloat(max(m.spending, 0) / peak)
                    let incomeRect = CGRect(x: left, y: size.height - incomeHeight, width: barWidth, height: incomeHeight)
                    let spendRect = CGRect(x: left + barWidth + 2, y: size.height - spendHeight, width: barWidth, height: spendHeight)
                    context.fill(Path(incomeRect), with: .color(Color.green))
                    context.fill(Path(spendRect), with: .color(Color.orange))
                }
            }
            HStack(spacing: 0) {
                ForEach(months) { (m: Snapshot.MonthBlock) in
                    Text(String(m.month.suffix(2)) + "月")
                        .font(.caption2)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
