# 首頁第二版設計規格（DESIGN v2）

2026-11-09。只放版面、用語、欄位；不放任何真實金額、店名、帳號。範例數字一律寫 `XX,XXX`／`N`。
目標使用者需求原話：「每天的額度以及還剩下多少錢，以及未出帳的信用卡還沒繳款的，還有必定開支的，我最上面只留下我可以使用的流動資金，以及我還有甚麼款項還沒處理」。

## 1. 設計結論（一句話）

第一屏只有兩件事：**「可動用」一個大數字**（底下一行每日額度）＋**「待處理」清單**。其餘（未出帳卡費、必定開支、本月剩餘、帳戶合計）往下捲才看到，而且每一塊都是「可動用」算式裡的一項，點算式任何一行就跳到那一塊。

v1 首頁的「本月收支」「前五支出」從首頁移除（分析頁、分類頁已有），「待補資料」併進「待處理」。

## 2. 參考了誰、取了什麼

| 來源 | 取用的作法 | 不取的 |
|---|---|---|
| Quicken Simplifi「Spending Plan」：Available to Spend ＝ Income − Recurring Expenses − Planned Spending − Savings Goals；帳單、訂閱自動列成一張清單 <https://www.quicken.com/blog/simplifi-spending-plan-better-than-budgeting/> | 一個「可花」數字＝扣完固定支出後的餘額；固定支出列成清單讓人核對 | 它以「月」為週期；本案以「發薪日」為週期 |
| Monarch Money：Fixed／Non-monthly／Flex 三桶，Flex ＝ Income − Fixed − Non-monthly − Goals；社群抱怨「Left to Budget 不反映真正剩多少現金」 <https://www.monarch.com/blog/flex-budgeting-simplify-your-spending-with-just-one-number> <https://help.monarch.com/hc/en-us/articles/360048883631-Understanding-Your-Budget-in-Monarch> | 固定支出與彈性支出分開；**頂部數字必須是真的能動的錢，不是預算差額**（所以本案頂部放「可動用」而不是 v1 的「剩餘預算」） | 類別預算 |
| YNAB：信用卡消費當下就把現金撥進「卡費」類別；付清卡的卡費類別必須等於卡片餘額，不等就警示 <https://support.ynab.com/en_us/paid-in-full-credit-cards-a-guide-Hk56hPMyo.md> | 未出帳卡費視為「已經花掉的現金」，從可動用直接扣 | 信封式手動分配 |
| Safe To Spend／When is pay?／Daily Budget Until Payday（App Store／Play 上架頁）：先扣帳單再把餘額除以距發薪天數；首頁一個大數字＋發薪倒數 <https://apps.apple.com/us/app/-/id6758524287> <https://play.google.com/store/apps/details?id=com.whenispay.app> <https://appgoblin.info/apps/6792426198> | 每日額度 ＝ 可動用 ÷ 距發薪天數；顯示「距發薪 N 天」 | 這些 App 把每日額度當主數字；本案主數字是可動用，每日額度是第二行（他原話「最上面只留下我可以使用的流動資金」） |
| 發卡行說明「statement balance vs current balance」：已出帳與未出帳要分開標、並說清楚要繳哪一個 <https://www.capitalone.com/learn-grow/money-management/statement-balance-vs-current-balance/> | 每張卡分兩列：「未出帳」「已出帳未繳」 | — |
| NN/g 漸進揭露：「一開始只給使用者最重要的少數選項」 <https://www.nngroup.com/articles/progressive-disclosure/> | 算式預設收合；帳戶明細預設收合 | — |
| WCAG 2.2 SC 1.4.3：一般文字 ≥4.5:1，大字（≥18pt 或 ≥14pt 粗體）≥3:1；比值不四捨五入 <https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html> | 第 8 節全部顏色都用公式實算 | — |
| Apple HIG Typography（Dynamic Type 預設 Large：Large Title 34、Title 1 28、Title 2 22、Headline/Body 17、Subheadline 15、Footnote 13、Caption 1 12）<https://developer.apple.com/design/human-interface-guidelines/typography>；HIG 點按目標 ≥44×44 pt <https://developer.apple.com/design/human-interface-guidelines/accessibility> | 全部用文字樣式不寫死 pt；最小字 Footnote 13 | 11 pt Caption 2 不用 |

