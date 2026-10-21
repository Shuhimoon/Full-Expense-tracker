package app

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/shopspring/decimal"
)

type testEnv struct {
	t      *testing.T
	pool   *pgxpool.Pool
	app    *App
	router http.Handler
	email  string
	pass   string
	cookie string
	userID uuid.UUID
	bookID uuid.UUID
}

func newTestEnv(t *testing.T) *testEnv {
	t.Helper()
	pool := testPool(t)
	t.Cleanup(func() { pool.Close() })
	a := New(pool)
	e := &testEnv{
		t:      t,
		pool:   pool,
		app:    a,
		router: a.Router(),
		email:  fmt.Sprintf("hb-%s@test.local", uuid.NewString()),
		pass:   "password123",
	}
	return e
}

func (e *testEnv) do(method, path string, body any, cookie string) (int, map[string]any, http.Header) {
	e.t.Helper()
	var rdr io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			e.t.Fatal(err)
		}
		rdr = bytes.NewReader(b)
	}
	req := httptest.NewRequest(method, path, rdr)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if cookie != "" {
		req.Header.Set("Cookie", cookie)
	}
	rec := httptest.NewRecorder()
	e.router.ServeHTTP(rec, req)
	var out map[string]any
	raw := rec.Body.Bytes()
	if len(raw) > 0 && raw[0] == '{' {
		_ = json.Unmarshal(raw, &out)
	} else if len(raw) > 0 && raw[0] == '[' {
		var arr []any
		_ = json.Unmarshal(raw, &arr)
		out = map[string]any{"_arr": arr}
	}
	if out == nil {
		out = map[string]any{}
	}
	return rec.Code, out, rec.Header()
}

func (e *testEnv) doArr(method, path string, body any, cookie string) (int, []any) {
	e.t.Helper()
	code, out, _ := e.do(method, path, body, cookie)
	if arr, ok := out["_arr"].([]any); ok {
		return code, arr
	}
	return code, nil
}

func sidFromSetCookie(h http.Header) string {
	for _, c := range h.Values("Set-Cookie") {
		if strings.HasPrefix(c, "sid=") {
			part := strings.SplitN(c, ";", 2)[0]
			return part
		}
	}
	return ""
}

func (e *testEnv) registerLogin() {
	e.t.Helper()
	code, out, hdr := e.do("POST", "/api/register", map[string]any{
		"email": e.email, "password": e.pass,
	}, "")
	if code != http.StatusCreated {
		e.t.Fatalf("register %d %v", code, out)
	}
	e.cookie = sidFromSetCookie(hdr)
	if e.cookie == "" {
		e.t.Fatal("missing sid cookie")
	}
	id, _ := uuid.Parse(fmt.Sprint(out["id"]))
	e.userID = id
	e.t.Cleanup(func() {
		_, _ = e.pool.Exec(context.Background(), `DELETE FROM users WHERE id=$1`, e.userID)
	})
}

func (e *testEnv) createBook(name string) uuid.UUID {
	e.t.Helper()
	code, out, _ := e.do("POST", "/api/books", map[string]any{"name": name}, e.cookie)
	if code != http.StatusCreated {
		e.t.Fatalf("create book %d %v", code, out)
	}
	id, err := uuid.Parse(fmt.Sprint(out["id"]))
	if err != nil {
		e.t.Fatal(err)
	}
	e.bookID = id
	return id
}

// putOpening 只寫開帳日與現金快照。M1 沒有鎖定步驟，PUT 當下就落成開帳分錄。
func (e *testEnv) putOpening(bookID uuid.UUID, openingDate string, cashAccount uuid.UUID, cashAmt int64) {
	e.t.Helper()
	code, out, _ := e.do("PUT", "/api/books/"+bookID.String()+"/opening", map[string]any{
		"opening_date": openingDate,
		"accounts":     []map[string]any{{"account_id": cashAccount.String(), "amount": cashAmt}},
	}, e.cookie)
	if code != http.StatusOK {
		e.t.Fatalf("opening put %d %v", code, out)
	}
}

