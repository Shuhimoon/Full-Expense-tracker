# Full 記帳 v1 開發文檔

狀態：可實作。未標「非 v1」的都是這版要做。
基準日：2026-08-29。基準幣：TWD。時區：Asia/Taipei。
架構已定（2026-08-29 御芳拍板）：正規 App＝PostgreSQL 關聯式資料庫＋後端 API＋可安裝 PWA。系統來源是資料庫，不是筆記、不是本機 JSON／IndexedDB。 **（2026-10-20 改 Flutter：前端由 PWA 改為 Flutter App＋Flutter web；後端與 DB 不變。）**

---

## 1. 產品目標與使用情境

一個人的記帳本，必須登入。日常花多少、帳戶剩多少、股票和加密貨幣入場花多少、現在值多少、累積賺賠。可開多本（生活、投資、某專案），一次只看一本；帳戶／流水／持倉／統計都跟著當前這本。資料只屬於登入者，不分享。

目標使用者：御芳，人在台灣，自己記、自己看。不做家庭、不做會計師、不做報稅。

v1 成功長這樣：

- 今天午餐 180，從中信活存扣，本月餐飲看得到。
- 玉山卡欠款是負債，淨資產有扣。
- 富邦證券裡的 2330：成本、現值、未實現、這本帳開帳後賣過的已實現、累計，一檔一頁。
- Binance 的 BTC 同上。USDT 當持倉，不當第二本外幣帳。
- 開帳用快照，不補十年流水。
- 首頁月曆看到今天花多少、點一天看當天流水；圓餅看本月錢花在哪類，摺線看每天花多少。

筆記、投資邏輯、月檢討寫 Craft。App 裡只有單筆短備註。記帳資料不准進 Craft 表格，也不做 Craft API。

---

## 2. v1 做／不做

### 做

- 日常支出、收入、轉帳（含還卡）。
- 帳戶餘額；信用卡當負債。
- 股票＋加密貨幣成交：買、賣、轉入、轉出、現金股利、空投／股票股利。
- 持倉：數量、剩餘成本、現值、未實現、已實現、累計損益。
- 現況快照開帳：一個開帳日、各帳戶現金餘額、各檔現倉數量＋總成本 TWD。
- 成本：移動平均，按「帳戶 × 標的」分開算。
- 現價：公開報價，失敗或沒有就手改；手改可鎖，鎖了自動報價不准覆蓋。
- 淨資產、本月收支、持倉損益。
- 首頁月曆：每日支出合計；點一天看當天流水；今天高亮並顯示今日已花。
- 首頁圖表：本月每日支出摺線（可切收入、現金淨資產走勢）；本月支出分類圓餅。
- 正規 App：PostgreSQL 分表 ＋ 後端 API ＋ Flutter 前端（iOS／Android／macOS／web 同一套 Dart 程式碼）。（改 Flutter，2026-10-20；原為可安裝 PWA）
- 帳號登入（email＋密碼）。未登入不能記、不能開帳、不能看圖／日曆。
- 可多本帳本，每本獨立開帳日與快照。切換後只看當前這本。不分享、沒有邀請。
- 前端只經 API 讀寫。跨裝置看到同一 user 的同一份 DB。
- 整包 JSON 匯出／還原只當備份檔。還原是打 API 寫回資料表，JSON 不是資料庫、不是開帳輸入。

### 不做（非 v1）

- 券商／交易所／銀行 CSV 或 OFX 整批匯入。
- CSV 當正式流水重播歷史。
- 預算、信封、額度警示。
- 銀行／券商／鏈上自動同步。
- 多幣別帳簿（帳戶不記 USD 餘額當第二本帳）。
- FIFO／個別辨認成本。
- 選擇權、期貨、融資融券、槓桿、合約。
- 報稅表、分離課稅、已實現匯出給會計。
- 多人、共用、權限。
- 定期交易自動產生。
- 發票／收據照片。
- 價格到價通知、目標、FIRE。
- Craft 雙向同步。
- 原生 App（Swift/Kotlin）分開寫三套。v1 前端是 Flutter 一套（改 Flutter，2026-10-20；原為 PWA）。
- 本機 JSON、IndexedDB、localStorage 當帳本正本。
- 未登入在本機開正式帳。
- 本機覆蓋雲端／最後寫入贏的用戶端合併。

已定死、不准再問：開帳＝現況快照；成本＝移動平均；基準＝TWD；系統來源＝Postgres＋API。

---

## 3. 平台與架構

### 3.1 三端 UI

**Flutter 一套前端（改 Flutter，2026-10-20；原為可安裝 PWA）。** 不寫原生 Swift／Kotlin 三套。畫面照 Doop 重做。

- iOS／Android：Flutter App。v1 不靠推播。
- Flutter web：同一套程式碼 build web，供瀏覽器使用與**UI 驗收截圖**（不需 Docker）。
- Mac：Flutter macOS 或 Flutter web。
- 離線：可看上次 API 成功的畫面快取。不能寫入正式帳。連線後重送失敗的那次 API（見 3.4）。