沒查到：Copilot Money、CWMoney、記帳城市三家官方都沒有公開說明首頁「可花金額」怎麼算（只找到 App Store 頁與新聞轉述），不引用。

## 3. 畫面由上到下

| # | 區塊標籤（畫面上的字） | 第一屏？ | 內容 |
|---|---|---|---|
| 1 | **可動用** | 是 | 大數字；第二行「每日額度 XX,XXX・距發薪 N 天」；第三行收合的「算式」 |
| 2 | **待處理**（N 項） | 是 | 最多 5 列，第 6 列起收成「其餘 N 項」→ 帳款頁 |
| 3 | **未出帳卡費** | 否 | 每張卡一列（未出帳）；有已出帳未繳的卡再多一列 |
| 4 | **必定開支**（至 MM/DD 發薪） | 否 | 下次發薪日前還會扣的固定支出；已扣的灰掉標「已扣」 |
| 5 | **本月剩餘** | 否 | v1「剩餘預算」改名；剩餘／預算、狀態標籤、收合算式 |
| 6 | **帳戶合計** | 否 | 合計一列；各帳戶可用餘額收合；未計入帳戶 |
| 7 | 資料日期 MM/DD HH:mm | 否 | 頁尾一行 |

用語規則：2～4 字名詞；不用「還能自由花」「剩多少」這類口語；按鈕寫動作結果（「展開算式」「收合算式」「全部待處理」）。

### 3.1 可動用（主角）

- 標籤「可動用」（Subheadline 15）。
- 大數字（見第 7 節字級），`monospacedDigit`。正數用一般文字色；**負數**用 `over` 色並在右側加標籤「不足」。數字本身不用綠色——綠色會讓人以為「還很安全」，而這個數字只是事實。
- 第二行：「每日額度 XX,XXX・距發薪 N 天（MM/DD）」（Body 17）。`days_to_payday` 含今天；≤0 或沒有發薪日時這行改成「未設定發薪日」並在待處理多一列（見 3.2）。
- 第三行：`DisclosureGroup` 標題「算式」，預設收合。展開後是一張直式減法表，每列可點，點了捲到對應區塊：

```
帳戶合計（可用餘額）        XX,XXX   → 區塊 6
− 未出帳卡費                 X,XXX   → 區塊 3
− 已出帳未繳                 X,XXX   → 區塊 3
− 必定開支（至 MM/DD）       X,XXX   → 區塊 4
− 待繳款項                     XXX   → 區塊 2
− 保留金                     X,XXX   （設定在電腦端）
− 手動記帳（待入帳）           XXX   → 帳款頁
＝ 可動用                   XX,XXX
```

- 「手動記帳（待入帳）」那一列只在有未配對手動記帳時出現，沿用 `BudgetCalc` 的規則（本月、未配對）；差別是**全部**未配對記帳都扣，不分必要／非必要（現金已經出去了）。
- 為什麼要攤開：v3 審查要求「數字可信度」。一個大數字沒有來源他不會信，攤開後每一項都能點到明細自己對。

### 3.2 待處理

清單，每列：左側 2～4 字類型標籤（膠囊、`line` 色框、文字色）、中間標題、右側金額與日期（或「N 天後」「逾期 N 天」）。排序：逾期 → 今天 → 日期近 → 無日期。

| 類型標籤 | 什麼事 | 來源欄位 |
|---|---|---|
| 待繳 | 要他自己動手繳的帳單（非自動扣款） | `actions[].kind = "pay"` |
| 待轉帳 | 要先把錢搬到某帳戶（例如付房租前轉入） | `kind = "transfer"` |
| 待確認 | 帳本有筆交易不知道是什麼 | `kind = "confirm"`（只放日期＋金額＋類別） |
| 待補資料 | 某帳戶／平台要他匯出資料 | `kind = "data"` |
| 待辦 | 搬卡、訂閱去留這類 | `kind = "todo"`（取代 v1 `card_move`） |
| 設定 | 電腦端設定缺東西（發薪日、保留金） | `kind = "setup"` |

