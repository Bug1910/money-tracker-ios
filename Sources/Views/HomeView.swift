// 角色：首頁（v6）。第一屏只有三塊：
// ① 今天還能花多少（大數字＋今日已花圓環）  ② 距發薪日幾天＋總共可花  ③ 錢花去哪（本月支出圓餅）
// 數字全部是電腦端算好的快照；App 只把「手機上剛記、電腦還沒配對」的記帳加減進去（見 BudgetCalc.swift 的 TodayFigures）。
// 超支用平靜的中性色文字呈現（「今天多花 N」），紅色只留給帳單逾期。
import SwiftUI
import Charts

struct HomeView: View {
    let snapshot: Snapshot
    let entries: [Entry]

    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 58

    private var today: TodayFigures? {
        return TodayFigures.make(snapshot: snapshot, entries: entries)
    }

    private var liquidFigures: LiquidFigures? {
        return LiquidFigures.make(snapshot: snapshot, entries: entries)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                paydayCard
                spendCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    // MARK: - ① 今天還能花

    private var heroTitle: String {
        if snapshot.reconcileFailed { return "今天還能花" }
        if let t = today { return t.isOver ? "今天多花" : "今天還能花" }
        return "本月還能花"
    }

    private var heroValue: String {
        if snapshot.reconcileFailed { return "—" }
        if let t = today { return Formats.money(abs(t.left)) }
        if let b = BudgetFigures.make(snapshot: snapshot, entries: entries) { return Formats.money(abs(b.left)) }
        return "—"
    }

    private var heroCaption: String? {
        if snapshot.reconcileFailed { return "帳目對不起來，先不顯示數字" }
        if let t = today {
            if t.spentToday > 0 { return "今天已花 " + Formats.money(t.spentToday) }
            return "今天還沒花錢"
        }
        return nil
    }

    private var heroAccessibility: String {
        if snapshot.reconcileFailed { return "今天還能花，目前不顯示，帳目對不起來" }
        let tail: String = heroCaption.map { (c: String) -> String in "，" + c } ?? ""
        return heroTitle + " " + heroValue + " 元" + tail
    }

    private var ringProgress: Double? {
        if snapshot.reconcileFailed { return nil }
        guard let pct = today?.ringPct else { return nil }
        return pct / 100
    }

    private var heroCard: some View {
        VStack(spacing: 12) {
            Text(heroTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.text2)

            ZStack {
                if let progress = ringProgress {
                    TodayRing(progress: progress)
                        .frame(maxWidth: 250)
                        .aspectRatio(1, contentMode: .fit)
                }
                VStack(spacing: 4) {
                    Text(heroValue)
                        .font(.system(size: heroSize, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: heroValue)
                    if let caption = heroCaption {
                        Text(caption)
                            .font(.footnote)
                            .foregroundStyle(Theme.text2)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, ringProgress != nil ? 44 : 0)
            }
            .frame(maxWidth: .infinity)

            if let issue = notTrustReason {
                Label(issue, systemImage: "clock.arrow.circlepath")
                    .font(.footnote)
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
            }
        }
        .mtCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heroAccessibility)
    }

    /// 資料過期、日期不明這類「數字可能不是最新」的提醒；對帳失敗已在大數字處說明
    private var notTrustReason: String? {
        if snapshot.reconcileFailed { return nil }
        return snapshot.dataIssue
    }

    // MARK: - ② 發薪日與總共可花

    private var paydayCard: some View {
        let available: Double? = liquidFigures?.available
        let days: Int? = snapshot.liquid?.daysToPayday
        let availableText: String = snapshot.reconcileFailed ? "—" : Formats.money(available.map { (v: Double) -> Double in abs(v) })
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("距發薪日").font(.subheadline).foregroundStyle(Theme.text2)
                Text(days != nil ? "\(days ?? 0) 天" : "—")
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 4) {
                Text((available ?? 0) < 0 ? "總共超出" : "總共可花").font(.subheadline).foregroundStyle(Theme.text2)
                Text(availableText)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: availableText)
                Text("已先扣卡費與固定支出")
                    .font(.caption)
                    .foregroundStyle(Theme.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
        .mtCard()
    }

    // MARK: - ③ 錢花去哪

    struct SpendSlice: Identifiable {
        let id: Int
        let name: String
        let amount: Double
        let pct: Double?
        let color: Color
    }

    private var slices: [SpendSlice] {
        var list: [SpendSlice] = []
        if let compo = snapshot.compo, !compo.segments.isEmpty {
            for (i, seg) in compo.segments.enumerated() where seg.amount > 0 {
                list.append(SpendSlice(id: i, name: seg.name, amount: seg.amount, pct: seg.pct, color: Theme.slice(i)))
            }
            if let rest = compo.rest, rest.amount > 0 {
                list.append(SpendSlice(id: 99, name: "其他", amount: rest.amount, pct: rest.pct, color: Theme.slice(9)))
            }
        }
        return list
    }

    /// 沒有 compo 的舊快照：退回 months 最後一個月的前幾大類
    private var fallbackCategories: [Snapshot.CategoryAmount] {
        guard let month = snapshot.months.last else { return [] }
        let sorted: [Snapshot.CategoryAmount] = month.categories
            .filter { (c: Snapshot.CategoryAmount) -> Bool in c.amount > 0 }
            .sorted { (a: Snapshot.CategoryAmount, b: Snapshot.CategoryAmount) -> Bool in a.amount > b.amount }
        return Array(sorted.prefix(5))
    }

    private var spendMonthLabel: String {
        let key: String = snapshot.compo?.month ?? snapshot.months.last?.month ?? ""
        guard key.count >= 7, let n = Int(String(key.suffix(2))) else { return "本月" }
        return "\(n) 月"
    }

    private var spendTotal: Double {
        if let t = snapshot.compo?.total { return t }
        var sum: Double = 0
        for s in slices { sum += s.amount }
        return sum
    }

    private var spendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("錢花去哪").font(.headline).foregroundStyle(Theme.text)
                Spacer()
                Text(spendMonthLabel).font(.subheadline).foregroundStyle(Theme.text2)
            }
            if !slices.isEmpty {
                SpendDonut(slices: slices, total: spendTotal)
                ForEach(slices) { (s: SpendSlice) in
                    HStack(spacing: 10) {
                        Circle().fill(s.color).frame(width: 10, height: 10).accessibilityHidden(true)
                        Text(s.name).foregroundStyle(Theme.text)
                        Spacer()
                        Text(Formats.money(s.amount)).monospacedDigit().foregroundStyle(Theme.text)
                        Text(pctText(s.pct))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(Theme.text2)
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                    .font(.subheadline)
                    .frame(minHeight: 28)
                    .accessibilityElement(children: .combine)
                }
            } else if !fallbackCategories.isEmpty {
                let top: Double = fallbackCategories.first?.amount ?? 1
                ForEach(fallbackCategories) { (c: Snapshot.CategoryAmount) in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(c.name).foregroundStyle(Theme.text)
                            Spacer()
                            Text(Formats.money(c.amount)).monospacedDigit().foregroundStyle(Theme.text)
                        }
                        .font(.subheadline)
                        AnimatedBar(ratio: top > 0 ? c.amount / top : 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                Text("這個月還沒有支出紀錄")
                    .font(.subheadline)
                    .foregroundStyle(Theme.text2)
            }
        }
        .mtCard()
    }

    private func pctText(_ pct: Double?) -> String {
        guard let pct = pct else { return "" }
        return String(format: "%.0f%%", pct)
    }
}

/// 今日已花圓環：從 0 轉到目前比例；超過今天額度也只是轉滿一圈，不變紅
struct TodayRing: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Theme.line.opacity(0.18), lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(drawn, 0), 1)))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
        .onAppear { update() }
        .onChange(of: progress) { (_: Double, _: Double) in update() }
    }

    private func update() {
        if reduceMotion {
            drawn = progress
        } else {
            withAnimation(.easeOut(duration: 0.9)) { drawn = progress }
        }
    }
}

/// 本月支出甜甜圈（Swift Charts 的 SectorMark），中央放合計；進場淡入＋微放大
struct SpendDonut: View {
    let slices: [HomeView.SpendSlice]
    let total: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Chart(slices) { (s: HomeView.SpendSlice) in
                SectorMark(
                    angle: .value("金額", s.amount),
                    innerRadius: .ratio(0.64),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(s.color)
            }
            .chartLegend(.hidden)
            VStack(spacing: 2) {
                Text("本月支出").font(.caption).foregroundStyle(Theme.text2)
                Text(Formats.money(total))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.text)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.horizontal, 30)
        }
        .frame(height: 190)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) { appeared = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("本月支出圓餅圖，合計 " + Formats.money(total) + " 元，明細見下方清單")
    }
}