### 3.2 系統來源（已定）

```
Flutter──HTTPS JSON──▶ Go/chi ──pgx──▶ PostgreSQL
                         │
                         └─ 報價／FX 外部 API（寫入 Quote、FxRate 表）
```

- **正本只在 PostgreSQL。** Book / Account / Category / Entry / Instrument / Position / Trade / Quote / FxRate 各一張表，有 PK、FK、NOT NULL、check。禁止一份大 JSON 當帳本，禁止 IndexedDB／localStorage／檔案當主資料。
- 前端**只經 API**讀寫。畫面數字以 API 回應為準。前端可快取 GET 加速顯示（Flutter 記憶體／本機快取），寫入成功後用回應覆寫快取；快取不是帳本。
- Craft 只放筆記。記帳資料不准進 Craft、不准進本機筆記檔。
- JSON 匯出是備份檔。開帳不吃 JSON、不吃 CSV。還原＝登入後呼叫還原 API，在**一筆 DB transaction**裡寫進各表。

### 3.5 UI 驗收規則（2026-10-20 已定）

- UI 驗收＝**Flutter web 實機截圖對 Doop frame**（同寬 390×844，逐頁並排），比版面、元件、圖示、文字、顏色；不只對結構／路由／主色。
- 不需 Docker：Flutter web 連可用的 API（測試庫）即可截圖。
- 每頁附截圖路徑與對應 frame id 提驗收；落差逐項列出。

### 3.3 技術選型（已定，不再問）

| 層 | 選定 |
| --- | --- |
| 資料庫 | PostgreSQL 16。UUID PK。金額用 `bigint`（TWD 元）。數量／單價用 `numeric`。遷移用 golang-migrate。 |
| 後端 | Go 1.22+。HTTP 用 chi。資料庫用 pgx（參數化 SQL，不用 ORM 包整本帳）。REST JSON。一個服務。 |
| 前端 | **Flutter（Dart）**，一套程式碼出 iOS／Android／macOS／web；只經 API。（改 Flutter，2026-10-20；原 React + Vite PWA，`web/` 停用待移除） |
| 鑑權 | Email＋密碼（argon2id）。httpOnly session cookie。所有帳本／統計 API 必須已登入。`books.user_id` 不是 UNIQUE：一 user 多本。請求必須帶當前 book，且 book.user_id = session.user_id，否則 404。 |
| 佈署 | API 與 Postgres 常駐。前端靜態 hosting。v1 單區、單實例即可。 |

表結構用 SQL migration 建，**不要**做成 `ledger_json jsonb` 一欄包整本。Position 是物化表，與 Trade 在**同一 transaction**裡更新；仍必須能從 Trade 重算對帳。

不作：FastAPI、SQLAlchemy、Alembic、CoffeeScript、Express、Python 後端。

### 3.4 登入、暫存、衝突

- **未登入：** 只顯示註冊／登入。開帳、記一筆、持倉、圖表、日曆、帳本列表一律 401。表單暫存在記憶體；登入後丟棄，以 DB 為準。沒有「未登入本機先開正式帳」。
- **註冊：** email＋密碼（至少 8 碼）。email UNIQUE。不做 magic link、不做 OAuth、v1 不做信箱驗證。
- **當前帳本：** users.last_book_id。切換時寫回。所有業務 API 帶 book_id，後端核對所有權。
- **已登入寫入：** `POST/PATCH/DELETE` 進 DB transaction。買／賣必須同一 transaction 更新 Trade ＋ Position（必要時 Entry）。成功回 2xx 與新 `version`。
- **樂觀鎖：** 可更新的列有 `version int NOT NULL DEFAULT 1`。請求帶目前 version；`UPDATE ... WHERE id=? AND version=?` 影響 0 列 → 409，前端重抓再送。**不要**用戶端「最後寫入贏」、**不要**本機蓋伺服器。
- **離線：** GET 快取可看。寫入失敗留在畫面，連線後用同一冪等鍵重送 POST。伺服器用 `Idempotency-Key`（等於客戶端生成的 UUID，當 PK）去重。409 就重抓。
- **還原備份：** 只透過還原 API。覆蓋順序尊重 FK，整包在一筆 transaction。不是把 JSON 載進瀏覽器當 DB。

---

## 4. 信息架構與畫面

五個一級，外加一個記一筆入口。

| 入口 | 幹嘛 |
| --- | --- |
| 首頁 | 今天已花、月曆、圖表、淨資產、本月收支、持倉未實現 |
| 記一筆 | 支出／收入／轉帳／成交。從首頁大按鈕進，任何頁可進 |
| 帳戶 | 類型分組的帳戶列表＋餘額；點進去是該帳戶流水與（若是券商／交易所）持倉 |
| 投資 | 所有未平倉；點一檔看成本／現值／損益／成交 |
| 設定 | 帳本（新增／改名／封存／切換）、開帳、分類、帳戶、備份、登入登出 |

