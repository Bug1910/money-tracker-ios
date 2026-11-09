// 角色：App 的骨架。底下四個分頁（首頁／分類／帳款／分析），
// 每頁右上角「＋」開手動記帳、左上角齒輪開設定。
// 還沒選資料夾或讀不到快照時，各分頁改顯示「尚無資料」引導去設定。
// 首頁的「全部待處理」「手動記帳（待入帳）」會切到帳款頁，所以分頁用 selection 綁定。
import SwiftUI

enum AppTab: Hashable {
    case home
    case category
    case todo
    case analysis
}

struct RootView: View {
    @StateObject private var store = FolderStore()
    @State private var showSettings = false
    @State private var showAdd = false
    @State private var tab: AppTab = .home

    var body: some View {
        TabView(selection: $tab) {
            page(title: "首頁") { (snap: Snapshot) -> AnyView in
                AnyView(HomeView(snapshot: snap, entries: store.entries, openTodo: { tab = .todo }))
            }
            .tabItem { Label("首頁", systemImage: "house") }
            .tag(AppTab.home)

            page(title: "分類") { (snap: Snapshot) -> AnyView in
                AnyView(CategoryView(snapshot: snap))
            }
            .tabItem { Label("分類", systemImage: "chart.bar.doc.horizontal") }
            .tag(AppTab.category)

            page(title: "帳款") { (snap: Snapshot) -> AnyView in
                AnyView(TodoView(snapshot: snap, entries: store.entries))
            }
            .tabItem { Label("帳款", systemImage: "checklist") }
            .tag(AppTab.todo)

            page(title: "分析") { (snap: Snapshot) -> AnyView in
                AnyView(AnalysisView(snapshot: snap))
            }
            .tabItem { Label("分析", systemImage: "chart.xyaxis.line") }
            .tag(AppTab.analysis)
        }
        .tint(Theme.accent)
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
    /// 已有資料再重新讀取時，大數字不閃爍，改在導覽列顯示小轉圈（DESIGN_v2 第 9 節）
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
                    HStack(spacing: 12) {
                        if store.busy && store.snapshot != nil {
                            ProgressView()
                        }
                        Button(action: { showAdd = true }) {
                            Image(systemName: "plus")
                        }
                        .disabled(store.folderName == nil)
                    }
                }
            }
        }
    }
}