func (e *testEnv) createAccount(bookID uuid.UUID, name, typ string) uuid.UUID {
	e.t.Helper()
	code, out, _ := e.do("POST", "/api/accounts", map[string]any{
		"book_id": bookID.String(), "name": name, "type": typ,
	}, e.cookie)
	if code != http.StatusCreated {
		e.t.Fatalf("create account %d %v", code, out)
	}
	id, err := uuid.Parse(fmt.Sprint(out["id"]))
	if err != nil {
		e.t.Fatal(err)
	}
	return id
}

func (e *testEnv) expenseCat(bookID uuid.UUID) uuid.UUID {
	e.t.Helper()
	var id uuid.UUID
	err := e.pool.QueryRow(context.Background(),
		`SELECT id FROM categories WHERE book_id=$1 AND kind='expense' AND name='餐飲' LIMIT 1`, bookID).Scan(&id)
	if err != nil {
		e.t.Fatal(err)
	}
	return id
}

// ---- §2 B Auth ----

// 註冊、登入、登出都走 session cookie（sid）。登出後同一顆 cookie 再打 /api/me 應為 401。
func TestAuthRegisterLoginLogoutSession(t *testing.T) {
	e := newTestEnv(t)
	e.registerLogin()

	code, out, _ := e.do("GET", "/api/me", nil, e.cookie)
	if code != http.StatusOK {
		t.Fatalf("me %d %v", code, out)
	}
	if strings.ToLower(fmt.Sprint(out["email"])) != e.email {
		t.Fatalf("email=%v", out["email"])
	}

	code, out, hdr := e.do("POST", "/api/login", map[string]any{"email": e.email, "password": e.pass}, "")
	if code != http.StatusOK {
		t.Fatalf("login %d %v", code, out)
	}
	loginCookie := sidFromSetCookie(hdr)
	if loginCookie == "" {
		t.Fatal("login missing cookie")
	}

	code, _, _ = e.do("POST", "/api/logout", nil, loginCookie)
	if code != http.StatusOK {
		t.Fatalf("logout %d", code)
	}
	code, out, _ = e.do("GET", "/api/me", nil, loginCookie)
	if code != http.StatusUnauthorized {
		t.Fatalf("after logout me want 401 got %d %v", code, out)
	}
}

// 未帶 session 時，帳本、記帳、統計、帳戶、成交等業務 API 一律 401，不能看資料也不能寫。
func TestUnauthenticatedReturns401(t *testing.T) {
	e := newTestEnv(t)
	paths := []struct {
		method, path string
	}{
		{"GET", "/api/me"},
		{"GET", "/api/books"},
		{"POST", "/api/books"},
		{"GET", "/api/entries?book_id=" + uuid.NewString()},
		{"GET", "/api/stats/summary?book_id=" + uuid.NewString()},
		{"GET", "/api/stats/daily?book_id=" + uuid.NewString() + "&from=2026-01-01&to=2026-01-31"},
		{"GET", "/api/accounts?book_id=" + uuid.NewString()},
		{"GET", "/api/trades?book_id=" + uuid.NewString()},
	}
	for _, p := range paths {
		code, out, _ := e.do(p.method, p.path, nil, "")
		if code != http.StatusUnauthorized {
			t.Fatalf("%s %s want 401 got %d %v", p.method, p.path, code, out)
		}
	}
}

// ---- §2 C Books ----

