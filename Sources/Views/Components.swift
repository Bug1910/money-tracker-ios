// 角色：各畫面共用的小零件（空狀態、橫條、狀態顏色）。
// 放這裡是為了讓首頁／分類／帳款不要各寫一份同樣的東西。
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

enum EmptyKind {
    case noFolder
    case loading
    case notFound
}

/// 還沒讀到快照時各分頁顯示的畫面：未選資料夾／讀取中／找不到 snapshot.json 三種
struct EmptyStateView: View {
    let kind: EmptyKind
    let openSettings: () -> Void
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            switch kind {
            case .noFolder:
                Image(systemName: "folder.badge.questionmark").font(.largeTitle)
                Text("尚未選擇資料夾").font(.headline)
                Button("選擇資料夾", action: openSettings).buttonStyle(.borderedProminent)
            case .loading:
                ProgressView()
                Text("讀取中").font(.headline)
            case .notFound:
                Image(systemName: "doc.questionmark").font(.largeTitle)
                Text("找不到 snapshot.json").font(.headline)
                Text("請確認資料夾正確，且電腦端已產生快照")
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
                HStack {
                    Button("重新讀取", action: retry).buttonStyle(.borderedProminent)
                    Button("設定", action: openSettings).buttonStyle(.bordered)
                }
            }
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