沒有獨立「流水」或「統計」一級，避免手機底欄第六個。流水從月曆點日期進去。帳戶流水在帳戶裡，成交在該檔持倉裡。圖表和月曆都在首頁。

> **2026-10-20 補註（IA 與視覺來源）：** 上表為早期五入口版，已被 Doop 定稿取代：底欄四項「帳本／分析圖／資產／設定」＋浮動 FAB 記一筆；圖表移到獨立「分析圖」頁；帳戶＋持倉合併為「資產」頁。**視覺以 Doop 畫布為準**：https://doop.design/c/jr-EE9CpoR（登入 `Y5Bm0qKqks`、帳本首頁 `1vMhY6OCSe`、記一筆 `q273gYu-Cj`、分析圖 `iH20573wrb`、資產 `HDLHZYbQ_r`、設定 `0N9oT5Ax2q`、開帳 `rZ0KEpCTCs`／`shTyYPkl4-`／`Bkl20hKz5B`；`5Wjm9YUjPA` 由小蘭改稿為「預覽＋儲存」（2026-10-20））。風格指引 `full-accounting-ios-glass`。驗收規則見 §3.5。

空狀態：未登入只顯示註冊／登入。已登入但沒有帳本，只推「建立帳本」（預設名「生活」，可改）。**建立帳本後即可使用**（2026-10-20 規格變更：移除鎖定），不再有「先開帳」閘門；開帳快照為選填，可在設定隨時補／改。

### 4.1 首頁

一級維持五個。統計不另開分頁，全部放首頁，上到下捲。手機優先：數字大、月曆格可點、圖表全寬、圓餅圖例在圖下方不是旁邊。

頂欄：當前帳本名稱（例如「生活」）加 chevron。點開列表切換未封存帳本；「管理帳本」進設定。不另開一級。

上到下：

1. **今天已花 NT$x**（當日 `expense` 合計）。這是日曆的「今天」入口，一眼看得到。旁邊小字本月已花。點「今天已花」＝打開今天的當日流水。
2. 淨資產（TWD）、相對開帳日變化（金額）。持倉現值、未實現（一行小字）。
3. **月曆**（當月，Asia/Taipei）。見 4.1.1。
4. **圖表**：摺線＋圓餅。見 4.1.2。
5. 大按鈕：記一筆（預設今天）。

不再在首頁堆「最近 10 筆」。看流水走月曆。

下拉刷新：拉現價＋FX，並重抓日曆／圖表 API。數字旁顯示報價時間。

#### 4.1.1 月曆

- 一屏一個月。可上一月／下一月。含開帳日的那個月是能往回的最早月（再早的月份進不去）。
- 每一格：日期＋當日支出合計（TWD）。支出＝`Entry.type=expense` 且未刪，不含轉帳、不含成交。0 元顯示「0」或空白都可以，v1 定：**沒支出就空著，有支出才寫金額**（超過 9999 顯示 `1.2萬` 這種縮寫，格內塞得下）。
- **今天**格：框線或底色不同，且格內金額與頂部「今天已花」同一數字。
- 點 ≥ 開帳日的某一天：進當日流水（當日所有 Entry＋Trade，時間序）。可從這裡按記一筆，日期預填該日。
- **開帳日之前的格子：不顯示金額、不可點進去記、視覺淡。** 開帳當日可記。
- （2026-10-20 規格變更：移除鎖定）月曆一律顯示；最早可往回到開帳日所在月份。

#### 4.1.2 圖表

圖庫：前端用 Flutter 圖表套件（如 fl_chart，由實作選定；改 Flutter，2026-10-20，原 recharts）。資料全從 API 來，前端不算帳。

**摺線圖（預設本月每日支出）**

- X＝該月每一天，Y＝當日支出合計（同月曆口徑）。沒記的日子 Y=0。
- 可切兩個系列（同一張圖不要一次疊三種）：本月每日收入；開帳日後「現金淨資產」走勢（每日結束：Σ cash/bank/broker/exchange 現金 − Σ credit_card 欠款。**不含持倉市值**）。
- 不含持倉的原因：v1 不存歷史報價，不能用今天股價假裝昨天的淨資產。圖上切到這條時標「不含持倉」。
- 本月未過完：摺線畫到今天，未來日子不畫。

**圓餅圖：本月支出依分類占比**

- 口徑同本月支出。一分類一瓣。0 的分類不畫。
- 圖例在圖下方，分類名＋金額＋％。手機不要圖例在側邊。
- 點某一瓣或圖例：可列出該分類本月流水（簡易篩選，不必新頁級）。

兩張圖看開帳日（含）之後的資料。寬度跟著螢幕，高度固定約 200–240px，不要桌面儀表板。

### 4.2 記一筆

四個類型，預設支出。切換類型只改要填的欄位，不要拆四個頁。

**支出／收入：** 金額、帳戶、分類、日期、備註。預設今天、上次用的帳戶。

