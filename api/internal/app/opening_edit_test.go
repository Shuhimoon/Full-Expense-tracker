package app

import (
	"fmt"
	"net/http"
	"testing"

	"github.com/shopspring/decimal"
)

func numEq(t *testing.T, label string, got any, want string) {
	t.Helper()
	g, err := decimal.NewFromString(fmt.Sprint(got))
	if err != nil {
		t.Fatalf("%s: %v", label, got)
	}
	w, err := decimal.NewFromString(want)
	if err != nil {
		t.Fatal(err)
	}
	if !g.Equal(w) {
		t.Fatalf("%s = %s want %s", label, g.String(), w.String())
	}
}

func expenseCat(t *testing.T, c *tclient, bid string) any {
	t.Helper()
	var cats []map[string]any
	c.do("GET", "/api/categories?book_id="+bid, nil, &cats)
	for _, k := range cats {
		if k["kind"] == "expense" || k["type"] == "expense" {
			return k["id"]
		}
	}
	if len(cats) > 0 {
		return cats[0]["id"]
	}
	t.Fatal("no category")
	return nil
}

func TestOpeningEditAfterTradesRecomputesAvgCost(t *testing.T) {
	c := newClient(t)
	var book map[string]any
	if st := c.do("POST", "/api/books", map[string]string{"name": "投資"}, &book); st >= 300 {
		t.Fatalf("book %d %v", st, book)
	}
	bid := book["id"].(string)
	var acc map[string]any
	if st := c.do("POST", "/api/accounts", map[string]any{"book_id": bid, "name": "券商", "type": "broker"}, &acc); st >= 300 {
		t.Fatalf("account %d %v", st, acc)
	}
	aid := acc["id"].(string)
	opening := map[string]any{
		"opening_date": "2026-01-01",
		"positions": []map[string]any{{
			"account_id": aid, "symbol": "2330", "name": "台積電",
			"asset_class": "tw_stock", "quote_currency": "TWD",
			"qty": "10", "cost_twd": "10000",
		}},
	}
	if st := c.do("PUT", "/api/books/"+bid+"/opening", opening, nil); st >= 300 {
		t.Fatalf("opening %d", st)
	}
	var resp map[string]any
	if st := c.do("POST", "/api/trades", map[string]any{
		"book_id": bid, "date": "2026-02-01", "account_id": aid,
		"symbol": "2330", "asset_class": "tw_stock", "quote_currency": "TWD",
		"side": "buy", "qty": "10", "price": "2000", "price_ccy": "TWD", "fee_twd": 0,
	}, &resp); st >= 300 {
		t.Fatalf("buy %d %v", st, resp)
	}
	if st := c.do("POST", "/api/trades", map[string]any{
		"book_id": bid, "date": "2026-03-01", "account_id": aid,
		"symbol": "2330", "asset_class": "tw_stock", "quote_currency": "TWD",
		"side": "sell", "qty": "4", "price": "1800", "price_ccy": "TWD", "fee_twd": 0,
	}, &resp); st >= 300 {
		t.Fatalf("sell %d %v", st, resp)
	}
	// Opening cost 10000 → 20000. Replay: 20000 + buy 20000 = 40000, sell 4 at avg 2000 leaves qty 16 cost 32000.
	opening["positions"].([]map[string]any)[0]["cost_twd"] = "20000"
	if st := c.do("PUT", "/api/books/"+bid+"/opening", opening, &resp); st >= 300 {
		t.Fatalf("edit opening after trades %d %v", st, resp)
	}
	var poss []map[string]any
	if st := c.do("GET", "/api/positions?book_id="+bid, nil, &poss); st >= 300 {
		t.Fatalf("positions %d %v", st, poss)
	}
	if len(poss) != 1 {
		t.Fatalf("want 1 position, got %+v", poss)
	}
	p := poss[0]
	numEq(t, "qty", p["qty"], "16")
	numEq(t, "cost_twd", p["cost_twd"], "32000")
	numEq(t, "avg_cost_twd", p["avg_cost_twd"], "2000")

	var trades []map[string]any
	c.do("GET", "/api/trades?book_id="+bid, nil, &trades)
	var sawSell bool
	for _, tr := range trades {
		if tr["side"] == "sell" {
			sawSell = true
			// proceeds 7200 − avg 2000 × 4
			numEq(t, "realized_twd", tr["realized_twd"], "-800")
		}
	}
	if !sawSell {
		t.Fatal("sell trade missing")
	}
}