// 多本帳本：改名、切換 last_book_id、封存／取消封存。空帳本可刪；已有帳戶不可刪（409）。
// 別人的 book_id 查開帳、分錄、統計都應 404，不能靠猜 id 讀到。
func TestBooksMultiCRUDArchiveSelectOwnership(t *testing.T) {
	e := newTestEnv(t)
	e.registerLogin()
	b1 := e.createBook("生活A-" + uuid.NewString()[:8])
	b2 := e.createBook("生活B-" + uuid.NewString()[:8])

	// rename
	code, out, _ := e.do("GET", "/api/books", nil, e.cookie)
	if code != http.StatusOK {
		t.Fatalf("list %d", code)
	}
	var ver float64
	for _, raw := range out["_arr"].([]any) {
		m := raw.(map[string]any)
		if fmt.Sprint(m["id"]) == b1.String() {
			ver = m["version"].(float64)
		}
	}
	newName := "改名-" + uuid.NewString()[:6]
	code, out, _ = e.do("PATCH", "/api/books/"+b1.String(), map[string]any{"name": newName, "version": int(ver)}, e.cookie)
	if code != http.StatusOK || fmt.Sprint(out["name"]) != newName {
		t.Fatalf("rename %d %v", code, out)
	}

	// select last_book_id
	code, _, _ = e.do("POST", "/api/books/"+b2.String()+"/select", nil, e.cookie)
	if code != http.StatusOK {
		t.Fatalf("select %d", code)
	}
	code, me, _ := e.do("GET", "/api/me", nil, e.cookie)
	if code != http.StatusOK || fmt.Sprint(me["last_book_id"]) != b2.String() {
		t.Fatalf("last_book_id=%v want %s", me["last_book_id"], b2)
	}

	// archive / unarchive
	code, out, _ = e.do("POST", "/api/books/"+b1.String()+"/archive", nil, e.cookie)
	if code != http.StatusOK || out["archived_at"] == nil {
		t.Fatalf("archive %d %v", code, out)
	}
	code, out, _ = e.do("POST", "/api/books/"+b1.String()+"/unarchive", nil, e.cookie)
	if code != http.StatusOK || out["archived_at"] != nil {
		t.Fatalf("unarchive %d %v", code, out)
	}

	// delete empty (seeded categories only) OK
	empty := e.createBook("空帳-" + uuid.NewString()[:8])
	code, out, _ = e.do("DELETE", "/api/books/"+empty.String(), nil, e.cookie)
	if code != http.StatusOK {
		t.Fatalf("delete empty %d %v", code, out)
	}

	// delete non-empty blocked
	acc := e.createAccount(b2, "現金", "cash")
	code, out, _ = e.do("DELETE", "/api/books/"+b2.String(), nil, e.cookie)
	if code != http.StatusConflict {
		t.Fatalf("delete non-empty want 409 got %d %v (acc=%s)", code, out, acc)
	}

	// ownership → 404
	e2 := newTestEnv(t)
	e2.registerLogin()
	code, out, _ = e2.do("GET", "/api/books/"+b1.String()+"/opening", nil, e2.cookie)
	if code != http.StatusNotFound {
		t.Fatalf("other user opening want 404 got %d %v", code, out)
	}
	code, out, _ = e2.do("GET", "/api/entries?book_id="+b1.String(), nil, e2.cookie)
	if code != http.StatusNotFound {
		t.Fatalf("other user entries want 404 got %d %v", code, out)
	}
	code, out, _ = e2.do("GET", "/api/stats/summary?book_id="+b1.String(), nil, e2.cookie)
	if code != http.StatusNotFound {
		t.Fatalf("other user stats want 404 got %d %v", code, out)
	}
}

// ---- 開帳 PUT 一次落成快照；開帳日前不可記 ----

