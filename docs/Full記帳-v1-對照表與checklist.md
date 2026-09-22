# Full 記帳 v1｜當前計劃對照表 + Build Checklist

基準日：2026-09-07（實作 UI 驗收更新至 2026-09-22）  
畫布：https://doop.design/c/jr-EE9CpoR  
程式：`/workspace/full-jizhang` → GitHub `Shuhimoon/Full-Expense-tracker`  
用途：之後從 GitHub 拉取做 Grok build 對照。

---

## 0. 文件所有權與驗收（強制）

- **唯二可改動本檔**：Shuhi（GitHub `Shuhimoon`）與產品經理 **灰原哀（Haibara Ai）**。
- 其他代理人（柯南調度除外之實作／設計）**不得**自行改對照表勾選狀態或刪改項目。
- **完成項目流程**：實作者／設計師完成後，向 **灰原哀** 提驗收 → 她檢查「是否完成、有無遺漏」→ 由其（或 Shuhi）更新本檔勾選。
- GitHub：`docs/Full記帳-v1-對照表與checklist.md`；CODEOWNERS 鎖定此路徑需 Shuhi review。


狀態欄說明：
- **設計**：Doop 有對應 frame＝設計好；否則空白／未做
- **API**：後端已有路由＝已有 API
- **程式 UI**：現有 web 頁大致能跑＝可 build（可能還要對新 IA／Doop）
- **整體**：給 build 一眼用的綜合判斷

---

## 1. 對照表（規格 ↔ Doop ↔ 實作）

| # | v1 規格項目 | Doop frame | 設計 | API | 程式 UI | 整體 | 備註 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 註冊／登入（email＋密碼） | `Y5Bm0qKqks` | 設計好 | 已有 | **可 build**（2026-09-22 驗收） | OK | `Auth.tsx` 主色 `#8FB09F`；session cookie |
| 2 | 底欄四項：帳本／分析圖／資產／設定＋FAB 記一筆 | 首頁等 frame 底欄 | **設計好**（2026-09-07 驗收） | — | **可 build**（2026-09-22 驗收） | OK | `App.tsx` 四欄＋FAB |
| 3 | 帳本＝首頁：今天已花、淨資產、月曆 | `1vMhY6OCSe` | **設計好**（2026-09-07 驗收） | 已有 summary／daily | **可 build**（2026-09-22 驗收） | OK | `Home.tsx` |
| 4 | 首頁：**逐筆記一筆流水** | `1vMhY6OCSe`（今天流水） | **設計好**（2026-09-07 驗收） | 已有 entries／trades | **可 build**（2026-09-22 驗收） | OK | 今天／最近流水列表 |
| 5 | 首頁：**不要**本月支出圖（圖歸分析） | 首頁無圖／分析有圖 | **設計好**（2026-09-07 驗收） | 已有 stats | **可 build**（2026-09-22 驗收） | OK | Home 已無 recharts |
| 6 | 分析圖：摺線（支出／收入／現金淨資產）＋分類圓餅 | `iH20573wrb` | **設計好**（2026-09-07 驗收） | 已有 | **可 build**（2026-09-22 驗收） | OK | `Analytics.tsx` 獨立頁＋三切換 |
| 7 | 資產：帳戶列表＋持倉列表 | `HDLHZYbQ_r` | **設計好**（2026-09-07 驗收） | 已有 accounts／positions | **可 build**（2026-09-22 驗收） | OK | `Assets.tsx`；舊路由 redirect |
| 8 | 設定：帳本 CRUD／開帳入口／分類／備份／登出 | `0N9oT5Ax2q` | **設計好**（2026-09-07 驗收） | 已有 | **可 build**（2026-09-22 驗收） | OK | `Settings.tsx` 分區齊 |
| 9 | 記一筆彈層（支出示意） | `q273gYu-Cj`（另有舊 `HngcMO3aMK`） | **設計好**（2026-09-07 驗收） | 已有 entries | **可 build**（2026-09-22 驗收） | OK | FAB→`/record` `asSheet` |
| 10 | 記一筆四類型：支出／收入／轉帳／成交 | `q273gYu-Cj` 同層切 | **設計好**（2026-09-07 驗收） | 已有 | **可 build**（2026-09-22 驗收） | OK | 四 tab 同層；成交含買賣／轉倉／空投 |
| 11 | 開帳流程（日→餘額→現倉→鎖定） | `rZ0KEpCTCs`→`shTyYPkl4-`→`Bkl20hKz5B`→`5Wjm9YUjPA` | **設計好**（2026-09-07 驗收） | 已有 opening | **可 build**（2026-09-22 驗收） | OK | `Opening.tsx` 四步 wizard |
| 12 | 帳本切換（多本） | 頂欄／設定（獨立頁可延後） | 部分（設定內） | 已有 select | 可 build（`BookBar`＋設定） | 可 build | **獨立切換頁延後** |
| 13 | 日曆點進當日流水 | — | 可延後設計 | 已有 | 可 build（`DayLedger.tsx`） | 可延後視覺 | |
| 14 | 帳戶明細 | — | 可併資產 | 已有 | **可 build**（2026-09-22 驗收） | OK | 資產列→`/accounts/:id` |
| 15 | 持倉單檔（成本／現值／損益／成交） | — | **可延後** | 已有 | 可 build（`PositionDetail`） | **可延後對 Doop**；API／舊頁在 | |
| 16 | 報價刷新／手改現價 | — | 手改 UI 可延後 | 已有 quotes／fx | 部分（下拉刷新） | 手改畫面延後 | |
| 17 | 備份匯出／還原（當前帳本 JSON） | 設定內 | 設計好（設定） | 已有 | 可 build（設定備份區） | 可 build | 非 CSV 開帳 |
| 18 | PWA 可安裝、Postgres 正本、Go API | — | — | 架構已定 | 專案骨架在 | build 環境 | Go chi／pgx／React Vite |