**轉帳：** 金額、轉出帳戶、轉入帳戶、日期、備註。不選分類。還信用卡就是銀行 → 信用卡。

**成交：** 買／賣／轉入／轉出／現金股利／空投。欄位見流程。

存檔＝打 API，成功才更新畫面。沒有本機正式草稿。未登入不能存。

### 4.3 帳戶

五類分組：現金、銀行活存、信用卡、券商、交易所／錢包。

每列：名稱、餘額。信用卡顯示「欠 NT$x」。券商／交易所額外一行「持倉現值」。

新增帳戶：名稱＋類型。v1 帳戶幣別鎖定 TWD。可封存，不可刪（有流水就封存；沒流水可刪）。

### 4.4 投資

列表：標的、帳戶、數量、現值、未實現、未實現％。可按現值或未實現排，預設現值高到低。

點一檔：

- 數量、均價（TWD）、剩餘成本、現值、現價、報價時間、來源（自動／手改）。
- 未實現、已實現（開帳日後）、累計。
- 成交紀錄（含開倉那筆快照）。
- 動作：買、賣、轉出、手改現價。

### 4.5 設定
- 開帳：隨時可改（2026-10-20 規格變更：移除鎖定）。改開帳日時，若已有 Entry／Trade（未刪）早於新開帳日，API 回錯（409／422，訊息「有早於新開帳日的流水」）並擋下。
- 開帳：隨時可改（2026-10-20 規格變更：移除鎖定）。改開帳日時，若已有 Entry／Trade 早於新開帳日則擋下並提示。
- 分類列表：新增、改名、封存。系統預設可改名、可封存、不可刪。
- 備份：匯出／還原都是**當前這本**。JSON 不是資料庫。
- 帳本：列表（未封存／已封存分組）。新增（必填名稱）、改名、封存、取消封存。有帳戶或分錄的不能刪，只能封存。沒資料的可刪。封存中不能記帳、不能開帳、不能寫入；切換器預設不列已封存。
- 登入／登出、改密碼。未登入不能開帳、不能記、不能看圖。
- 關於：基準幣 TWD 寫死、成本法移動平均寫死、正本在 Postgres。

---

## 5. 關鍵流程

### 5.0 註冊、登入、帳本

1. 註冊或登入（email＋密碼）。登入錯誤統一「帳號或密碼不對」。
2. 若沒有未封存帳本：新增一本，名稱必填，預設「生活」可改。這本變成 last_book_id。
3. 若有多本：進入上次那本；頂欄可切。
4. 建立／選好帳本後直接進首頁（2026-10-20 規格變更：不再檢查鎖定開帳）。開帳快照可之後從設定補。
5. 新增第 N 本：設定 → 新增帳本 → 命名 → 切過去 → 獨立走一次開帳。兩本的帳戶／持倉／開帳日互不相通。

### 5.1 開帳

開帳是當前這本的，選填、可分次填、隨時可改（2026-10-20 規格變更：移除鎖定，無 opening_locked）。資料存 DB，不在本機。未登入不能開帳。封存中的帳本不能開帳。

1. 選開帳日。必須是日曆日，建議「能對到銀行／券商／交易所餘額的那天」。
2. 建帳戶，每個填當日現金餘額（規則見 §7）。
3. 建現倉：帳戶（限券商或交易所／錢包）、標的、數量、總成本 TWD（含手續費）。沒成本標「不確定」→ 存成成本 0，未實現會偏大，畫面要標「成本未填」。
4. 預覽淨資產＝Σ現金類餘額 − Σ信用卡欠款 ＋ Σ現倉成本（開帳當下還沒現價就先用成本當現值；有價再改現值）。
5. 儲存。寫入／更新開帳分錄。開帳日之前不可記帳（已定，2026-10-20）。

~~鎖定前可來回改。鎖定後開帳日與開帳分錄不可改。~~ 已移除（2026-10-20 規格變更）：開帳日與開帳分錄任何時候都可改。

### 5.2 記一筆（日常）

1. 選支出或收入。
2. 填金額（TWD 整元）、帳戶、分類、日期（≥ 開帳日）、備註可空。
3. 存：帳戶餘額加減；出現在流水。轉帳不進本月收支。

還卡：轉帳，銀行活存 → 信用卡。兩邊餘額都動。不進損益。

### 5.3 買入

1. 記一筆 → 成交 → 買，或從該檔持倉按買。
2. 帳戶（必須券商或交易所／錢包）、標的、數量、單價、單價幣別（TWD 或 USD）、手續費、日期。
3. 系統算成交總額 TWD＝數量 × 單價 × FX ＋ 手續費 TWD。手續費若原幣不是 TWD，用同一 FX。
4. 扣該帳戶現金。不夠也准記，警告一句，不擋（錢可能從銀行轉、還沒記）。
5. 持倉數量增加；剩餘成本增加成交總額；均價重算。

### 5.4 賣出