// 一次 PUT 就在同一筆交易寫入現金開帳分錄與現倉 opening 成交，沒有鎖定步驟。
// 規則：開帳日當天可以記；成交早於開帳日、以及把既有分錄改到開帳日之前，都回 400「不能記開帳日之前的帳」。
// 分錄早於開帳日的拒絕已在 opening_nolock_test；負持倉 422 已在 opening_edit_test，這裡不重複。
func TestOpeningPutWritesSnapshotInOneTxAndRejectsBeforeDate(t *testing.T) {
	e := newTestEnv(t)
	e.registerLogin()
	bookID := e.createBook("開帳-" + uuid.NewString()[:8])
	cash := e.createAccount(bookID, "錢包", "cash")
	broker := e.createAccount(bookID, "券商", "broker")
	cat := e.expenseCat(bookID)

	code, out, _ := e.do("PUT", "/api/books/"+bookID.String()+"/opening", map[string]any{
		"opening_date": "2026-03-01",
		"accounts":     []map[string]any{{"account_id": cash.String(), "amount": 10000}},
		"positions": []map[string]any{{
			"account_id": broker.String(), "symbol": "2330", "name": "台積電",
			"asset_class": "tw_stock", "quote_currency": "TWD",
			"qty": "10", "cost_twd": "5000", "cost_unknown": false,
		}},
	}, e.cookie)
	if code != http.StatusOK {
		t.Fatalf("opening put %d %v", code, out)
	}
	if _, ok := out["opening_locked"]; ok {
		t.Fatalf("opening response still has opening_locked: %v", out)
	}

	var nOpenEnt, nOpenTr int
	_ = e.pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM entries WHERE book_id=$1 AND type='opening_balance' AND deleted_at IS NULL`, bookID).Scan(&nOpenEnt)
	_ = e.pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM trades WHERE book_id=$1 AND side='opening' AND deleted_at IS NULL`, bookID).Scan(&nOpenTr)
	if nOpenEnt != 1 || nOpenTr != 1 {
		t.Fatalf("opening PUT want 1 opening_balance + 1 opening trade, got entries=%d trades=%d", nOpenEnt, nOpenTr)
	}
	var od, td string
	_ = e.pool.QueryRow(context.Background(),
		`SELECT date::text FROM entries WHERE book_id=$1 AND type='opening_balance'`, bookID).Scan(&od)
	_ = e.pool.QueryRow(context.Background(),
		`SELECT date::text FROM trades WHERE book_id=$1 AND side='opening'`, bookID).Scan(&td)
	if od != "2026-03-01" || td != "2026-03-01" {
		t.Fatalf("opening dates entry=%s trade=%s", od, td)
	}

	// 開帳日當天可以記。
	code, out, _ = e.do("POST", "/api/entries", map[string]any{
		"book_id": bookID.String(), "type": "expense", "amount": 100,
		"account_id": cash.String(), "category_id": cat.String(), "date": "2026-03-01",
	}, e.cookie)
	if code != http.StatusCreated {
		t.Fatalf("entry on open %d %v", code, out)
	}

	// 成交早於開帳日 → 400。
	code, out, _ = e.do("POST", "/api/trades", map[string]any{
		"book_id": bookID.String(), "account_id": broker.String(),
		"symbol": "0050", "name": "0050", "asset_class": "tw_stock", "quote_currency": "TWD",
		"side": "buy", "qty": "1", "price": "100", "price_ccy": "TWD", "fee_twd": 0,
		"date": "2026-02-01",
	}, e.cookie)
	if code != http.StatusBadRequest || fmt.Sprint(out["error"]) != "不能記開帳日之前的帳" {
		t.Fatalf("trade before open want 400, got %d %v", code, out)
	}

	// 把既有分錄改到開帳日之前 → 400，原日期不變。
	var entryID uuid.UUID
	_ = e.pool.QueryRow(context.Background(),
		`SELECT id FROM entries WHERE book_id=$1 AND type='expense' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 1`, bookID).Scan(&entryID)
	var ver int
	_ = e.pool.QueryRow(context.Background(), `SELECT version FROM entries WHERE id=$1`, entryID).Scan(&ver)
	code, out, _ = e.do("PATCH", "/api/entries/"+entryID.String(), map[string]any{
		"date": "2026-02-15", "version": ver,
	}, e.cookie)
	if code != http.StatusBadRequest || fmt.Sprint(out["error"]) != "不能記開帳日之前的帳" {
		t.Fatalf("patch before open want 400, got %d %v", code, out)
	}
	var kept string
	_ = e.pool.QueryRow(context.Background(), `SELECT date::text FROM entries WHERE id=$1`, entryID).Scan(&kept)
	if kept != "2026-03-01" {
		t.Fatalf("rejected patch changed date to %s", kept)
	}
}