- 標題由電腦端寫，不得含帳號、卡號、店名原文（走既有 `privacy_check`）。
- 0 項時整塊縮成一列「目前無待處理」，不留空白卡片。
- 第 6 項起不顯示，最後一列按鈕「全部待處理（N）」→ 切到帳款頁。
- 列高 ≥44 pt。

### 3.3 未出帳卡費

- 區塊標題右側顯示合計。
- 每張卡：卡名（例「卡 A」，不含卡號）、「未出帳」金額、「結帳 MM/DD」。
- 已出帳未繳的卡再多一列：同卡名、「已出帳未繳」金額、「繳款 MM/DD」；若 `statement_paid = true` 不顯示。
- 簽帳金融卡（`kind = "debit"`）的未入帳扣款不在這裡（它已經反映在帳戶「可用餘額」），**不重複扣**。
- 沒有任何卡費：一列「目前無未出帳卡費」。

### 3.4 必定開支（至 MM/DD 發薪）

- 只列 `date` 在今天～下次發薪日（含）之間、且 `paid = false` 的項目；標題右側顯示合計。
- 已經在帳本偵測到扣款（`paid = true`）的項目仍列出但 60% 透明、右側標「已扣」，讓他知道「房租已經扣了」而不是消失。
- 每列：標題、「MM/DD・自動扣款」或「MM/DD・需手動」、金額。需手動的同時會出現在「待處理」（`kind = "pay"`），兩邊同一筆。

### 3.5 本月剩餘

- v1 的剩餘預算區塊搬到這裡並縮小：一列「剩餘 XX,XXX／預算 XX,XXX」＋狀態標籤（正常／接近上限／已超支）＋收合的「算式」（收入 − 必要支出 − 必要待繳 − 儲蓄目標 − 非必要支出）。
- 不再是首頁第一眼：它是「規劃」數字，「可動用」是「現實」數字；兩個都要，但現實先看。

### 3.6 帳戶合計

- 一列「合計 XX,XXX」＋收合的「各帳戶」（帳戶名、可用餘額、「更新 MM/DD」；`stale = true` 的帳戶整列用 `stale` 色＋警示圖示）。
- `not_counted` 有東西時一列「未計入：A、B」。

## 4. 欄位清單（給電腦端 `phone_page.py`）

欄位名用 snake_case；標「新增」的是 `build_snapshot` 現在沒有的。沒標的沿用現有。

### 4.1 新增 `liquid`（可動用）

| 欄位 | 型別 | 中文說明 |
|---|---|---|
| `liquid.available` 新增 | int | 可動用 ＝ `accounts_available` − `cards_unbilled_total` − `cards_statement_due_total` − `fixed_outflows_total` − `actions_due_total` − `reserve`。App 再扣未配對手動記帳 |
| `liquid.accounts_available` 新增 | int | 流動帳戶可用餘額合計（用 `accounts[].available`，沒有就用 `balance`；`not_counted` 不算） |
| `liquid.cards_unbilled_total` 新增 | int | 所有信用卡未出帳合計 |
| `liquid.cards_statement_due_total` 新增 | int | 已出帳未繳合計 |
| `liquid.fixed_outflows_total` 新增 | int | 必定開支（至發薪日、未扣）合計 |
| `liquid.actions_due_total` 新增 | int | 待處理裡 `kind = pay` 且有金額、不在必定開支裡的合計（避免重複扣） |
| `liquid.reserve` 新增 | int | 保留金（電腦端 `phone_config` 設定；沒設就 0） |
| `liquid.next_payday` 新增 | "YYYY-MM-DD" 或 null | 下次發薪日（規則在 `phone_config`，例：每月 N 日，遇假日提前） |
| `liquid.days_to_payday` 新增 | int 或 null | 今天到發薪日的天數，含今天；null ＝ 未設定 |
| `liquid.daily_allowance` 新增 | int 或 null | `available ÷ days_to_payday`，無條件捨去；`available ≤ 0` 或 `days_to_payday` 為 null 時為 null |

### 4.2 新增 `cards[]`（每張卡一筆）