1. 成交 → 賣。數量不可大於該「帳戶 × 標的」持倉。
2. 成交總額 TWD＝數量 × 單價 × FX − 手續費 TWD。手續費不得大於成交額，大於就擋下來改。
3. 已實現＝成交總額 − 均價 × 數量。
4. 持倉數量減少；剩餘成本減少 均價 × 數量；均價不變。
5. 該帳戶現金增加成交總額。
6. 數量賣到 0：持倉列移到「已平倉」（投資頁預設隱藏，可展開）。已實現留在該檔累計裡。

### 5.5 看持倉

投資頁 → 一檔。現價用 §8。沒價：現值空白、未實現空白，成本仍顯示。

### 5.6 標的在自己帳戶間搬（例如交易所 → 錢包）

轉出：減少 A 帳戶該檔數量與等比例剩餘成本，不產生已實現。
轉入：B 帳戶增加同一數量、同一成本。兩筆必須成對，一次流程填：標的、數量、轉出帳戶、轉入帳戶、日期。手續費若發生，從轉出帳戶現金扣，記支出「投資費用」，不改變成本（v1 定死，避免搬倉把均價弄髒）。

### 5.7 看日曆與當天流水

1. 首頁看到「今天已花」與當月月曆。
2. 點某一天（≥ 開帳日）→ 當日流水。
3. 可記一筆，日期鎖在該日。存檔後回到該日流水，月曆金額更新。
4. 開帳日前的格子沒反應。

### 5.8 看圖表

1. 首頁往下捲到摺線、圓餅，預設本月。
2. 摺線切收入或現金淨資產。圓餅點分類看該類本月流水。
3. 換月曆月份時，圖表跟著那個月份（現金淨資產切換時 X 軸改成開帳日→今天，不受月曆月份限制）。

---

## 6. 資料模型

這些是 **PostgreSQL 表**，不是 JSON 形狀。id 一律 UUID PK。除 `users` 外，業務表都有 `book_id uuid NOT NULL REFERENCES books(id)`。可更新的表有 `version int NOT NULL DEFAULT 1`。

刪除：Entry／Trade 軟刪（deleted_at）；帳戶與分類封存（archived_at）。金額除非註明，都是整數「元」（`bigint`）。數量與單價用 `numeric`，不可用 float。

FK 摘要：

- `books.user_id → users.id`（一 user 多本，不是 UNIQUE）
- `accounts.book_id`、`categories.book_id`、`instruments.book_id`、`entries.book_id`、`trades.book_id`、`positions.book_id`
- `entries.account_id → accounts`；`entries.to_account_id → accounts`；`entries.category_id → categories`（可空）；`entries.instrument_id → instruments`（可空）
- `trades.account_id → accounts`；`trades.instrument_id → instruments`；`trades.pair_id → trades.id`（可空）
- `positions(account_id, instrument_id)` UNIQUE；兩個 FK
- `quotes.instrument_id → instruments`
- `fx_rates` 全系統或 per book 一列 USD/TWD（v1 per book）

寫入規則：應用層禁止先改 Position 再慢慢補 Trade。賣出超賣在 transaction 裡用 `qty` check 擋下。

### 6.0 User

| 欄位 | 型別 | 規則 |
| --- | --- | --- |
| id | uuid | PK |
| email | citext | UNIQUE，登入識別 |
| password_hash | text | argon2id，不明文、不進匯出 JSON |
| last_book_id | uuid? | FK → books，可空 |
| created_at | timestamptz | |


### 6.1 Book（帳本，一 user 多本）

| 欄位 | 型別 | 規則 |
| --- | --- | --- |
| id | uuid | PK |
| user_id | uuid | FK → users，非 UNIQUE |
| name | text | 必填。同一 user 的未封存帳本名稱不重複 |
| archived_at | timestamptz? | 有值＝封存，不可寫入 |
| base_currency | 'TWD' | 寫死 |
| opening_date | date | 每本自己的；**建立帳本時預設＝建立當日**（Asia/Taipei，已定 2026-10-20）；之後可改，有早於新日期的流水則擋 |
| ~~opening_locked~~ | — | 已移除（2026-10-20 規格變更） |
| timezone | 'Asia/Taipei' | 寫死 |
| cost_method | 'avg' | 寫死 |
| version | int | 樂觀鎖 |

### 6.2 Account

| 欄位 | 型別 | 規則 |
| --- | --- | --- |
| id | uuid | |
| name | string | 必填，同本帳不重名 |
| type | enum | cash / bank / credit_card / broker / exchange |
| archived_at | datetime? | |
| created_at | datetime | |
| version | int | 樂觀鎖 |

餘額不存欄位，由分錄算出。畫面要快可 cache，以分錄為準。

type 決定：cash/bank/broker/exchange 是資產；credit_card 是負債。只有 broker、exchange 能持倉與成交。

### 6.3 Category

| 欄位 | 型別 | 規則 |
| --- | --- | --- |
| id | uuid | |
| name | string | |
| kind | enum | income / expense |
| is_system | bool | 預設分類 true |
| archived_at | datetime? | |
| sort | int | |