// 開帳沒有鎖定，已儲存的開帳仍可再 PUT。
// 規則：把開帳日往後改時，若有未刪成交早於新日期，回 400，訊息帶出最早那天；被拒的修改不得寫入。
// 開帳分錄與 opening 成交本身不算早於新開帳日的紀錄。分錄擋日期的案例在 opening_nolock_test。
func TestMovingOpeningDateLaterBlockedByEarlierTrade(t *testing.T) {
	e := newTestEnv(t)
	e.registerLogin()
	bookID := e.createBook("往後-" + uuid.NewString()[:8])
	cash := e.createAccount(bookID, "現金", "cash")
	broker := e.createAccount(bookID, "券商", "broker")
	e.putOpening(bookID, "2026-01-01", cash, 1000)

	// 帳上只有開帳分錄時，開帳日可以再往後。
	code, out, _ := e.do("PUT", "/api/books/"+bookID.String()+"/opening", map[string]any{
		"opening_date": "2026-02-01",
	}, e.cookie)
	if code != http.StatusOK {
		t.Fatalf("move date with only opening rows want 200 got %d %v", code, out)
	}

	code, out, _ = e.do("POST", "/api/trades", map[string]any{
		"book_id": bookID.String(), "account_id": broker.String(),
		"symbol": "2330", "name": "台積電", "asset_class": "tw_stock", "quote_currency": "TWD",
		"side": "buy", "qty": "1", "price": "100", "price_ccy": "TWD", "fee_twd": 0,
		"date": "2026-03-01",
	}, e.cookie)
	if code != http.StatusCreated {
		t.Fatalf("buy %d %v", code, out)
	}

	code, out, _ = e.do("PUT", "/api/books/"+bookID.String()+"/opening", map[string]any{
		"opening_date": "2026-03-02",
	}, e.cookie)
	if code != http.StatusBadRequest || fmt.Sprint(out["error"]) != "已有早於新開帳日的紀錄（2026-03-01），不能把開帳日往後改" {
		t.Fatalf("move past trade want 400, got %d %v", code, out)
	}
	var bookDate string
	if err := e.pool.QueryRow(context.Background(), `SELECT opening_date::text FROM books WHERE id=$1`, bookID).Scan(&bookDate); err != nil {
		t.Fatal(err)
	}
	if bookDate != "2026-02-01" {
		t.Fatalf("rejected move changed opening_date to %s", bookDate)
	}

	// 停在成交當天可以，開帳分錄日期跟著改。
	code, out, _ = e.do("PUT", "/api/books/"+bookID.String()+"/opening", map[string]any{
		"opening_date": "2026-03-01",
	}, e.cookie)
	if code != http.StatusOK {
		t.Fatalf("move onto trade date want 200 got %d %v", code, out)
	}
	var od string
	if err := e.pool.QueryRow(context.Background(),
		`SELECT date::text FROM entries WHERE book_id=$1 AND type='opening_balance' AND deleted_at IS NULL`, bookID).Scan(&od); err != nil {
		t.Fatal(err)
	}
	if od != "2026-03-01" {
		t.Fatalf("opening entry date=%s", od)
	}
	if fmt.Sprint(out["opening_date"]) != "2026-03-01" {
		t.Fatalf("response opening_date=%v", out["opening_date"])
	}
}

// ---- §2 J moving average + stats + instruments + backup ----

