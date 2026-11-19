// 角色：App 的骨架（v6）。底下四個分頁：首頁／花費／事項／設定。
// 前三頁底部都有一顆大大的「記一筆」按鈕（一步打開記帳畫面）；刪掉記帳後，按鈕上方會出現「復原」。
// 還沒選資料夾或讀不到快照時，各分頁改顯示「尚無資料」引導去設定（記帳仍可用，會先存在手機）。
import SwiftUI

enum AppTab: Hashable {
    case home
    case spend
    case items
    case settings
}

struct RootView: View {
    @StateObject private var store = FolderStore()
    @State private var showAdd = false
    @State private var tab: AppTab = .home
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TabView(selection: $tab) {
            page(title: "首頁") { (snap: Snapshot) -> AnyView in
                AnyView(HomeView(snapshot: snap, entries: store.visibleEntries))
            }
            .tabItem { Label("首頁", systemImage: "house") }
            .tag(AppTab.home)

            page(title: "花費") { (snap: Snapshot) -> AnyView in
                AnyView(SpendView(snapshot: snap, store: store))
            }
            .tabItem { Label("花費", systemImage: "chart.pie") }
            .tag(AppTab.spend)

            page(title: "事項") { (snap: Snapshot) -> AnyView in
                AnyView(ItemsView(snapshot: snap))
            }
            .tabItem { Label("事項", systemImage: "checklist") }
            .tag(AppTab.items)

            SettingsView(store: store)
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Theme.accent)
        .sheet(isPresented: $showAdd) {
            AddEntryView(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
        .onAppear {
            if store.folderName != nil && store.snapshot == nil {
                store.reload()
            }
            store.flushPending()
        }
        .onChange(of: scenePhase) { (_: ScenePhase, newPhase: ScenePhase) in
            // 回到前景：補寫佇列；資料超過一分鐘沒讀就重讀
            if newPhase == .active {
                store.flushPending()
                if store.folderName != nil && !store.busy {
                    if let at = store.readAt {
                        if Date().timeIntervalSince(at) > 60 { store.reload() }
                    } else {
                        store.reload()
                    }
                }
            }
        }
        .task(id: store.lastRemoved?.id) {
            // 「復原」按鈕只留 6 秒
            if store.lastRemoved != nil {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                store.lastRemoved = nil
            }
        }
    }

    private var emptyKind: EmptyKind {
        if store.folderName == nil { return .noFolder }
        if store.busy { return .loading }
        return .notFound
    }

    /// 每個分頁共用的外框：導覽列＋空狀態處理＋下拉重新讀取＋底部「記一筆」
    /// 已有資料再重新讀取時，大數字不閃爍，改在導覽列顯示小轉圈
    private func page(title: String, content: @escaping (Snapshot) -> AnyView) -> some View {
        NavigationStack {
            Group {
                if let snap = store.snapshot {
                    content(snap)
                } else {
                    EmptyStateView(kind: emptyKind, openSettings: { tab = .settings }, retry: { store.reload() })
                        .background(Theme.bg.ignoresSafeArea())
                }
            }
            .navigationTitle(title)
            .refreshable { store.reload() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if store.busy && store.snapshot != nil {
                        ProgressView()
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let removed = store.lastRemoved {
                HStack {
                    Text("已刪除 " + Formats.money(removed.amount))
                        .font(.subheadline)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Button("復原") {
                        withAnimation { store.undoRemove() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 16)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().stroke(Theme.line.opacity(0.18), lineWidth: 1))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Button(action: { showAdd = true }) {
                Label("記一筆", systemImage: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Theme.accent, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("打開記帳畫面，只要輸入金額")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: store.lastRemoved?.id)
    }
}
