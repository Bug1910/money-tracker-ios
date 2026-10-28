// 角色：主畫面。
// 由上到下：資料夾（選擇）→ 快照三個數字＋讀取時間（重新讀取）→ 寫入測試 → 狀態／錯誤訊息。
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = FolderStore()
    @State private var picking = false

    var body: some View {
        NavigationStack {
            List {
                Section("資料夾") {
                    LabeledContent("位置", value: store.folderName ?? "未選擇")
                    Button("選擇資料夾") { picking = true }
                }

                Section("快照") {
                    LabeledContent("資料日期", value: store.snapshot?.generatedAt ?? "—")
                    LabeledContent("還能自由花", value: money(store.snapshot?.freeMoney?.freeLeft))
                    LabeledContent("總資產", value: money(store.snapshot?.assets?.total))
                    LabeledContent("讀取時間", value: timeText(store.readAt))
                    Button("重新讀取") { store.reload() }
                        .disabled(store.folderName == nil || store.busy)
                }

                Section("同步測試") {
                    Button("寫入測試") { store.writeTest() }
                        .disabled(store.folderName == nil || store.busy)
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
            .navigationTitle("金錢盤點")
            .overlay {
                if store.busy {
                    ProgressView()
                }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [UTType.folder], allowsMultipleSelection: false) { result in
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

    private func money(_ value: Double?) -> String {
        guard let value = value else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "—"
    }

    private func timeText(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }
}
