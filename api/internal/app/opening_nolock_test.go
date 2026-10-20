package app

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
)

type tclient struct {
	t   *testing.T
	srv *httptest.Server
	c   *http.Client
}

func (c *tclient) do(method, path string, body any, out any) int {
	c.t.Helper()
	var buf bytes.Buffer
	if body != nil {
		_ = json.NewEncoder(&buf).Encode(body)
	}
	req, _ := http.NewRequest(method, c.srv.URL+path, &buf)
	req.Header.Set("Content-Type", "application/json")
	if method != http.MethodGet {
		req.Header.Set("Idempotency-Key", uuid.NewString())
	}
	resp, err := c.c.Do(req)
	if err != nil {
		c.t.Fatalf("%s %s: %v", method, path, err)
	}
	defer resp.Body.Close()
	if out != nil {
		_ = json.NewDecoder(resp.Body).Decode(out)
	}
	return resp.StatusCode
}

func newClient(t *testing.T) *tclient {
	pool := testPool(t)
	t.Cleanup(pool.Close)
	srv := httptest.NewServer(New(pool).Router())
	t.Cleanup(srv.Close)
	jar, _ := cookiejar.New(nil)
	c := &tclient{t: t, srv: srv, c: &http.Client{Jar: jar}}
	email := "nolock-" + uuid.NewString() + "@test.local"
	if st := c.do("POST", "/api/register", map[string]string{"email": email, "password": "test-password-123"}, nil); st >= 300 {
		t.Fatalf("register status %d", st)
	}
	t.Cleanup(func() { _, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE email=$1`, email) })
	return c
}

func todayTaipei() string { return time.Now().In(taipei).Format("2006-01-02") }

// 2026-10-20 spec: a created book is enough to record; no opening lock.
func TestBookCreatedCanRecordWithoutLock(t *testing.T) {
	c := newClient(t)
	var book map[string]any
	if st := c.do("POST", "/api/books", map[string]string{"name": "生活"}, &book); st >= 300 {
		t.Fatalf("create book %d %v", st, book)
	}
	if _, ok := book["opening_locked"]; ok {
		t.Fatal("opening_locked must be gone")
	}
	if book["opening_date"] != todayTaipei() {
		t.Fatalf("opening_date default = %v want %s", book["opening_date"], todayTaipei())
	}
	bid := book["id"].(string)
	var acc map[string]any
	if st := c.do("POST", "/api/accounts", map[string]any{"book_id": bid, "name": "現金", "type": "cash"}, &acc); st >= 300 {
		t.Fatalf("account %d %v", st, acc)
	}
	var cats []map[string]any
	c.do("GET", "/api/categories?book_id="+bid, nil, &cats)
	var catID any
	for _, k := range cats {
		if k["type"] == "expense" || k["kind"] == "expense" {
			catID = k["id"]
			break
		}
	}
	if catID == nil && len(cats) > 0 {
		catID = cats[0]["id"]
	}
	var e map[string]any
	st := c.do("POST", "/api/entries", map[string]any{"book_id": bid, "type": "expense", "amount": 120, "account_id": acc["id"], "date": todayTaipei(), "category_id": catID}, &e)
	if st >= 300 {
		t.Fatalf("entry without lock should succeed: %d %v", st, e)
	}
	if st := c.do("POST", "/api/books/"+bid+"/opening/lock", map[string]any{}, nil); st != http.StatusNotFound && st != http.StatusMethodNotAllowed {
		t.Fatalf("lock endpoint should be gone, got %d", st)
	}
	// KEEP: cannot record before opening date
	st = c.do("POST", "/api/entries", map[string]any{"book_id": bid, "type": "expense", "amount": 50, "account_id": acc["id"], "date": "2000-01-01", "category_id": catID}, nil)
	if st < 400 {
		t.Fatalf("entry before opening date must be rejected, got %d", st)
	}
	// PUT opening writes opening_balance directly
	var op map[string]any
	if st := c.do("PUT", "/api/books/"+bid+"/opening", map[string]any{"accounts": []map[string]any{{"account_id": acc["id"], "amount": 1000}}}, &op); st >= 300 {
		t.Fatalf("put opening %d %v", st, op)
	}
	var n int
	pool := testPool(t)
	defer pool.Close()
	_ = pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM entries WHERE book_id=$1 AND type='opening_balance' AND amount=1000`, bid).Scan(&n)
	if n != 1 {
		t.Fatalf("want 1 opening_balance entry, got %d", n)
	}
	// re-save replaces instead of duplicating
	c.do("PUT", "/api/books/"+bid+"/opening", map[string]any{"accounts": []map[string]any{{"account_id": acc["id"], "amount": 2000}}}, nil)
	_ = pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM entries WHERE book_id=$1 AND type='opening_balance'`, bid).Scan(&n)
	if n != 1 {
		t.Fatalf("opening re-save duplicated: %d", n)
	}
	// moving opening date later than an existing entry must be rejected
	later := time.Now().In(taipei).AddDate(0, 0, 3).Format("2006-01-02")
	if st := c.do("PUT", "/api/books/"+bid+"/opening", map[string]any{"opening_date": later}, nil); st < 400 {
		t.Fatalf("moving opening date past entries must fail, got %d", st)
	}
	// moving earlier is fine
	if st := c.do("PUT", "/api/books/"+bid+"/opening", map[string]any{"opening_date": "2026-01-01"}, nil); st >= 300 {
		t.Fatalf("moving opening date earlier should pass, got %d", st)
	}
}