| 欄位 | 型別 | 中文說明 |
|---|---|---|
| `name` | string | 卡名，不含卡號 |
| `kind` | "credit" / "debit" | 信用卡／簽帳金融卡 |
| `unbilled` | int | 未出帳金額 |
| `closing_date` | "YYYY-MM-DD" 或 "" | 下次結帳日 |
| `statement_amount` | int 或 null | 已出帳本期應繳 |
| `statement_due_date` | "YYYY-MM-DD" 或 "" | 繳款截止日 |
| `statement_paid` | bool | 已繳（帳本偵測到繳款） |
| `as_of` | "YYYY-MM-DD" | 資料日期 |
| `stale` | bool | 超過 `STALE_DAYS` 沒更新 |

### 4.3 新增 `fixed_outflows[]`（必定開支）

| 欄位 | 型別 | 中文說明 |
|---|---|---|
| `title` | string | 例「房租」「電話費」「手機分期」 |
| `amount` | int | 金額 |
| `date` | "YYYY-MM-DD" | 預計扣款日 |
| `account` | string | 從哪個帳戶／卡扣（帳戶名，不含帳號） |
| `auto` | bool | true ＝自動扣款；false ＝要他手動（同時進 `actions` pay） |
| `paid` | bool | 帳本已偵測到扣款（沿用 `_paid_guess` 邏輯） |

電腦端來源：現有 `config.due`（`necessary_due_titles`）＋ `subscriptions`（週期落在窗口內的）合併，窗口＝今天～`next_payday`。

### 4.4 新增 `actions[]`（待處理）

| 欄位 | 型別 | 中文說明 |
|---|---|---|
| `kind` | "pay" / "transfer" / "confirm" / "data" / "todo" / "setup" | 類型，對應 3.2 的標籤 |
| `title` | string | 2～12 字，不含帳號卡號店名 |
| `date` | "YYYY-MM-DD" 或 "" | 期限；空＝無期限 |
| `amount` | int 或 null | 有金額才給 |
| `count` | int 或 null | 「待確認 N 筆」這類用 |
| `target` | "due" / "cards" / "fixed" / "accounts" / "pending" / "" | 點了要去哪一塊 |

電腦端來源：`due` 裡非自動扣款的 → pay／transfer；`pending` 彙總成一筆 confirm（`count`）；`card_move` 每行一筆 todo；缺 `next_payday` 或 `reserve` → setup；`accounts[].stale` → data。

### 4.5 既有欄位要補的

| 欄位 | 說明 |
|---|---|
| `accounts[].available` 新增 | 可用餘額（銀行網頁的「可用餘額」，含未入帳簽帳扣款）；沒有就省略，App 退回 `balance` |
| `generated_time` 新增 | "HH:mm"，配合 `generated_at` 顯示頁尾「資料日期 MM/DD HH:mm」 |
| `reconcile_issues[]` 新增 | 對帳沒過時的帳戶名清單（只放名稱，不放差額）；配合 `reconcile_ok = false` |
| `stale_days` 新增（可選） | 電腦端定義幾天算過期；沒有就用 App 預設 3 |
| `free_money.*`、`months[]`、`assets.*`、`due[]`、`pending[]`、`subscriptions[]`、`matched_entry_ids[]` | 沿用；`card_move[]` 保留一版相容，App 優先讀 `actions` |

隱私：以上所有新欄位都走 `privacy_check`（長數字、帳號格式、星號、檔名、店名黑名單）。`title`／`name` 由人寫在 `phone_config`，不從帳本店名欄抄。

## 5. 三態＋對帳失敗

| 狀態 | 判定 | 可動用區塊 | 待處理 | 其餘區塊 |
|---|---|---|---|---|
| 有資料 | `reconcile_ok = true` 且 `generated_at` 在 `stale_days` 內 | 正常 | 正常 | 正常 |
| 資料過期 | `generated_at` 超過 `stale_days` | 大數字 40% 透明；每日額度那行換成「資料已 N 天未更新」（`stale` 色＋三角圖示）；算式仍可展開 | 正常（它來自設定，不會因過期失真） | 金額 40% 透明；頁尾資料日期用 `stale` 色 |
| 對帳失敗 | `reconcile_ok = false` | 大數字改「—」；下方一行「對帳未通過：帳戶 A、B」（`over` 色＋圖示）；算式不可展開 | 自動多一列「設定」類：「對帳未通過，電腦端重跑」 | 卡費、必定開支照顯示（來自設定）；帳戶合計改「—」 |
| 沒資料 | 無資料夾／讀取中／找不到檔 | 沿用 v3 `EmptyStateView` 三種（選擇資料夾／讀取中／重新讀取＋設定） | — | — |

