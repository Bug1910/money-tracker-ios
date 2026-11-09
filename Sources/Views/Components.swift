// 角色：各畫面共用的小零件（色票、空狀態、橫條、金額列、待繳列、標籤膠囊）。
// 放這裡是為了讓首頁／分類／帳款不要各寫一份同樣的東西。
// 顏色全部來自 Assets.xcassets 的 Color Set（淺色／深色各一組，DESIGN_v2 第 8 節 WCAG 實算），程式只用名字。
import SwiftUI

/// DESIGN_v2 色票。名字對應 Assets.xcassets/<name>.colorset
enum Theme {
    /// 主文字、大數字
    static let text = Color("mt_text")
    /// 日期、備註
    static let text2 = Color("mt_text2")
    /// 分隔線、膠囊框
    static let line = Color("mt_line")
    /// 狀態：正常
    static let ok = Color("mt_ok")
    /// 狀態：接近上限
    static let warn = Color("mt_warn")
    /// 狀態：已超支／不足／對帳未通過
    static let over = Color("mt_over")
    /// 資料過期、帳戶未更新（中性灰）
    static let stale = Color("mt_stale")
    /// 可點的文字、箭頭、主要按鈕底
    static let accent = Color("mt_accent")
    /// 主要按鈕上的字（深色模式是深色，白字對 accent 不合格）
    static let onAccent = Color("mt_on_accent")
}

enum Palette {
    static func color(for status: BudgetStatus) -> Color {
        switch status {
        case .ok: return Theme.ok
        case .warn: return Theme.warn
        case .over: return Theme.over
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
                Button("選擇資料夾", action: openSettings)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.onAccent)
            case .loading:
                ProgressView()
                Text("讀取中").font(.headline)
            case .notFound:
                Image(systemName: "doc.questionmark").font(.largeTitle)
                Text("找不到 snapshot.json").font(.headline)
                Text("請確認資料夾正確，且電腦端已產生快照")
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                HStack {
                    Button("重新讀取", action: retry)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .foregroundStyle(Theme.onAccent)
                    Button("設定", action: openSettings)
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
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

/// 一筆待繳帳款：標題、到期日（幾天後）、金額；疑似已繳的變淡（帳款頁用）
struct DueRow: View {
    let item: Snapshot.DueItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                Text("\(Formats.shortDate(item.date))・\(Formats.relativeDays(item.date))")
                    .font(.footnote)
                    .foregroundStyle(Theme.text2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formats.money(item.amount)).monospacedDigit()
                if item.paidGuess {
                    Text("疑似已繳").font(.footnote).foregroundStyle(Theme.text2)
                }
            }
        }
        .frame(minHeight: 44)
        .opacity(item.paidGuess ? 0.6 : 1.0)
    }
}

/// 2～4 字類型標籤膠囊：1pt line 色框、無底色（DESIGN_v2 第 7 節）
struct TagCapsule: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(
                Capsule().stroke(Theme.line, lineWidth: 1)
            )
    }
}

/// 狀態標籤：底色＝狀態色 15%，字＝狀態色
struct StatusCapsule: View {
    let status: BudgetStatus

    var body: some View {
        Text(Palette.label(for: status))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.color(for: status))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Palette.color(for: status).opacity(0.15))
            .clipShape(Capsule())
    }
}
