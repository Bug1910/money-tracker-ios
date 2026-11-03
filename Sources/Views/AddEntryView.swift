// 角色：「手動記帳」表單。輸入金額、類別、日期、是否必要、備註，按儲存就追加進 entries.json。
// 只寫 entries.json，不碰 snapshot.json；電腦端之後會把這些紀錄配對進帳本。
// 類別選項取自快照裡出現過的類別名，這樣手機與電腦的分類一致。
import SwiftUI

struct AddEntryView: View {
    @ObservedObject var store: FolderStore
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""
    @State private var category: String = "其他"
    @State private var date: Date = Date()
    @State private var necessary: Bool = false
    @State private var note: String = ""

    private var categoryNames: [String] {
        var names: [String] = []
        if let snap = store.snapshot {
            for month in snap.months {
                for item in month.categories where !names.contains(item.name) {
                    names.append(item.name)
                }
            }
        }
        if !names.contains("其他") { names.append("其他") }
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

    private var amountValue: Double? {
        let cleaned: String = amountText.replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("金額") {
                    TextField("金額", text: $amountText)
                        .keyboardType(.decimalPad)
                }
                Section("明細") {
                    Picker("類別", selection: $category) {
                        ForEach(categoryNames, id: \.self) { (name: String) in
                            Text(name).tag(name)
                        }
                    }
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    Toggle("必要支出", isOn: $necessary)
                    TextField("備註", text: $note)
                }
            }
            .navigationTitle("手動記帳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(amountValue == nil || store.busy)
                }
            }
            .onChange(of: category) { (_: String, newValue: String) in
                necessary = necessaryNames.contains(newValue)
            }
        }
    }

    private func save() {
        guard let amount = amountValue else { return }
        let now = Date()
        let entry = Entry(
            id: UUID().uuidString,
            amount: amount,
            necessary: necessary,
            date: Formats.dayString(date),
            createdAt: Formats.stampString(now),
            matched: false,
            category: category,
            note: note
        )
        store.addEntry(entry, onDone: { (ok: Bool) -> Void in
            if ok { dismiss() }
        })
    }
}