對帳失敗的前提：電腦端改成**仍然輸出** snapshot（帶 `reconcile_ok = false` 與 `reconcile_issues`），而不是現在的「不產生」。不改的話 App 永遠只會看到「資料過期」，分不出是沒跑還是對帳錯——這點請後端決定。

## 6. 線框圖（iPhone 直式，第一屏到虛線為止）

```
┌──────────────────────────────────────┐
│ ⚙︎            首頁                 ＋ │
├──────────────────────────────────────┤
│ 可動用                               │
│                                      │
│ XX,XXX                               │  ← 44pt 半粗 rounded，等寬數字
│ 每日額度 X,XXX・距發薪 N 天（MM/DD） │  ← Body 17
│ ▸ 算式                               │  ← 收合
│                                      │
│ 待處理（N）                          │
│ ┌────┐                               │
│ │待繳│ 瓦斯費            XXX  3 天後 │
│ │待轉│ 轉入帳戶 B 付房租 X,XXX  5 天後 │
│ │確認│ 不明交易 N 筆          ──     │
│ │待辦│ 電信代繳改卡           ──     │
│ └────┘            全部待處理（N）  › │
│ · · · · · · · · · · · · · · · · · ·  │  ← 第一屏到此（約 700pt 內）
│ 未出帳卡費                    X,XXX  │
│ 卡 A          未出帳   X,XXX 結帳 MM/DD │
│ 卡 B          未出帳     XXX 結帳 MM/DD │
│ 卡 A          已出帳未繳 X,XXX 繳款 MM/DD│
│                                      │
│ 必定開支（至 MM/DD 發薪）     X,XXX  │
│ 房租        MM/DD・自動扣款   X,XXX  │
│ 電話費      MM/DD・自動扣款   X,XXX  │
│ 手機分期    MM/DD・自動扣款   X,XXX  │
│ 水電        MM/DD・自動扣款     XXX 已扣 │  ← 60% 透明
│                                      │
│ 本月剩餘                             │
│ 剩餘 XX,XXX／預算 XX,XXX   [正常]    │
│ ▸ 算式                               │
│                                      │
│ 帳戶合計                     XX,XXX  │
│ ▸ 各帳戶（N）                        │
│ 未計入：帳戶 C                        │
│                                      │
│ 資料日期 MM/DD HH:mm                 │
├──────────────────────────────────────┤
│  首頁    分類    帳款    分析        │
└──────────────────────────────────────┘
```

「算式」展開後（在同一位置往下撐開，不彈視窗）：

```
│ ▾ 算式                               │
│   帳戶合計（可用餘額）     XX,XXX  › │
│   − 未出帳卡費              X,XXX  › │
│   − 已出帳未繳              X,XXX  › │
│   − 必定開支（至 MM/DD）    X,XXX  › │
│   − 待繳款項                  XXX  › │
│   − 保留金                  X,XXX    │
│   − 手動記帳（待入帳）        XXX  › │
│   ＝ 可動用                XX,XXX    │
```

## 7. 字級（全部用 Dynamic Type 文字樣式，不寫死 pt）

| 元素 | 樣式 | 預設 pt | 備註 |
|---|---|---|---|
| 可動用大數字 | `.system(size: 44, weight: .semibold, design: .rounded)` 包在 `@ScaledMetric` | 44 | 唯一自訂尺寸；rounded 是這個 App 的識別，其他地方不用 rounded。AX 尺寸時最多放大到 60 並允許換行 |
| 區塊標籤 | `.subheadline` | 15 | 不全大寫、不加 eyebrow |
| 列文字、每日額度行 | `.body` / `.headline`（金額） | 17 | 金額 `monospacedDigit` |
| 日期、「N 天後」、備註 | `.footnote` | 13 | **最小字級**；不用 `.caption2`（11） |
| 類型標籤膠囊 | `.footnote.weight(.semibold)` | 13 | 1pt `line` 色框、無底色 |
| 狀態標籤（本月剩餘） | `.footnote.weight(.semibold)` | 13 | 底色＝狀態色 15%，字＝狀態色（對比見第 8 節） |

