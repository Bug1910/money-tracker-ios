// 角色：設定頁（v6，第四個分頁）。管：選同步資料夾、看資料更新時間、補寫還沒進雲端的記帳、版本、App 記錄。
// 系統錯誤原文放在最下面的「狀態」，方便實機除錯；平常用不到。
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: FolderStore
    @State private var picking = false
    @State private var logLines: [String] = []

    private var versionText: String {
        let info: [String: Any] = Bundle.main.infoDictionary ?? [:]
        let short: String = (info["CFBundleShortVersionString"] as? String) ?? "—"
        let build: String = (info["CFBundleVersion"] as? String) ?? "—"
        return short + "（" + build + "）"
    }

    private var dataTimeText: String {
        guard let snap = store.snapshot else { return "—" }
        let day: String = snap.generatedAt ?? "—"
        if let t = snap.generatedTime { return day + " " + t }
        return day
    }

    var body: some View {
        NavigationStack {
            List {
                Section("資料夾") {
                    LabeledContent("位置", value: store.folderName ?? "未選擇")
                    Button(store.folderName == nil ? "選擇資料夾" : "換一個資料夾") { picking = true }
                        .frame(minHeight: 44)
                }
                .listRowBackground(Theme.card)

                Section {
                    LabeledContent("資料更新", value: dataTimeText)
                    LabeledContent("手機讀取", value: timeText(store.readAt))
                    Button("重新讀取") { store.reload() }
                        .disabled(store.folderName == nil || store.busy)
                        .frame(minHeight: 44)
                } header: {
                    Text("資料")
                } footer: {
                    Text("資料由電腦端定時更新；在首頁往下拉也能重新讀取")
                }
                .listRowBackground(Theme.card)

                Section {
                    LabeledContent("等待寫入", value: "\(store.pending.count) 筆")
                    if !store.pending.isEmpty {
                        Button("立即補寫") { store.flushPending() }
                            .frame(minHeight: 44)
                    }
                } header: {
                    Text("記帳")
                } footer: {
                    Text(store.pending.isEmpty ? "記過的帳都已寫進雲端資料夾" : "這些帳已先存在手機，資料夾可寫入時會自動補上")
                }
                .listRowBackground(Theme.card)

                Section("關於") {
                    LabeledContent("版本", value: versionText)
                }
                .listRowBackground(Theme.card)

                Section("記錄（最近 50 行）") {
                    if logLines.isEmpty {
                        Text("尚無記錄").foregroundStyle(Theme.text2)
                    } else {
                        Text(logLines.joined(separator: "\n"))
                            .font(.caption2.monospaced())
                            .foregroundStyle(Theme.text)
                            .textSelection(.enabled)
                    }
                    Button("重新整理記錄") { logLines = AppLog.recent(50) }
                        .frame(minHeight: 44)
                }
                .listRowBackground(Theme.card)

                if let message = store.message {
                    Section {
                        Text(message)
                            .font(.footnote.monospaced())
                            .foregroundStyle(Theme.text)
                            .textSelection(.enabled)
                    } header: {
                        Text(store.isError ? "錯誤" : "狀態")
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .onAppear { logLines = AppLog.recent(50) }
            .navigationTitle("設定")
            .overlay {
                if store.busy {
                    ProgressView()
                }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [UTType.folder], allowsMultipleSelection: false) { (result: Result<[URL], Error>) in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        store.setFolder(url)
                    }
                case .failure(let error):
                    store.showError(error)
                }
            }
        }
    }

    private func timeText(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: date)
    }
}