---

## 2. Build Checklist（給 Grok／實作者勾）

### A. 環境與架構
- [x] Clone `Shuhimoon/Full-Expense-tracker`（或 `/workspace/full-jizhang`）（環境可測；本機路徑在）
- [x] Postgres 起來且測試庫可連（2026-09-22 灰原哀驗收；migrate 以測試可跑為準）
- [x] API：Go／chi／pgx 可測（2026-09-22；`go test ./internal/auth/ ./internal/app/` 11 PASS）
- [x] Web：React Vite PWA（2026-09-22 灰原哀驗收；`manifest.webmanifest` theme `#8FB09F`／bg `#F2EFE8`、icons 192／512／svg、`sw.js` NetworkFirst GET `/api`）
- [x] 主色 `#8FB09F`；底欄對齊 Doop（帳本／分析圖／資產／設定＋FAB）（2026-09-22 灰原哀驗收）

### B. 帳號
- [x] 註冊 email＋密碼（argon2id）（2026-09-22 灰原哀驗收；`TestHashVerifyArgon2id`＋register）
- [x] 登入／登出 session cookie（2026-09-22 灰原哀驗收；`TestAuthRegisterLoginLogoutSession`）
- [x] 未登入擋開帳／記帳／圖表／日曆（2026-09-22 灰原哀驗收；`TestUnauthenticatedReturns401`）
- [x] 登入／註冊頁視覺主色 `#8FB09F`（2026-09-22 灰原哀驗收；`Auth.tsx`）

### C. 帳本
- [x] 多本：新增／改名／封存／取消封存；有資料不可刪（2026-09-22 灰原哀驗收；`TestBooksMultiCRUDArchiveSelectOwnership`）
- [x] `last_book_id` 切換；業務 API 帶 `book_id` 且核對所有權（2026-09-22 灰原哀驗收）
- [x] 頂欄顯示當前帳本名（2026-09-22 灰原哀驗收；`BookBar` 名＋chevron、只列未封存、可切換、管理→設定）

### D. 開帳（對 Doop 四步）
- [x] 開帳日（2026-09-22 灰原哀驗收）
- [x] 各帳戶現金／信用卡欠款（2026-09-22 灰原哀驗收）
- [x] 現倉（數量＋總成本 TWD；成本未填標示）（2026-09-22 灰原哀驗收）
- [x] 預覽→鎖定；鎖定後不可改開帳日／快照（2026-09-22 灰原哀驗收）
- [x] 開帳日前不可記（2026-09-22 灰原哀驗收；`TestOpeningLockWritesInOneTxAndBlocksBeforeDate` PASS）

### E. 記一筆（彈層＋四類型）
- [x] FAB → 底部彈層（不要當底欄一級）（2026-09-22 灰原哀驗收）
- [x] 支出／收入／轉帳／成交同層切換（2026-09-22 灰原哀驗收）
- [x] 成交：買／賣／轉倉／空投（2026-09-22 灰原哀驗收；現金股利＝收入分類「股利」入口在設定說明）
- [x] 存檔打 API；冪等 `Idempotency-Key`（2026-09-22 灰原哀驗收；`api.ts` 自動帶）

### F. 帳本首頁（對 `1vMhY6OCSe`）
- [x] 今天已花（2026-09-22 灰原哀驗收）
- [x] 淨資產／相對開帳／持倉摘要（2026-09-22 灰原哀驗收）
- [x] 月曆（格上支出；開帳日前淡、不可記）（2026-09-22 灰原哀驗收）
- [x] **逐筆流水列表**（今天或最近；**必做**）（2026-09-22 灰原哀驗收）
- [x] **首頁無**本月支出摺線／圓餅（2026-09-22 灰原哀驗收）

### G. 分析圖（對 `iH20573wrb`）
- [x] 獨立「分析圖」頁（從首頁搬走）（2026-09-22 灰原哀驗收）
- [x] 摺線：支出／收入／現金淨資產（不含持倉）（2026-09-22 灰原哀驗收）
- [x] 圓餅：本月支出分類（2026-09-22 灰原哀驗收；圖例位置跟現實作）