行高用系統預設；清單列最小高度 44 pt；可點的列整列可點（不是只有箭頭）。

## 8. 顏色（WCAG 實算，2026-11-09 用相對亮度公式算過，比值不四捨五入）

不寫死顏色：全部進 Asset Catalog 的 Color Set（Any／Dark 兩個外觀），程式只用名字。

| 代號 | 用途 | 淺色 | 對白底 / 對卡片底 | 深色 | 對黑底 / 對卡片底 |
|---|---|---|---|---|---|
| `bg` | 頁底 | #FFFFFF | — | #000000 | — |
| `card` | 區塊底 | #F2F2F7 | — | #1C1C1E | — |
| `text` | 主文字、大數字 | #1C1C1E | 17.0 / 15.3 | #F5F5F7 | 19.3 / 15.6 |
| `text2` | 日期、備註 | #5B5B60 | 6.8 / 6.1 | #A9A9AE | 9.0 / 7.3 |
| `line` | 分隔線、膠囊框 | #86868B | 3.6 / 3.3（≥3 即可） | #6E6E73 | 4.1 / 3.4 |
| `ok` | 狀態：正常 | #1E7B3A | 5.3 / 4.8 | #4CC26A | 9.2 / 7.5 |
| `warn` | 狀態：接近上限 | #7F6200 | 5.8 / 5.2 | #E6B93F | 11.4 / 9.2 |
| `over` | 狀態：已超支／不足／對帳未通過 | #B3261E | 6.5 / 5.9 | #FF6B61 | 7.5 / 6.1 |
| `stale` | 資料過期、帳戶未更新 | #636368（中性灰） | 6.0 / 5.4 | #A1A1A6 | 8.2 / 6.6 |
| `accent` | 可點的文字、箭頭、主要按鈕底 | #4349C9 | 6.9 / 6.2 | #9DA3FF | 9.1 / 7.4 |
| `on_accent` | 主要按鈕上的字 | #FFFFFF | 對 accent 6.9 | #0E1030 | 對 accent 8.0 |

- 全部文字對底 ≥4.5:1、線條 ≥3:1，兩個外觀都過；沒有一個需要打＊。
- 狀態色色相：ok 138°、warn 46°、over 3°，兩兩相差 ≥40°；`stale` 是中性灰不佔色相；`accent`（靛藍 237°，呼應專案主色 #7C83FF）不當狀態色用。
- 狀態標籤底色＝狀態色 15% 透明疊在 `card` 上，字用狀態色本身（上表已算字對 `card` 底的比值，疊 15% 只會讓底更接近狀態色、對比下降不到 0.3，仍 ≥4.5）。
- 深色模式主要按鈕的字必須用 `on_accent` 深色（白字對 #9DA3FF 只有 2.3:1，不合格）。
- 「可動用」大數字永遠用 `text`，不隨狀態變色；只有負數用 `over`。

## 9. 互動與可及性

- 算式每列、帳戶合計、待處理每列整列可點；VoiceOver 讀法：「未出帳卡費，X,XXX，按兩下前往」。
- 下拉重新讀取沿用；讀取中大數字不閃爍，改在導覽列顯示小轉圈。
- 無自動動畫；展開／收合用系統預設。`Reduce Motion` 開啟時展開不做位移。
- 數字全部 `monospacedDigit`，右對齊；金額千分位沿用 `Formats.money`。
- 第一屏不放任何「評價」字眼（「比平常高」「約 N 倍」），沿用 10/27 審查規則。

## 10. 給後端工程師的交付順序建議

1. `accounts[].available`、`liquid.*`、`generated_time`（首屏能動）
2. `cards[]`、`fixed_outflows[]`（算式各項能點到明細）
3. `actions[]`（取代 `card_move`，待處理清單）
4. `reconcile_ok = false` 時仍輸出＋`reconcile_issues[]`（對帳失敗態）

每一步 App 都要能在欄位缺少時退回：`liquid` 缺 → 首頁顯示 v1 的「本月剩餘」在最上面並加一列「設定：電腦端尚未提供可動用資料」；`cards`／`fixed_outflows`／`actions` 缺 → 該區塊不顯示，不留空卡。