轉帳沒有分類。v1 不分層。

### 6.4 Entry（日常分錄，含開帳現金、轉帳）

| 欄位 | 型別 | 規則 |
| --- | --- | --- |
| id | uuid | |
| date | date | ≥ opening_date；只記日，不記時 |
| type | enum | expense / income / transfer / opening_balance |
| amount | int | TWD 元，必須 > 0 |
| account_id | uuid | 支出／收入／開帳：這個帳戶。轉帳：轉出 |
| to_account_id | uuid? | 僅 transfer |
| category_id | uuid? | 支出／收入必填；transfer、opening_balance 空 |
| note | string | 可空，短字，不做附件 |
| instrument_id | uuid? | 可空；現金股利可掛標的方便從該檔看到 |
| created_at, updated_at, deleted_at | datetime | |
| version | int | 樂觀鎖 |

規則：

- expense：資產餘額 −amount；若 account 是 credit_card，欠款 +amount。
- income：反向。
- transfer：account 減、to_account 加。兩端都是 credit_card 不允許。還卡：bank → credit_card，銀行減、欠款減。
- opening_balance：只在儲存開帳時由系統寫（重存時覆蓋），使用者不可再新增 type=opening_balance。credit_card 的 amount 是當日欠款。
- 不可自轉自己。

本月支出＝當月 expense 且未刪。本月收入＝當月 income 且未刪。轉帳、開帳不進這兩個數。

### 6.5 Instrument

| 欄位 | 型別 | 規則 |
| --- | --- | --- |
| id | uuid | |
| symbol | string | 必填，大寫。台股用代號 2330；美股 AAPL；加密貨幣 BTC |
| name | string | 可空，沒有就顯示 symbol |
| asset_class | enum | tw_stock / us_stock / crypto / fx |
| quote_currency | enum | TWD / USD | tw_stock → TWD；其餘預設 USD |
| unique | | (asset_class, symbol) 唯一 |

v1 使用者第一次成交時建立標的，手動打 symbol。能從報價 API 對到名稱就填，對不到就只用 symbol。USDT、USDC、USD 都當 Instrument（fx 或 crypto），不當帳戶現金。

### 6.6 Position（持倉，可物化）

以 (account_id, instrument_id) 為唯一。數量為 0 仍保留列（已平倉）。

| 欄位 | 型別 | 規則 |
| --- | --- | --- |
| account_id, instrument_id | uuid | |
| qty | decimal | ≥ 0，最多 8 位小數 |
| cost_twd | decimal | 剩餘成本，≥ 0，內部 10 位小數 |
| avg_cost_twd | 衍生 | qty>0 則 cost_twd/qty，否則 0 |
| realized_twd | int | 開帳後已實現累計，可負 |
| cost_unknown | bool | 開帳時成本未填；可隨時在開帳補 |
| version | int | 與對應 Trade 同一 transaction 更新 |

Position 必須能從 Trade 重算得出。Postgres 物化表供畫面；對帳用重算。禁止只存 Position 不存 Trade。

### 6.7 Trade（成交）

| 欄位 | 型別 | 規則 |
| --- | --- | --- |
| id | uuid | |
| date | date | ≥ opening_date |
| account_id | uuid | 必須 broker 或 exchange |
| instrument_id | uuid | |
| side | enum | buy / sell / transfer_in / transfer_out / opening / airdrop |
| qty | decimal | > 0 |
| price | decimal? | buy/sell 必填；opening 用成本反推可空；airdrop/transfer 空 |
| price_ccy | enum? | TWD / USD |
| fee_twd | int | ≥ 0，預設 0 |
| proceeds_or_cost_twd | int | 系統算，見 §8 |
| fx_usd_twd | decimal | 存檔當下匯率；price_ccy=TWD 則 1 |
| realized_twd | int? | 僅 sell |
| pair_id | uuid? | 轉出入成對 |
| note | string | |
| created_at, updated_at, deleted_at | | |
| version | int | 樂觀鎖 |

現金股利**不是 Trade**，是 Entry type=income、分類「股利」、可掛 instrument_id。不改 qty、不改成本。

airdrop（含股票股利）：qty 增加，成本 +0，均價被攤薄。

opening：儲存開帳時系統寫（重存時覆蓋）。qty、cost_twd 來自快照。price 可存 cost/qty。

### 6.8 Quote 與 FxRate

Quote：(instrument_id) 最新一筆。price、ccy、as_of、source=auto|manual、locked bool。locked 時自動更新跳過。

FxRate：USD/TWD，as_of、source。全帳本共用這一支 FX，用來把 USD 報價與 USD 單價換成 TWD。

### 6.9 餘額怎麼算

帳戶現金餘額（credit_card 則為欠款）：

```
opening_balance
+ Σ income
− Σ expense
− Σ transfer 出
+ Σ transfer 入
− Σ buy 的 proceeds_or_cost_twd
+ Σ sell 的 proceeds_or_cost_twd
− Σ 投資費用（搬倉手續費等 expense）
```

