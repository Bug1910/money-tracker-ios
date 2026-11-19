# 金錢盤點（iOS）

一個只給自己用的記帳 App。電腦端程式把帳本算成 `snapshot.json`，放在雲端硬碟資料夾；
手機 App 讀它、顯示數字，並把手動記帳寫進同資料夾的 `entries.json`，電腦端再配對進帳本。

## 它在做什麼（v6）

四個分頁，前三頁底部都有一顆大大的「記一筆」：

| 分頁 | 內容 |
|---|---|
| 首頁 | 今天還能花多少（大數字＋今日已花圓環）、距發薪日幾天＋總共可花、錢花去哪（本月支出圓餅） |
| 花費 | 切換「本月」（各分類長條）／「近三個月」（各分類並排）；底下是最近記帳，左滑可刪除、可復原 |
| 事項 | 待處理、近期帳單（逾期才用紅色）、待確認、訂閱、帳戶更新 |
| 設定 | 選資料夾、資料更新時間、補寫還沒進雲端的記帳、版本、記錄 |

記帳＝只打金額：按「記一筆」→ 大數字鍵盤打金額 → 按「存」（兩步）。分類、必要、備註、日期收在「更多」裡。
存下去先進手機本機佇列，再補寫雲端資料夾的 `entries.json`（寫不進去也不會丟，之後自動補）。
App 只寫 `entries.json`，**絕不改 `snapshot.json`**。

## 資料不在這裡

這個 repo 是公開的，**只有程式碼**。真實的金額、帳戶、明細都在使用者自己的雲端資料夾，
`.gitignore` 已排除所有 `.json`／`.csv`／`.pdf` 與 `data/`。程式碼與測試資料不得出現真實金額、店名、帳號。

## 檔案角色

| 檔案 | 角色 |
|---|---|
| `project.yml` | XcodeGen 設定，雲端編譯時用它產生 Xcode 專案檔 |
| `Config/Info.plist` | App 基本資料（顯示名、版本） |
| `Sources/MoneyTrackerApp.swift` | App 大門 |
| `Sources/Models/Snapshot.swift` | 看懂 `snapshot.json`（寬鬆讀法，缺欄位不當掉） |
| `Sources/Models/Entry.swift` | 手動記帳一筆的格式＋金額／日期格式化工具 |
| `Sources/Models/BudgetCalc.swift` | 把未入帳的手動記帳先扣進「今天還能花」「總共可花」（只做加減） |
| `Sources/Models/FolderStore.swift` | 記住資料夾、讀快照、記帳先進本機佇列再補寫 entries.json、刪除／復原 |
| `Sources/Models/AppLog.swift` | App 自己的日誌（Documents/logs，留 7 天，不記金額店名帳號） |
| `Sources/Views/RootView.swift` | 四分頁骨架、底部「記一筆」按鈕、刪除後的「復原」 |
| `Sources/Views/HomeView.swift` | 首頁 |
| `Sources/Views/SpendView.swift` | 花費頁（本月／近三個月圖表＋最近記帳） |
| `Sources/Views/ItemsView.swift` | 事項頁 |
| `Sources/Views/AddEntryView.swift` | 記帳畫面（大數字鍵盤，只打金額） |
| `Sources/Views/SettingsView.swift` | 設定頁（第四個分頁） |
| `Sources/Views/Components.swift` | 共用小零件＋色票 `Theme`（名字對應 Assets 的 Color Set） |
| `Sources/Assets.xcassets` | App 圖示（目前是純色佔位）＋ 11 組 `mt_*` 顏色（淺色／深色各一，WCAG 實算見 DESIGN_v2 第 8 節） |
| `.github/workflows/build_ipa.yml` | 雲端 Mac 編譯出 IPA |

## 怎麼編譯

沒有 Mac 也行：推一個 `v` 開頭的標籤（例如 `v2`），或到 GitHub Actions 手動按 Run workflow。
跑完在該次執行的 Artifacts 下載 `MoneyTracker-<sha>.ipa`，用側載工具裝到 iPhone。
IPA 沒有簽名，側載工具會用你自己的 Apple ID 簽。
