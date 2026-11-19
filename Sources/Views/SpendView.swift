// 角色：花費頁（v6）。舊的「分類」「分析」兩頁合在這裡。
// 上面一個切換：「本月」看各分類由大到小的長條（可選月份）；「近三個月」看各分類並排（快照有 recent3 就用，沒有就看三個月合計）。
// 最下面是「最近記帳」：手機上記的最近幾筆，左滑可刪除（刪完下方會出現「復原」）。
import SwiftUI
import Charts

struct SpendView: View {
    let snapshot: Snapshot
    @ObservedObject var store: FolderStore

    @State private var mode: Int = 0
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
        return month.categories
            .filter { (c: Snapshot.CategoryAmount) -> Bool in c.amount > 0 }
            .sorted { (a: Snapshot.CategoryAmount, b: Snapshot.CategoryAmount) -> Bool in a.amount > b.amount }
    }

    private var recentEntries: [Entry] {
        let sorted: [Entry] = store.visibleEntries.sorted { (a: Entry, b: Entry) -> Bool in a.createdAt > b.createdAt }
        return Array(sorted.prefix(6))
    }

    var body: some View {
        List {
            Section {
                Picker("範圍", selection: $mode) {
                    Text("本月").tag(0)
                    Text("近三個月").tag(1)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if mode == 0 {
                monthSections
            } else {
                threeMonthSections
            }

            recentSection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            if selectedMonth.isEmpty { selectedMonth = snapshot.thisMonth?.month ?? "" }
        }
    }

    // MARK: - 本月

    @ViewBuilder
    private var monthSections: some View {
        Section {
            Picker("月份", selection: $selectedMonth) {
                ForEach(monthKeys, id: \.self) { (key: String) in
                    Text(key).tag(key)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            if let month = activeMonth {
                HStack {
                    Text("支出合計").foregroundStyle(Theme.text)
                    Spacer()
                    Text(Formats.money(month.spending))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
            }
        }
        .listRowBackground(Theme.card)

        Section("各項支出") {
            if sortedCategories.isEmpty {
                Text("這個月還沒有支出紀錄").foregroundStyle(Theme.text2)
            } else {
                let top: Double = sortedCategories.first?.amount ?? 1
                ForEach(sortedCategories) { (item: Snapshot.CategoryAmount) in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.name).foregroundStyle(Theme.text)
                            if item.necessary {
                                Text("必要").font(.caption2.weight(.semibold)).foregroundStyle(Theme.text2)
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .overlay(Capsule().stroke(Theme.line.opacity(0.5), lineWidth: 1))
                            }
                            Spacer()
                            Text(Formats.money(item.amount)).monospacedDigit().foregroundStyle(Theme.text)
                            if let pct = item.pct {
                                Text(String(format: "%.0f%%", pct))
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(Theme.text2)
                                    .frame(minWidth: 40, alignment: .trailing)
                            }
                        }
                        AnimatedBar(ratio: top > 0 ? item.amount / top : 0, color: Theme.accent.opacity(item.necessary ? 0.55 : 1))
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - 近三個月

    struct BarPoint: Identifiable {
        let id: String
        let name: String
        let month: String
        let amount: Double
    }

    private func monthLabel(_ key: String) -> String {
        guard key.count >= 7, let n = Int(String(key.suffix(2))) else { return key }
        return "\(n) 月"
    }

    @ViewBuilder
    private var threeMonthSections: some View {
        if let r3 = snapshot.recent3, !r3.rows.isEmpty, !r3.months.isEmpty {
            let labels: [String] = r3.months.map { (m: Snapshot.Recent3Month) -> String in monthLabel(m.month) }
            let rows: [Snapshot.Recent3Row] = Array(r3.rows.prefix(6))
            let points: [BarPoint] = barPoints(rows: rows, labels: labels)
            Section("每月支出") {
                ForEach(r3.months) { (m: Snapshot.Recent3Month) in
                    HStack {
                        Text(monthLabel(m.month)).foregroundStyle(Theme.text)
                        if !m.settled {
                            Text("統計中").font(.footnote).foregroundStyle(Theme.text2)
                        }
                        Spacer()
                        Text(Formats.money(m.spending)).monospacedDigit().foregroundStyle(Theme.text)
                    }
                    .frame(minHeight: 36)
                    .accessibilityElement(children: .combine)
                }
            }
            .listRowBackground(Theme.card)

            Section("主要分類") {
                Chart(points) { (p: BarPoint) in
                    BarMark(
                        x: .value("金額", p.amount),
                        y: .value("分類", p.name)
                    )
                    .position(by: .value("月份", p.month))
                    .foregroundStyle(by: .value("月份", p.month))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale(domain: labels, range: threeMonthColors(count: labels.count))
                .chartLegend(position: .top, alignment: .leading)
                .frame(height: CGFloat(rows.count) * 64 + 40)
                .padding(.vertical, 6)
                .accessibilityHidden(true)

                ForEach(rows) { (row: Snapshot.Recent3Row) in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name).foregroundStyle(Theme.text)
                        Text(zip(labels, row.amounts).map { (pair: (String, Double)) -> String in
                            pair.0 + " " + Formats.money(pair.1)
                        }.joined(separator: "　"))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(Theme.text2)
                    }
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
            .listRowBackground(Theme.card)
        } else {
            let recent: [Snapshot.MonthBlock] = Array(snapshot.months.suffix(3))
            Section("每月支出") {
                if recent.isEmpty {
                    Text("還沒有資料").foregroundStyle(Theme.text2)
                } else {
                    Chart(recent) { (m: Snapshot.MonthBlock) in
                        BarMark(
                            x: .value("月份", monthLabel(m.month)),
                            y: .value("支出", m.spending)
                        )
                        .foregroundStyle(Theme.accent)
                        .cornerRadius(4)
                    }
                    .frame(height: 180)
                    .padding(.vertical, 6)
                    .accessibilityHidden(true)
                    ForEach(recent.reversed()) { (m: Snapshot.MonthBlock) in
                        HStack {
                            Text(monthLabel(m.month)).foregroundStyle(Theme.text)
                            Spacer()
                            Text(Formats.money(m.spending)).monospacedDigit().foregroundStyle(Theme.text)
                        }
                        .frame(minHeight: 36)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .listRowBackground(Theme.card)
        }
    }

    private func barPoints(rows: [Snapshot.Recent3Row], labels: [String]) -> [BarPoint] {
        var list: [BarPoint] = []
        for row in rows {
            for (i, label) in labels.enumerated() {
                let amount: Double = i < row.amounts.count ? max(row.amounts[i], 0) : 0
                list.append(BarPoint(id: row.name + "|" + label, name: row.name, month: label, amount: amount))
            }
        }
        return list
    }

    /// 同一個藍色由淺到深：越新的月份越深
    private func threeMonthColors(count: Int) -> [Color] {
        let all: [Color] = [Theme.accent.opacity(0.3), Theme.accent.opacity(0.6), Theme.accent]
        return Array(all.suffix(max(count, 1)))
    }

    // MARK: - 最近記帳

    @ViewBuilder
    private var recentSection: some View {
        if !recentEntries.isEmpty {
            Section {
                ForEach(recentEntries) { (entry: Entry) in
                    entryRow(entry)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if canDelete(entry) {
                                Button(role: .destructive) {
                                    withAnimation { store.remove(entry) }
                                } label: {
                                    Label("刪除", systemImage: "trash")
                                }
                            }
                        }
                }
            } header: {
                Text("最近記帳")
            } footer: {
                Text("左滑可刪除；已進帳本的不能在這裡刪")
            }
            .listRowBackground(Theme.card)
        }
    }

    private func canDelete(_ entry: Entry) -> Bool {
        return !snapshot.isMatched(entry)
    }

    private func statusText(_ entry: Entry) -> String {
        if snapshot.isMatched(entry) { return "已入帳" }
        if store.isPending(entry) { return "待寫入" }
        return "待入帳"
    }

    private func entryRow(_ entry: Entry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.category.isEmpty ? "未分類" : entry.category).foregroundStyle(Theme.text)
                Text(Formats.shortDate(entry.date) + "　" + statusText(entry))
                    .font(.footnote)
                    .foregroundStyle(Theme.text2)
            }
            Spacer()
            Text(Formats.money(entry.amount)).monospacedDigit().foregroundStyle(Theme.text)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
