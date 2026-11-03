// 角色：App 的大門。
// 開 App 時只做一件事：把主骨架 RootView 擺出來。
import SwiftUI

@main
struct MoneyTrackerApp: App {
    init() {
        AppLog.purgeOld()
        AppLog.write("App 啟動")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
