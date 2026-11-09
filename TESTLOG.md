# TESTLOG（金錢盤點 iOS）

## 已測過（沒改到就不重測）
| 項目 | 版本 | 結果 |
|---|---|---|
| 階段 1：CI 編譯、選資料夾、讀 snapshot、寫 entries | v1（0e67583） | CI 成功；實機讀寫未測 |
| v2 雲端編譯 | v2 | CI 成功（run 41712081933） |
| v3 雲端編譯 | v3 | CI 成功（run 41712617877） |
| v5 雲端編譯（首頁第二版） | v5（dc2e161） | CI 成功（run 42567163604，44 秒，0 個 Swift 警告） |

## 還沒測過
| 項目 | 備註 |
|---|---|
| v2 四分頁實機畫面 | 需側載後看 |
| v5 首頁第二版實機畫面 | 三態（有資料／過期／對帳失敗）、算式點列捲動是否到位（id 放在區塊標題上）、深色模式色票、Dynamic Type AX 尺寸大數字換行；側載 MoneyTracker-v5.ipa 後看 |
| v5 退路畫面 | 舊快照（沒有 liquid、cards、fixed_outflows、actions）→ 本月剩餘在最上面＋「設定」列；對帳失敗精簡 JSON（只有 generated_at／generated_time／reconcile_ok／reconcile_issues）→ 大數字「—」；未實測 |
| 手動記帳寫入 entries.json 並被電腦端讀到 | 實機＋電腦端配對 |
| 空資料、缺欄位、entries.json 不存在 | 程式已容錯，未實測 |

## 測試紀錄
| 日期 | 版本 | 測了什麼 | 結果 | 因此改了什麼 |
|---|---|---|---|---|
| 2026-11-04 | v2 | 本機無 Mac／swiftc，只能逐行檢查；已對照真實 snapshot.json 的欄位結構（只看欄位型別，未抄任何數值）核對 Snapshot 模型 | CI run 41712081933 編譯成功（1m37s），一輪過 | 閉包與泛型處全寫明型別 |
| 2026-11-04 | v3 | UX 審查七點（可信度／對比／字級／算式／帳款頁／三態空狀態）；逐行檢查＋CI | CI run 41712617877 編譯成功（1m44s） | 見 commit；實機仍未測 |
| 2026-11-04 | v4 | matched_entry_ids：Snapshot 缺欄位→空陣列（lenient 讀法）；Snapshot.isMatched = entry.matched 或 id 在清單；BudgetFigures 只扣 isMatched=false 的本月記帳；帳款頁標籤用同一函式。App 日誌 AppLog。無測試 target、本機無 Swift，驗證方式＝逐行推演三情境（舊快照無欄位／id 在清單／id 不在清單）＋CI 編譯 | CI run 41713324862 編譯成功（1m49s） | — |
| 2026-11-09 | v5 | 依 DESIGN_v2 重做首頁：Snapshot 新增 liquid／cards／fixed_outflows／actions／accounts[].available／generated_time／reconcile_issues／stale_days（全 optional）；LiquidFigures 扣全部未配對手動記帳；HomeView 七區塊＋直式算式可點捲動＋待處理六種標籤；三態與對帳失敗；色票 9 組 Color Set（淺／深）；RootView 分頁 selection 綁定。本機無 Swift，驗證方式＝逐行推演三情境（新快照全欄位／舊快照缺新欄位／對帳失敗精簡 JSON）＋括號配對計數＋CI 編譯；隱私 grep（4 位以上數字、銀行名、人名）全 repo 0 命中 | CI run 42567163604 編譯成功（44 秒、0 警告）；IPA 重壓為 `C:\Tools\Installers\MoneyTracker\MoneyTracker-v5.ipa`（224,537 bytes，舊 v1 IPA 已刪） | — |
