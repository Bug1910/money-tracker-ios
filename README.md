# 金錢盤點（iOS）

一個只給自己用的記帳 App。電腦端程式把帳本算成 `snapshot.json`，放在雲端硬碟資料夾；
手機 App 讀它、顯示數字，並把手動記帳寫進同資料夾的 `entries.json`，電腦端再配對進帳本。

## 它在做什麼（v2：階段 4＋5）

四個分頁：

| 分頁 | 內容 |
|---|---|
| 首頁 | 剩餘預算（超支變紅）→ 14 天內待繳帳款 → 本月收支 → 前五支出 → 待補資料 → 帳戶合計 |
| 分類 | 單月支出依類別由大到小的橫條＋金額＋百分比，可切月份（不用圓餅圖） |
| 待辦 | 待繳帳款、待補資料、訂閱、搬卡清單、帳戶對帳燈、手動記帳紀錄 |
| 分析 | 近 6 月收支長條圖、本月必要／非必要比例（Canvas 自己畫，無第三方套件） |

右上角「＋」＝手動記帳；左上角齒輪＝選資料夾、重新讀取、看錯誤原文。
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
| `Sources/Models/BudgetCalc.swift` | 把未入帳的手動記帳先扣進剩餘預算 |
| `Sources/Models/FolderStore.swift` | 記住資料夾、讀快照、讀寫 entries.json |
| `Sources/Views/RootView.swift` | 四分頁骨架、工具列按鈕 |
| `Sources/Views/HomeView.swift` | 首頁 |
| `Sources/Views/CategoryView.swift` | 分類頁 |
| `Sources/Views/TodoView.swift` | 待辦頁 |
| `Sources/Views/AnalysisView.swift` | 分析頁（圖） |
| `Sources/Views/AddEntryView.swift` | 手動記帳表單 |
| `Sources/Views/SettingsView.swift` | 設定頁 |
| `Sources/Views/Components.swift` | 共用小零件 |
| `Sources/Assets.xcassets` | App 圖示（目前是純色佔位） |
| `.github/workflows/build_ipa.yml` | 雲端 Mac 編譯出 IPA |

## 怎麼編譯

沒有 Mac 也行：推一個 `v` 開頭的標籤（例如 `v2`），或到 GitHub Actions 手動按 Run workflow。
跑完在該次執行的 Artifacts 下載 `MoneyTracker-<sha>.ipa`，用側載工具裝到 iPhone。
IPA 沒有簽名，側載工具會用你自己的 Apple ID 簽。