func TestOpeningEditNegativeMidTimeline422(t *testing.T) {
	c := newClient(t)
	var book map[string]any
	if st := c.do("POST", "/api/books", map[string]string{"name": "負持倉"}, &book); st >= 300 {
		t.Fatalf("book %d %v", st, book)
	}
	bid := book["id"].(string)
	var acc map[string]any
	if st := c.do("POST", "/api/accounts", map[string]any{"book_id": bid, "name": "券商", "type": "broker"}, &acc); st >= 300 {
		t.Fatalf("account %d %v", st, acc)
	}
	aid := acc["id"].(string)
	opening := map[string]any{
		"opening_date": "2026-01-01",
		"positions": []map[string]any{{
			"account_id": aid, "symbol": "2330", "name": "台積電",
			"asset_class": "tw_stock", "quote_currency": "TWD",
			"qty": "10", "cost_twd": "1000",
		}},
	}
	if st := c.do("PUT", "/api/books/"+bid+"/opening", opening, nil); st >= 300 {
		t.Fatalf("opening %d", st)
	}
	var resp map[string]any
	if st := c.do("POST", "/api/trades", map[string]any{
		"book_id": bid, "date": "2026-02-01", "account_id": aid,
		"symbol": "2330", "asset_class": "tw_stock", "quote_currency": "TWD",
		"side": "sell", "qty": "6", "price": "100", "price_ccy": "TWD",
	}, &resp); st >= 300 {
		t.Fatalf("sell %d %v", st, resp)
	}
	if st := c.do("POST", "/api/trades", map[string]any{
		"book_id": bid, "date": "2026-03-01", "account_id": aid,
		"symbol": "2330", "asset_class": "tw_stock", "quote_currency": "TWD",
		"side": "buy", "qty": "10", "price": "100", "price_ccy": "TWD",
	}, &resp); st >= 300 {
		t.Fatalf("buy %d %v", st, resp)
	}
	// Final qty would be 4−6+10 = 8, but the sell drives the holding to −2.
	opening["positions"].([]map[string]any)[0]["qty"] = "4"
	st := c.do("PUT", "/api/books/"+bid+"/opening", opening, &resp)
	if st != http.StatusUnprocessableEntity {
		t.Fatalf("status %d want 422, body %v", st, resp)
	}
	if resp["error"] != "修改後持倉會變負數" {
		t.Fatalf("error %v", resp["error"])
	}
	var poss []map[string]any
	if st := c.do("GET", "/api/positions?book_id="+bid, nil, &poss); st >= 300 {
		t.Fatalf("positions %d %v", st, poss)
	}
	if len(poss) != 1 {
		t.Fatalf("rollback lost position: %+v", poss)
	}
	numEq(t, "qty after rollback", poss[0]["qty"], "14")
	var drafts map[string]any
	if st := c.do("GET", "/api/books/"+bid+"/opening", nil, &drafts); st >= 300 {
		t.Fatalf("opening get %d", st)
	}
	pd, _ := drafts["position_drafts"].([]any)
	if len(pd) != 1 {
		t.Fatalf("drafts %+v", drafts["position_drafts"])
	}
	numEq(t, "draft qty", pd[0].(map[string]any)["qty"], "10")
}

func TestOpeningBalanceEditAfterEntriesRecomputesBalance(t *testing.T) {
	c := newClient(t)
	var book map[string]any
	if st := c.do("POST", "/api/books", map[string]string{"name": "現金帳"}, &book); st >= 300 {
		t.Fatalf("book %d %v", st, book)
	}
	bid := book["id"].(string)
	var acc map[string]any
	if st := c.do("POST", "/api/accounts", map[string]any{"book_id": bid, "name": "現金", "type": "cash"}, &acc); st >= 300 {
		t.Fatalf("account %d %v", st, acc)
	}
	aid := acc["id"].(string)
	if st := c.do("PUT", "/api/books/"+bid+"/opening", map[string]any{
		"accounts": []map[string]any{{"account_id": aid, "amount": 1000}},
	}, nil); st >= 300 {
		t.Fatalf("opening %d", st)
	}
	var resp map[string]any
	if st := c.do("POST", "/api/entries", map[string]any{
		"book_id": bid, "type": "expense", "amount": 200,
		"account_id": aid, "date": todayTaipei(), "category_id": expenseCat(t, c, bid),
	}, &resp); st >= 300 {
		t.Fatalf("entry %d %v", st, resp)
	}
	if got := cashBalance(t, c, bid, aid); got != 800 {
		t.Fatalf("balance after expense = %d want 800", got)
	}
	if st := c.do("PUT", "/api/books/"+bid+"/opening", map[string]any{
		"accounts": []map[string]any{{"account_id": aid, "amount": 5000}},
	}, &resp); st >= 300 {
		t.Fatalf("edit opening balance %d %v", st, resp)
	}
	if got := cashBalance(t, c, bid, aid); got != 4800 {
		t.Fatalf("balance after opening edit = %d want 4800", got)
	}
}

func cashBalance(t *testing.T, c *tclient, bid, aid string) int64 {
	t.Helper()
	var accs []map[string]any
	if st := c.do("GET", "/api/accounts?book_id="+bid, nil, &accs); st >= 300 {
		t.Fatalf("accounts %d %v", st, accs)
	}
	for _, a := range accs {
		if a["id"] == aid {
			n, ok := a["cash_balance"].(float64)
			if !ok {
				t.Fatalf("cash_balance %T %v", a["cash_balance"], a["cash_balance"])
			}
			return int64(n)
		}
	}
	t.Fatal("account missing")
	return 0
}