持倉現值不進入現金餘額。

淨資產：

```
Σ cash/bank/broker/exchange 現金餘額
− Σ credit_card 欠款
+ Σ 未平倉 qty × 現價 TWD
```

沒現價的檔，暫用剩餘成本，並在首頁加註「部分持倉無現價，用成本估」。

---

## 7. 開帳規則

- 全帳本一個 opening_date。
- 開帳日前不准有 Entry 或 Trade。
- 每個帳戶一筆 opening_balance：
  - cash / bank / broker / exchange：當日**現金** TWD。券商帳上股票市值不要寫在這裡。
  - credit_card：當日**欠款** TWD，正數。餘額算法裡它是負債。
- 現倉每檔一筆 Trade side=opening：帳戶、標的、數量、總成本 TWD。成本含歷史手續費（使用者自己包進來）。
- 券商／交易所：現金走帳戶 opening_balance；持倉走 opening trade。兩筆分開，禁止把市值塞進現金。
- 穩定幣、外幣現金：開成 Instrument 持倉，不開成帳戶餘額。
- 已關掉帳戶、已出清標的：v1 不要開進來。
- 「成本不確定」：Position 加 cost_unknown（bool，預設 false）。開帳填 0 並勾未填時為 true，opening 的 cost_twd=0。可隨時回開帳補（2026-10-20 移除鎖定）。開帳預覽要把未填標紅，儲存時若還有未填，再確認一次。
- CSV：v1 不當輸入。使用者自己從 CSV 抄成本進來可以，App 不讀檔。

---

## 8. 現價與損益

### 8.1 現價

- tw_stock：TWD 報價。
- us_stock、crypto、fx：USD 報價 × USD/TWD。
- 刷新時機：App 進前台、投資頁下拉、持倉詳情進入、手動「更新報價」。
- 快取 5 分鐘；5 分鐘內不重複打 API。過期仍顯示舊價，標時間。
- 來源：公開報價（實作自選，例如台股 TWSE／Yahoo，美股與幣 CoinGecko 或等同）。失敗：保留上次，標「報價失敗」。
- 沒有公開價或使用者鎖了：用手動價。手動價要記 as_of＝他按下的時間。
- 離線：用最後一次成功價。

### 8.2 成交換算 TWD

FX 用**成交當日**的 USD/TWD。v1 簡化：用該筆存檔當下拿到的最新 FX，存進該 Trade（加欄位 fx_usd_twd，decimal）。之後 FX 變動不回改成本。手改成交才重算。

- buy 成本 TWD ＝ round(qty × price × fx) ＋ fee_twd。price_ccy=TWD 則 fx=1。
- sell 所得 TWD ＝ round(qty × price × fx) − fee_twd。必須 ≥ 0。
- 存成 proceeds_or_cost_twd。

TWD 金額四捨五入到元。qty、price 最多 8 位小數。均價內部 10 位，畫面到 2 或 4 位（加密貨幣 4、股票 2）。

### 8.3 移動平均（每個 account × instrument）

買／開倉／空投：

```
cost_twd += 本次成本   // 空投是 0
qty += 本次 qty
avg = cost_twd / qty
```

賣：

```
realized = 本次所得TWD − avg × 賣出qty
qty -= 賣出qty
cost_twd -= avg × 賣出qty
avg 不變
realized_twd += realized
```

轉出：跟賣一樣減少 qty 與 cost，但 realized=0，成本跟著 pair 轉入。
轉入：qty、cost 加上對應轉出的量與成本。

### 8.4 畫面損益

- 現值 ＝ qty × 現價 TWD
- 未實現 ＝ 現值 − cost_twd
- 未實現％ ＝ 未實現 / cost_twd；cost_twd=0 則顯示「—」
- 已實現 ＝ 該倉 realized_twd（開帳後賣出累計）
- 累計 ＝ 已實現 ＋ 未實現
- 現金股利不進累計持倉損益，進本月收入「股利」。v1 不把股利加回該檔報酬率，避免和持倉成本口徑混在一起。

---

## 9. 預設分類與帳戶類型

帳戶類型（系統固定，使用者只開實例）：

1. 現金
2. 銀行活存
3. 信用卡（負債）
4. 券商
5. 交易所／錢包

不預設開任何實例（中信、Binance 等等使用者自己建）。沒有「其他」類型。

收入預設：薪資、獎金、股利、利息、其他。
支出預設：餐飲、交通、居住、日用、訂閱、醫療、娛樂、學習、人情、投資費用、其他。

可改名、可封存、可再新增。不可刪系統那幾筆（封存即可）。v1 沒有「投資損益」分類——賣出已實現只顯示在投資頁，不進日常分類。

---

## 10. 權限、數字、API 雜項

