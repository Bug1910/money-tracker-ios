// 角色：記帳畫面（v6「只打金額」）。打開就是大數字鍵盤，打金額、按「存」就完成，其他都不用管。
// 日期預設今天、分類交給電腦猜；想補分類／必要／備註／改日期，展開「更多」。
// 存下去先進手機本機佇列（資料不會丟），再背景補寫雲端資料夾；寫不進去會在這裡用白話說明。
// 存完：成功觸覺回饋＋打勾動畫，自動關閉；首頁「今天還能花」立刻反映。
import SwiftUI
import UIKit

struct AddEntryView: View {
    @ObservedObject var store: FolderStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var digits: String = ""
    @State private var showMore = false
    @State private var necessary = false
    @State private var category: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var savedAmount: Int? = nil
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 64

    private static let maxDigits = 8

    private var amountValue: Int? {
        guard let v = Int(digits), v > 0 else { return nil }
        return v
    }

    private var categoryNames: [String] {
        var names: [String] = []
        if let snap = store.snapshot {
            for month in snap.months {
                for item in month.categories where !names.contains(item.name) {
                    names.append(item.name)
                }
            }
        }
        return names
    }

    private var necessaryNames: Set<String> {
        var names: Set<String> = []
        if let snap = store.snapshot {
            for month in snap.months {
                for item in month.categories where item.necessary {
                    names.insert(item.name)
                }
            }
        }
        return names
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 16) {
                        amountDisplay
                        moreSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                keypad
                saveButton
            }
            if let amount = savedAmount {
                successOverlay(amount)
            }
        }
    }

    // MARK: - 上半部

    private var header: some View {
        HStack {
            Button("取消") { dismiss() }
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            Spacer()
            Text("記一筆").font(.headline).foregroundStyle(Theme.text)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var amountDisplay: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("$")
                    .font(.system(size: amountSize * 0.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text2)
                Text(digits.isEmpty ? "0" : Formats.money(Double(digits) ?? 0))
                    .font(.system(size: amountSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(digits.isEmpty ? Theme.text2.opacity(0.5) : Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: digits)
            }
            Text(digits.isEmpty ? "輸入這筆花了多少" : "日期 " + dateLabel)
                .font(.footnote)
                .foregroundStyle(Theme.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(digits.isEmpty ? "金額，尚未輸入" : "金額 " + Formats.money(Double(digits) ?? 0) + " 元")
    }

    private var dateLabel: String {
        if Formats.dayString(date) == Formats.dayString(Date()) { return "今天" }
        return Formats.shortDate(Formats.dayString(date))
    }

    private var moreSection: some View {
        VStack(spacing: 0) {
            Button(action: toggleMore) {
                HStack {
                    Text("更多").foregroundStyle(Theme.text)
                    Text("分類、備註、日期").font(.footnote).foregroundStyle(Theme.text2)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.text2)
                        .rotationEffect(.degrees(showMore ? 180 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(showMore ? "收起" : "展開")

            if showMore {
                VStack(spacing: 12) {
                    Picker("分類", selection: $category) {
                        Text("不分類").tag("")
                        ForEach(categoryNames, id: \.self) { (name: String) in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                    Toggle("必要支出", isOn: $necessary).frame(minHeight: 44)
                    DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date).frame(minHeight: 44)
                    TextField("備註（選填）", text: $note)
                        .frame(minHeight: 44)
                }
                .tint(Theme.accent)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: category) { (_: String, newValue: String) in
            if !newValue.isEmpty { necessary = necessaryNames.contains(newValue) }
        }
    }

    private func toggleMore() {
        if reduceMotion {
            showMore.toggle()
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showMore.toggle() }
        }
    }

    // MARK: - 數字鍵盤

    private let keyRows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["00", "0", "⌫"]
    ]

    private var keypad: some View {
        VStack(spacing: 8) {
            ForEach(keyRows, id: \.self) { (row: [String]) in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { (key: String) in
                        Button(action: { press(key) }) {
                            Group {
                                if key == "⌫" {
                                    Image(systemName: "delete.left")
                                } else {
                                    Text(key)
                                }
                            }
                            .font(.system(.title, design: .rounded).weight(.medium))
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(key == "⌫" ? "刪除一位" : key)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func press(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if key == "⌫" {
            if !digits.isEmpty { digits.removeLast() }
            return
        }
        // 開頭不放 0；最多 8 位數，避免打爆
        if digits.isEmpty && (key == "0" || key == "00") { return }
        if digits.count + key.count > AddEntryView.maxDigits { return }
        digits += key
    }

    // MARK: - 存

    private var saveButton: some View {
        Button(action: save) {
            Text("存")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .opacity(amountValue == nil ? 0.35 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(amountValue == nil || savedAmount != nil)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityLabel("存")
        .accessibilityHint(amountValue == nil ? "先輸入金額" : "記下這一筆")
    }

    private func save() {
        guard let amount = amountValue else { return }
        store.record(amount: amount, necessary: necessary, category: category, note: note, date: date)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if reduceMotion {
            savedAmount = amount
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { savedAmount = amount }
        }
        let wait: Double = (store.notice != nil) ? 2.2 : (reduceMotion ? 0.6 : 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { dismiss() }
    }

    private func successOverlay(_ amount: Int) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 84))
                .foregroundStyle(Theme.accent)
                .transition(.scale)
            Text("已記下").font(.title3.weight(.semibold)).foregroundStyle(Theme.text)
            Text(Formats.money(Double(amount))).font(.title.weight(.semibold).monospacedDigit()).foregroundStyle(Theme.text)
            if let notice = store.notice {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("已記下 " + Formats.money(Double(amount)) + " 元")
    }
}