### H. 資產（對 `HDLHZYbQ_r`）
- [x] 帳戶列表（五類）＋餘額（2026-09-22 灰原哀驗收）
- [x] 持倉列表（現值／未實現）（2026-09-22 灰原哀驗收）
- [x] 帳戶明細可進（資產列→`/accounts/:id`）（2026-09-22 灰原哀驗收）
- [ ] 持倉單檔：**本輪可延後**對 Doop（舊 `PositionDetail` 可暫留）

### I. 設定（對 `0N9oT5Ax2q`）
- [x] 帳本管理、開帳入口、分類、備份匯出／還原、改密碼／登出（2026-09-22 灰原哀驗收）

### J. 資料規則（驗收）
- [x] 成本：帳戶×標的移動平均（2026-09-22 灰原哀驗收；`TestMovingAveragePerAccountInstrument`）
- [x] 基準 TWD；USDT／USD 當持倉（2026-09-22 灰原哀驗收；`TestBaseTWDAndUSDTUSDAreInstruments`）
- [x] 統計 SQL 聚合 Entry，不另建統計表（2026-09-22 灰原哀驗收；`TestStatsFromSQLAggregateNotStatsTable`）
- [x] JSON 備份≠資料庫≠開帳輸入；不做 CSV 全量匯入（2026-09-22 灰原哀驗收；`TestJSONBackupIsNotDatabaseDump`）

---

## 3. 可延後（本輪 build 不擋）

- 持倉單檔完整對 Doop（成本／現值／損益／成交精修）
- 帳本切換**獨立頁**（頂欄列表／設定內切換即可）
- 日曆點進當日流水的視覺精修（功能舊頁已有）
- 手改現價畫面、載入／錯誤／過場動畫
- 備份還原 UI 精修、已平倉展開、現金股利從持倉快捷入口
- 舊五欄 IA 文檔全文改寫（先跟畫／跟 build）

---

## 4. Build 建議順序（對齊現況）

1. ~~改底欄 IA＋FAB 彈層~~（2026-09-22 已驗）  
2. ~~首頁：加逐筆流水、撤走圖表~~（已驗）  
3. ~~新建分析圖頁~~（已驗）  
4. ~~資產頁合併~~（已驗）  
5. ~~對齊開帳／設定／登入視覺~~（2026-09-22 已驗）  
6. ~~頂欄帳本／PWA~~（2026-09-22 已驗）；其餘延後項（持倉單檔對 Doop）有空再補  

§1 #1–11、#14 與 §2 A／B／C／D／E／F／G／H／I／J 主項已於 2026-09-22 通過（UI 靜態＋`go test` 11 PASS）。未勾：持倉單檔對 Doop（可延後）。

---

## 5. 設計驗收紀錄

| 日期 | 提驗 | 結果 | 說明 |
| --- | --- | --- | --- |
| 2026-09-07 | 毛利蘭（Doop 這批） | **通過**（1 項 follow-up） | 畫布 `jr-EE9CpoR`：登入、首頁流水（無本月圖）、記一筆彈層四類型同層、分析、資產、設定、開帳四步皆有。持倉單檔／帳本切換獨立頁依規格可延後。 |
| 2026-09-07 | 毛利蘭（分析摺線切換） | **通過** | `iH20573wrb` 已加支出／收入／現金淨資產切換；現金淨資產標「不含持倉」。follow-up 結案。 |

**Follow-up：** 分析摺線切換已於 2026-09-07 補齊並通過驗收（結案）。

---

## 6. 實作／UI 驗收紀錄

| 日期 | 提驗 | 結果 | 說明 |
| --- | --- | --- | --- |
| 2026-09-22 | 阿笠（Grok Build UI） | **通過** | 靜態對碼：底欄四項＋FAB、首頁流水／無圖、獨立分析頁（三切換＋圓餅）、資產合併、記一筆彈層四類型、主色 `#8FB09F`。本機無 Docker，未跑 compose。 |
| 2026-09-22 | 阿笠（開帳／設定／登入） | **通過** | 開帳四步 wizard、設定分區、Auth 主色、資產→帳戶明細、成交四 side＋`Idempotency-Key`。未勾：開帳日前不可記（待實機）、B／C／J 後端規則、持倉單檔對 Doop（可延後）。 |
| 2026-09-22 | 阿笠（開帳日前＋B／C／J） | **通過** | 本機重跑 `go test ./internal/auth/ ./internal/app/ -count=1`：**11 PASS**（argon2id、session／401、帳本 CRUD／封存／刪除限制／所有權、開帳鎖定 TX＋開帳日前擋記、移動平均、stats SQL、USDT／USD instrument、JSON 備份）。勾 §2 B／C／J、開帳日前不可記、A 環境可測項。持倉單檔對 Doop 仍延後。 |
| 2026-09-22 | 阿笠（頂欄＋PWA） | **通過** | `BookBar`：當前帳本名＋chevron、只列未封存、切換、`管理帳本`→設定；`web/dist` manifest theme `#8FB09F`／bg `#F2EFE8`、icons 192／512／svg、`sw.js`、VitePWA NetworkFirst GET `/api`。持倉單檔對 Doop 仍延後。 |