// 成本按「帳戶 × 標的」移動平均，同標的在不同帳戶各自一筆持倉。
// 買 10@100、再買 10@200 後均價 150；賣 5@180 已實現 150，剩餘數量 15、成本 2250。
// 開帳只把日期設到這些成交之前，沒有鎖定步驟。
func TestMovingAveragePerAccountInstrument(t *testing.T) {
	e := newTestEnv(t)
	e.registerLogin()
	bookID := e.createBook("均價-" + uuid.NewString()[:8])
	cash := e.createAccount(bookID, "現金", "cash")
	broker := e.createAccount(bookID, "券商", "broker")
	e.putOpening(bookID, "2026-01-01", cash, 1000000)

	// buy 10 @ 100 → cost 1000
	code, out, _ := e.do("POST", "/api/trades", map[string]any{
		"book_id": bookID.String(), "account_id": broker.String(),
		"symbol": "2330", "name": "台積電", "asset_class": "tw_stock", "quote_currency": "TWD",
		"side": "buy", "qty": "10", "price": "100", "price_ccy": "TWD", "fee_twd": 0,
		"date": "2026-01-02",
	}, e.cookie)
	if code != http.StatusCreated {
		t.Fatalf("buy1 %d %v", code, out)
	}
	// buy 10 @ 200 → qty 20 cost 3000 avg 150
	code, out, _ = e.do("POST", "/api/trades", map[string]any{
		"book_id": bookID.String(), "account_id": broker.String(),
		"symbol": "2330", "name": "台積電", "asset_class": "tw_stock", "quote_currency": "TWD",
		"side": "buy", "qty": "10", "price": "200", "price_ccy": "TWD", "fee_twd": 0,
		"date": "2026-01-03",
	}, e.cookie)
	if code != http.StatusCreated {
		t.Fatalf("buy2 %d %v", code, out)
	}
	// sell 5 @ 180 → realized = 900 - 150*5 = 150; remaining qty 15 cost 2250
	code, out, _ = e.do("POST", "/api/trades", map[string]any{
		"book_id": bookID.String(), "account_id": broker.String(),
		"symbol": "2330", "name": "台積電", "asset_class": "tw_stock", "quote_currency": "TWD",
		"side": "sell", "qty": "5", "price": "180", "price_ccy": "TWD", "fee_twd": 0,
		"date": "2026-01-04",
	}, e.cookie)
	if code != http.StatusCreated {
		t.Fatalf("sell %d %v", code, out)
	}
	if f, ok := out["realized_twd"].(float64); !ok || int64(f) != 150 {
		t.Fatalf("realized want 150 got %v", out["realized_twd"])
	}

	var qty, cost decimal.Decimal
	var realized int64
	err := e.pool.QueryRow(context.Background(), `
		SELECT p.qty, p.cost_twd, p.realized_twd FROM positions p
		JOIN instruments i ON i.id=p.instrument_id
		WHERE p.book_id=$1 AND p.account_id=$2 AND i.symbol='2330'`, bookID, broker).Scan(&qty, &cost, &realized)
	if err != nil {
		t.Fatal(err)
	}
	if !qty.Equal(decimal.RequireFromString("15")) {
		t.Fatalf("qty want 15 got %s", qty)
	}
	if !cost.Equal(decimal.RequireFromString("2250")) {
		t.Fatalf("cost want 2250 got %s", cost)
	}
	if realized != 150 {
		t.Fatalf("pos realized want 150 got %d", realized)
	}

	// second account same instrument → separate avg
	broker2 := e.createAccount(bookID, "券商2", "broker")
	code, out, _ = e.do("POST", "/api/trades", map[string]any{
		"book_id": bookID.String(), "account_id": broker2.String(),
		"symbol": "2330", "name": "台積電", "asset_class": "tw_stock", "quote_currency": "TWD",
		"side": "buy", "qty": "2", "price": "50", "price_ccy": "TWD", "fee_twd": 0,
		"date": "2026-01-05",
	}, e.cookie)
	if code != http.StatusCreated {
		t.Fatalf("buy other acc %d %v", code, out)
	}
	var qty2, cost2 decimal.Decimal
	err = e.pool.QueryRow(context.Background(), `
		SELECT p.qty, p.cost_twd FROM positions p
		JOIN instruments i ON i.id=p.instrument_id
		WHERE p.book_id=$1 AND p.account_id=$2 AND i.symbol='2330'`, bookID, broker2).Scan(&qty2, &cost2)
	if err != nil {
		t.Fatal(err)
	}
	if !qty2.Equal(decimal.RequireFromString("2")) || !cost2.Equal(decimal.RequireFromString("100")) {
		t.Fatalf("acc2 want qty=2 cost=100 got %s / %s", qty2, cost2)
	}
}

