// 角色：App 的骨架。底下四個分頁（首頁／分類／帳款／分析），
// 每頁右上角「＋」開手動記帳、左上角齒輪開設定。
// 還沒選資料夾或讀不到快照時，各分頁改顯示「尚無資料」引導去設定。
import SwiftUI

struct RootView: View {
    @StateObject private var store = FolderStore()
    @State private var showSettings = false
    @State private var showAdd = false

    var body: some View {
        TabView {
            page(title: "首頁") { (snap: Snapshot) -> AnyView in
                AnyView(HomeView(snapshot: snap, entries: store.entries))
            }
            .tabItem { Label("首頁", systemImage: "house") }

            page(title: "分類") { (snap: Snapshot) -> AnyView in
                AnyView(CategoryView(snapshot: snap))
            }
            .tabItem { Label("分類", systemImage: "chart.bar.doc.horizontal") }

            page(title: "帳款") { (snap: Snapshot) -> AnyView in
                AnyView(TodoView(snapshot: snap, entries: store.entries))
            }
            .tabItem { Label("帳款", systemImage: "checklist") }

            page(title: "分析") { (snap: Snapshot) -> AnyView in
                AnyView(AnalysisView(snapshot: snap))
            }
            .tabItem { Label("分析", systemImage: "chart.xyaxis.line") }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
        .sheet(isPresented: $showAdd) {
            AddEntryView(store: store)
        }
        .onAppear {
            if store.folderName != nil && store.snapshot == nil {
                store.reload()
            }
        }
    }

    private var emptyKind: EmptyKind {
        if store.folderName == nil { return .noFolder }
        if store.busy { return .loading }
        return .notFound
    }

    /// 每個分頁共用的外框：導覽列＋工具列按鈕＋空狀態處理＋下拉重新讀取
    private func page(title: String, content: @escaping (Snapshot) -> AnyView) -> some View {
        NavigationStack {
            Group {
                if let snap = store.snapshot {
                    content(snap)
                } else {
                    EmptyStateView(kind: emptyKind, openSettings: { showSettings = true }, retry: { store.reload() })
                }
            }
            .navigationTitle(title)
            .refreshable { store.reload() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAdd = true }) {
                        Image(systemName: "plus")
                    }
                    .disabled(store.folderName == nil)
                }
            }
        }
    }
}
