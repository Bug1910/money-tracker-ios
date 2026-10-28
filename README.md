# 金錢盤點（iOS）

一個只給自己用的記帳小 App。這一版是「階段 1 小實驗」，只想確認一件事：
**手機 App 能不能透過 iOS「檔案」App 裡的雲端硬碟，跟電腦讀寫同一個資料夾。**

## 它在做什麼

1. 按「選擇資料夾」，在「檔案」裡挑一個雲端硬碟上的資料夾，App 會記住它
2. App 讀資料夾裡的 `snapshot.json`（電腦端程式算好的金錢快照），顯示三個數字：資料日期、還能自由花、總資產，以及讀取時間
3. 按「寫入測試」，App 在同一個資料夾的 `entries.json` 追加一筆 1 元的測試紀錄，電腦端看得到就代表雙向同步成功
4. 出錯時畫面直接顯示系統錯誤原文，方便實機除錯

## 資料不在這裡

這個 repo 是公開的，**只有程式碼**。真實的金額、帳戶、明細都在使用者自己的雲端資料夾，
`.gitignore` 已排除所有 `.json`／`.csv`／`.pdf` 與 `data/`。

## 檔案角色

| 檔案 | 角色 |
|---|---|
| `project.yml` | XcodeGen 設定，雲端編譯時用它產生 Xcode 專案檔 |
| `Config/Info.plist` | App 基本資料（顯示名、版本） |
| `Sources/MoneyTrackerApp.swift` | App 大門 |
| `Sources/ContentView.swift` | 主畫面 |
| `Sources/FolderStore.swift` | 記住資料夾、讀快照、寫測試紀錄 |
| `Sources/Snapshot.swift` | 看懂 `snapshot.json` |
| `Sources/Assets.xcassets` | App 圖示（目前是純色佔位） |
| `.github/workflows/build_ipa.yml` | 雲端 Mac 編譯出 IPA |

## 怎麼編譯

沒有 Mac 也行：推一個 `v` 開頭的標籤（例如 `v1`），或到 GitHub Actions 手動按 Run workflow。
跑完在該次執行的 Artifacts 下載 `MoneyTracker-<sha>.ipa`，用側載工具裝到 iPhone。
IPA 沒有簽名，側載工具會用你自己的 Apple ID 簽。