// 統計直接對 entries 做 SQL 聚合，不另建 stats 表。
// 今天兩筆支出 100+250，today_expense 與當月 month_expense 都應為 350。
// 帳本建立當日就是開帳日，支出記在當天即可，不必先寫開帳或鎖定。
func TestStatsFromSQLAggregateNotStatsTable(t *testing.T) {
	e := newTestEnv(t)
	e.registerLogin()
	bookID := e.createBook("統計-" + uuid.NewString()[:8])
	cash := e.createAccount(bookID, "現金", "cash")
	cat := e.expenseCat(bookID)

	today := time.Now().In(taipei).Format("2006-01-02")
	month := time.Now().In(taipei).Format("2006-01")
	for _, amt := range []int64{100, 250} {
		code, out, _ := e.do("POST", "/api/entries", map[string]any{
			"book_id": bookID.String(), "type": "expense", "amount": amt,
			"account_id": cash.String(), "category_id": cat.String(), "date": today,
		}, e.cookie)
		if code != http.StatusCreated {
			t.Fatalf("expense %d %v", code, out)
		}
	}

	// no dedicated stats table
	var n int
	err := e.pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='stats'`).Scan(&n)
	if err != nil {
		t.Fatal(err)
	}
	if n != 0 {
		t.Fatal("unexpected stats table exists")
	}

	code, out, _ := e.do("GET", "/api/stats/summary?book_id="+bookID.String()+"&month="+month, nil, e.cookie)
	if code != http.StatusOK {
		t.Fatalf("summary %d %v", code, out)
	}
	te := int64(out["today_expense"].(float64))
	me := int64(out["month_expense"].(float64))
	if te != 350 || me != 350 {
		t.Fatalf("today/month expense want 350 got %d / %d", te, me)
	}
}

// 帳本基準幣固定 TWD。USDT、USD 是標的（crypto／fx），不是帳戶幣別；accounts 沒有 currency 欄。
// 開帳只把日期設到成交之前，沒有鎖定步驟。
func TestBaseTWDAndUSDTUSDAreInstruments(t *testing.T) {
	e := newTestEnv(t)
	e.registerLogin()
	bookID := e.createBook("幣種-" + uuid.NewString()[:8])
	cash := e.createAccount(bookID, "現金", "cash")
	exch := e.createAccount(bookID, "交易所", "exchange")
	e.putOpening(bookID, "2026-01-01", cash, 100000)

	var base string
	_ = e.pool.QueryRow(context.Background(), `SELECT base_currency FROM books WHERE id=$1`, bookID).Scan(&base)
	if base != "TWD" {
		t.Fatalf("base_currency=%s", base)
	}

	// USDT as crypto instrument (not cash account)
	code, out, _ := e.do("POST", "/api/trades", map[string]any{
		"book_id": bookID.String(), "account_id": exch.String(),
		"symbol": "USDT", "name": "Tether", "asset_class": "crypto", "quote_currency": "USD",
		"side": "buy", "qty": "100", "price": "1", "price_ccy": "USD", "fee_twd": 0,
		"date": "2026-01-02",
	}, e.cookie)
	if code != http.StatusCreated {
		t.Fatalf("USDT trade %d %v", code, out)
	}
	// USD as fx instrument
	code, out, _ = e.do("POST", "/api/instruments", map[string]any{
		"book_id": bookID.String(), "symbol": "USD", "name": "美元",
		"asset_class": "fx", "quote_currency": "USD",
	}, e.cookie)
	if code != http.StatusCreated && code != http.StatusOK {
		// create might return 201
		if code != 201 {
			t.Fatalf("USD instrument %d %v", code, out)
		}
	}
	var ac string
	err := e.pool.QueryRow(context.Background(),
		`SELECT asset_class::text FROM instruments WHERE book_id=$1 AND symbol='USDT'`, bookID).Scan(&ac)
	if err != nil || ac != "crypto" {
		t.Fatalf("USDT asset_class=%s err=%v", ac, err)
	}
	err = e.pool.QueryRow(context.Background(),
		`SELECT asset_class::text FROM instruments WHERE book_id=$1 AND symbol='USD'`, bookID).Scan(&ac)
	if err != nil || ac != "fx" {
		t.Fatalf("USD asset_class=%s err=%v", ac, err)
	}

	// accounts have no currency column — cash is always TWD book base
	var hasCcy int
	_ = e.pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM information_schema.columns WHERE table_name='accounts' AND column_name='currency'`).Scan(&hasCcy)
	if hasCcy != 0 {
		t.Fatal("accounts should not have currency (USDT/USD are instruments)")
	}
}

// 匯出是這個帳本的 JSON 備份（帳本、帳戶、分類、分錄、成交、持倉），不是 pg_dump，也不含已移除的開帳鎖定狀態。
func TestJSONBackupIsNotDatabaseDump(t *testing.T) {
	e := newTestEnv(t)
	e.registerLogin()
	bookID := e.createBook("備份-" + uuid.NewString()[:8])
	cash := e.createAccount(bookID, "現金", "cash")
	e.putOpening(bookID, "2026-01-01", cash, 1000)

	code, out, _ := e.do("GET", "/api/books/"+bookID.String()+"/export", nil, e.cookie)
	if code != http.StatusOK {
		t.Fatalf("export %d %v", code, out)
	}
	for _, key := range []string{"book", "accounts", "categories", "entries", "trades", "positions"} {
		if _, ok := out[key]; !ok {
			t.Fatalf("export missing key %s", key)
		}
	}
	// not a pg_dump style
	raw, _ := json.Marshal(out)
	s := string(raw)
	if strings.Contains(s, "PostgreSQL database dump") || strings.Contains(s, "COPY public.") {
		t.Fatal("export looks like DB dump")
	}
	if strings.Contains(s, "opening_locked") {
		t.Fatal("export still has opening_locked")
	}
}