- 所有帳本讀寫：未帶有效 session → 401。
- 業務 API 必須指定 book_id；該本 user_id 不是當前使用者 → 404。封存本除了取消封存／匯出外，寫入 → 409。
- POST /api/register、/api/login、/api/logout、/api/password。
- GET/POST /api/books；PATCH /api/books/{id} 改名；POST .../archive 與 .../unarchive；無資料才 DELETE。
- 日期選擇器不可選 opening_date 之前（後端同樣擋）。
- 賣出數量 > 持倉：擋（DB transaction 內）。
- 轉帳兩端相同：擋。
- 成交帳戶類型不對：擋。
- 金額 ≤ 0：擋。
- 顯示：TWD 千分位、整元。負數用「−」不是括號。
- 備份：`GET /api/books/{id}/export` 產出該本 JSON。`POST /api/books/{id}/import` 還原覆蓋該本，確認後一筆 transaction。JSON **不是**執行期資料庫，**不是**開帳輸入。
- 衝突：帶 version，失敗 409，前端重抓。不做本機覆蓋、不做欄位合併精靈。
- 冪等：寫入帶 `Idempotency-Key`。同一 key 回同一結果，不複製分錄。
- 統計 API（皆要登入；數字由 SQL 聚合 Entry，**不另建統計表**；可加 `(book_id, date)` index 在 entries）：
  - `GET /api/stats/daily?from=YYYY-MM-DD&to=YYYY-MM-DD` → 每日 `{date, expense, income, cash_net}`。`cash_net` 是該日結束的現金淨資產（不含持倉）。`from` 不可早於 opening_date。
  - `GET /api/stats/expense-by-category?month=YYYY-MM` → `{category_id, name, amount}`。
  - 當日流水用既有 `GET /api/entries?date=` 與 trades。

---

## 11. 非 v1 清單

之後再說，這版規格當不存在：

- 券商／交易所／銀行 CSV、OFX、API 同步。
- 用 CSV 重播歷史成交當正式帳。
- FIFO、稅務成本。
- 預算、分類額度、月結報告 PDF。
- 多幣別現金帳戶、自動分攤匯兌損益（現在只在持倉市值用即期 FX）。
- 選擇權、期貨、融資、鏈上錢包讀取。
- 報稅、股利所得細表。
- 定期交易、模板。
- 收據照片、標籤、專案。
- 多人、稽核軌。
- 原生 iOS／Android／Mac App。
- Craft 同步。
- （2026-10-20 移除鎖定後，「鎖定後改開帳日」不再適用；開帳可直接改。）
- 欄位級衝突合併、本機覆蓋伺服器。
- 推播、到價提醒。
- IndexedDB／本機 JSON 當正本；未登入開正式帳。
- 帳本分享、成員邀請、權限角色。
- Magic link、OAuth、第三方登入。
- 獨立「統計」一級、週曆、年熱力圖、預算對圖。
- 用今日股價回填的「含持倉淨資產」歷史線（v1 不存歷史報價）。

CSV 的定位（再寫一次）：使用者可以自己打開 CSV 抄「現倉數量／總成本」填進開帳。App 不吃檔。

---

## 變更紀錄

### 2026-10-20 移除開帳「鎖定」（Shuhi）

- 不需要鎖定。使用者只要「建立帳本」就能開始記帳、看月曆與分析圖。
- 開帳（開帳日＋各帳戶餘額＋現倉快照）改為選填、隨時可改；最後一步由「確認鎖定」改為「預覽＋儲存」。
- 資料：新 migration **DROP COLUMN `books.opening_locked`**（down migration 加回 `boolean NOT NULL DEFAULT false`）。已定 2026-10-20。
- API：`POST /api/books/{id}/opening/lock` 移除；`PUT /api/books/{id}/opening` 直接寫入／覆蓋 opening_balance 分錄與 side=opening 成交（一筆 transaction）；`GET` 不再回 `opening_locked`。
- Entry／Trade 寫入不再檢查「已鎖定開帳」。
- **已定（2026-10-20 柯南／Shuhi）：** 保留 opening_date 與「開帳日前不可記」；建立帳本時 opening_date 預設＝建立當日；改開帳日若有未刪 Entry／Trade 早於新日期，API 回錯擋下。
- 備份 JSON：匯出不再含 `opening_locked`；匯入舊檔時忽略該欄位。

### 2026-10-20 補充決定（柯南／Shuhi）

- **前端改 Flutter**（Shuhi 14:48）：照 Doop 重做；含 Flutter web 供驗收。Go 後端（chi／pgx／Postgres 16／golang-migrate）維持。原 React Vite PWA（`web/`）停用。
- 「開帳日前不可記」保留，已定。
- opening_date 預設＝建立帳本當日；改開帳日若有早於新日期的 entries／trades，API 回錯擋下。
- `opening_locked`：新 migration drop 欄位（down 加回）；移除 `POST /api/books/{id}/opening/lock`。
- Doop `5Wjm9YUjPA` 由小蘭改為「預覽＋儲存」。
- UI 驗收＝Flutter web 實機截圖對 Doop frame（不需 Docker），見 §3.5。
