// 角色：各畫面共用的小零件（空狀態、橫條、狀態顏色）。
// 放這裡是為了讓首頁／分類／待辦不要各寫一份同樣的東西。
import SwiftUI

enum Palette {
    static func color(for status: BudgetStatus) -> Color {
        switch status {
        case .ok: return Color.green
        case .warn: return Color.orange
        case .over: return Color.red
        }
    }

    static func label(for status: BudgetStatus) -> String {
        switch status {
        case .ok: return "正常"
        case .warn: return "接近上限"
        case .over: return "已超支"
        }
    }
}

/// 還沒讀到快照時各分頁顯示的畫面
struct EmptyStateView: View {
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(Color.secondary)
            Text("尚無資料")
                .font(.headline)
            Text("請先選擇同步資料夾")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            Button("前往設定", action: openSettings)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// 一條水平比例條：ratio 0～1
struct RatioBar: View {
    let ratio: Double
    let color: Color

    var body: some View {
        GeometryReader { (proxy: GeometryProxy) -> AnyView in
            let clamped: Double = min(max(ratio, 0), 1)
            let width: CGFloat = proxy.size.width * CGFloat(clamped)
            return AnyView(
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.15))
                    Capsule().fill(color).frame(width: width)
                }
            )
        }
        .frame(height: 8)
    }
}

/// 金額＋標題的一行
struct AmountRow: View {
    let title: String
    let amount: Double?
    var emphasize: Bool = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(Formats.money(amount))
                .font(emphasize ? .headline.monospacedDigit() : .body.monospacedDigit())
        }
    }
}
