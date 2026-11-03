// 角色：設定頁（從左上角齒輪進來）。
// 管三件事：選同步資料夾、手動重新讀取快照、看狀態／錯誤訊息（錯誤顯示系統原文，方便實機除錯）。
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: FolderStore
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var logLines: [String] = []

    var body: some View {
        NavigationStack {
            List {
                Section("資料夾") {
                    LabeledContent("位置", value: store.folderName ?? "未選擇")
                    Button("選擇資料夾") { picking = true }
                }

                Section("快照") {
                    LabeledContent("資料日期", value: store.snapshot?.generatedAt ?? "—")
                    LabeledContent("讀取時間", value: timeText(store.readAt))
                    LabeledContent("記帳筆數", value: String(store.entries.count))
                    Button("重新讀取") { store.reload() }
                        .disabled(store.folderName == nil || store.busy)
                }

                Section("記錄（最近 50 行）") {
                    if logLines.isEmpty {
                        Text("尚無記錄")
                    } else {
                        Text(logLines.joined(separator: "\n"))
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                    Button("重新整理記錄") { logLines = AppLog.recent(50) }
                }

                if let message = store.message {
                    Section {
                        Text(message)
                            .font(.footnote.monospaced())
                            .foregroundStyle(store.isError ? Color.red : Color.primary)
                            .textSelection(.enabled)
                    } header: {
                        Text(store.isError ? "錯誤" : "狀態")
                    }
                }
            }
            .onAppear { logLines = AppLog.recent(50) }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
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
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }
}
