// 角色：App 的大門。
// 開 App 時只做一件事：把主畫面 ContentView 擺出來。
import SwiftUI

@main
struct MoneyTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
