package app

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/shopspring/decimal"
)

func (a *App) handleQuotesList(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	rows, err := a.pool.Query(r.Context(), `
		SELECT q.instrument_id, i.symbol, i.asset_class::text, q.price::text, q.ccy::text, q.as_of, q.source::text, q.locked
		FROM quotes q JOIN instruments i ON i.id=q.instrument_id WHERE i.book_id=$1`, b.ID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var iid uuid.UUID
		var sym, ac, price, ccy, src string
		var asof time.Time
		var locked bool
		if err := rows.Scan(&iid, &sym, &ac, &price, &ccy, &asof, &src, &locked); err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		out = append(out, map[string]any{
			"instrument_id": iid, "symbol": sym, "asset_class": ac,
			"price": price, "ccy": ccy, "as_of": asof, "source": src, "locked": locked,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *App) handleQuotesManual(w http.ResponseWriter, r *http.Request) {
	var body struct {
		BookID       string `json:"book_id"`
		InstrumentID string `json:"instrument_id"`
		Price        string `json:"price"`
		Ccy          string `json:"ccy"`
		Locked       *bool  `json:"locked"`
	}
	if err := decodeJSON(r, &body); err != nil {
		writeErr(w, http.StatusBadRequest, "格式不對")
		return
	}
	bookID, err := uuid.Parse(body.BookID)
	if err != nil {
		writeErr(w, http.StatusBadRequest, "缺少 book_id")
		return
	}
	b, err := a.loadBook(r.Context(), userID(r), bookID)
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到帳本")
		return
	}
	if rejectArchivedWrite(w, b) {
		return
	}
	iid, err := uuid.Parse(body.InstrumentID)
	if err != nil {
		writeErr(w, http.StatusBadRequest, "缺少 instrument_id")
		return
	}
	price, err := decimal.NewFromString(body.Price)
	if err != nil || !price.GreaterThan(decimal.Zero) {
		writeErr(w, http.StatusBadRequest, "價格不對")
		return
	}
	ccy := body.Ccy
	if ccy == "" {
		ccy = "TWD"
	}
	locked := false
	if body.Locked != nil {
		locked = *body.Locked
	}
	_, err = a.pool.Exec(r.Context(), `
		INSERT INTO quotes (instrument_id, price, ccy, as_of, source, locked)
		VALUES ($1,$2,$3,now(),'manual',$4)
		ON CONFLICT (instrument_id) DO UPDATE SET price=EXCLUDED.price, ccy=EXCLUDED.ccy, as_of=now(), source='manual', locked=EXCLUDED.locked`,
		iid, price, ccy, locked)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *App) recentlyAttempted(key string) bool {
	a.quoteMu.Lock()
	defer a.quoteMu.Unlock()
	t, ok := a.lastAttempt[key]
	return ok && time.Since(t) < 5*time.Minute
}

func (a *App) markAttempt(key string) {
	a.quoteMu.Lock()
	a.lastAttempt[key] = time.Now()
	a.quoteMu.Unlock()
}

func (a *App) handleQuotesRefresh(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	var lastFX time.Time
	_ = a.pool.QueryRow(r.Context(), `SELECT as_of FROM fx_rates WHERE book_id=$1`, b.ID).Scan(&lastFX)
	needFX := lastFX.IsZero() || time.Since(lastFX) > 5*time.Minute
	fxKey := "fx:" + b.ID.String()
	if needFX && a.recentlyAttempted(fxKey) {
		needFX = false
	}
	failures := []string{}
	if needFX {
		a.markAttempt(fxKey)
		if rate, err := fetchUSDTWD(r.Context()); err == nil {
			_, _ = a.pool.Exec(r.Context(), `
				INSERT INTO fx_rates (book_id, usd_twd, as_of, source) VALUES ($1,$2,now(),'auto')
				ON CONFLICT (book_id) DO UPDATE SET usd_twd=EXCLUDED.usd_twd, as_of=now(), source='auto'`, b.ID, rate)
		} else {
			failures = append(failures, "匯率")
			var n int
			_ = a.pool.QueryRow(r.Context(), `SELECT COUNT(*) FROM fx_rates WHERE book_id=$1`, b.ID).Scan(&n)
			if n == 0 {
				_, _ = a.pool.Exec(r.Context(), `INSERT INTO fx_rates (book_id, usd_twd, as_of, source) VALUES ($1,32,now(),'manual') ON CONFLICT DO NOTHING`, b.ID)
			}
		}
	}
	rows, err := a.pool.Query(r.Context(), `
		SELECT i.id, i.symbol, i.asset_class::text, i.quote_currency::text,
			COALESCE(q.locked,false), COALESCE(q.source::text,''), q.as_of
		FROM instruments i LEFT JOIN quotes q ON q.instrument_id=i.id WHERE i.book_id=$1`, b.ID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	type inst struct {
		id     uuid.UUID
		symbol string
		ac     string
		ccy    string
		locked bool
		source string
		asof   *time.Time
	}
	var list []inst
	for rows.Next() {
		var x inst
		if err := rows.Scan(&x.id, &x.symbol, &x.ac, &x.ccy, &x.locked, &x.source, &x.asof); err == nil {
			list = append(list, x)
		}
	}
	rows.Close()
	updated := 0
	for _, it := range list {
		// locked manual quotes must never be overwritten by auto fetch
		if it.locked && it.source == "manual" {
			continue
		}
		if it.locked {
			continue
		}
		if it.asof != nil && time.Since(*it.asof) < 5*time.Minute {
			continue
		}
		ikey := "q:" + it.id.String()
		if a.recentlyAttempted(ikey) {
			a.quoteMu.Lock()
			prev := a.lastFail[b.ID.String()]
			a.quoteMu.Unlock()
			for _, f := range prev {
				if f == it.symbol {
					failures = append(failures, it.symbol)
					break
				}
			}
			continue
		}
		a.markAttempt(ikey)
		price, ccy, err := fetchQuote(r.Context(), it.symbol, it.ac)
		if err != nil {
			failures = append(failures, it.symbol)
			continue
		}
		_, err = a.pool.Exec(r.Context(), `
			INSERT INTO quotes (instrument_id, price, ccy, as_of, source, locked)
			VALUES ($1,$2,$3,now(),'auto',false)
			ON CONFLICT (instrument_id) DO UPDATE SET price=EXCLUDED.price, ccy=EXCLUDED.ccy, as_of=now(), source='auto'
			WHERE quotes.locked=false AND NOT (quotes.source='manual' AND quotes.locked=true)`, it.id, price, ccy)
		if err == nil {
			updated++
		}
	}
	a.quoteMu.Lock()
	a.lastFail[b.ID.String()] = append([]string{}, failures...)
	a.quoteMu.Unlock()
	msg := ""
	if len(failures) > 0 {
		msg = "報價失敗"
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"updated": updated, "failed": failures, "message": msg, "quote_failed": len(failures) > 0,
	})
}

func (a *App) handleFxGet(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	var rate string
	var asof time.Time
	var src string
	err := a.pool.QueryRow(r.Context(), `SELECT usd_twd::text, as_of, source FROM fx_rates WHERE book_id=$1`, b.ID).Scan(&rate, &asof, &src)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]any{"usd_twd": nil})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"usd_twd": rate, "as_of": asof, "source": src})
}

func (a *App) handleFxSet(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	if rejectArchivedWrite(w, b) {
		return
	}
	var body struct {
		UsdTwd string `json:"usd_twd"`
	}
	if err := decodeJSON(r, &body); err != nil {
		writeErr(w, http.StatusBadRequest, "格式不對")
		return
	}
	rate, err := decimal.NewFromString(body.UsdTwd)
	if err != nil || !rate.GreaterThan(decimal.Zero) {
		writeErr(w, http.StatusBadRequest, "匯率不對")
		return
	}
	_, err = a.pool.Exec(r.Context(), `
		INSERT INTO fx_rates (book_id, usd_twd, as_of, source) VALUES ($1,$2,now(),'manual')
		ON CONFLICT (book_id) DO UPDATE SET usd_twd=EXCLUDED.usd_twd, as_of=now(), source='manual'`, b.ID, rate)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func httpGetJSON(ctx context.Context, url string, dest any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (compatible; full-jizhang/1.0)")
	req.Header.Set("Accept", "application/json")
	client := &http.Client{Timeout: 8 * time.Second}
	res, err := client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode >= 400 {
		b, _ := io.ReadAll(io.LimitReader(res.Body, 2048))
		return fmt.Errorf("http %d %s", res.StatusCode, string(b))
	}
	return json.NewDecoder(res.Body).Decode(dest)
}

func fetchUSDTWD(ctx context.Context) (decimal.Decimal, error) {
	var y map[string]any
	if err := httpGetJSON(ctx, "https://query1.finance.yahoo.com/v8/finance/chart/TWD=X?interval=1d&range=1d", &y); err == nil {
		if p := yahooLast(y); p != nil {
			return *p, nil
		}
	}
	var er struct {
		Rates map[string]float64 `json:"rates"`
	}
	if err := httpGetJSON(ctx, "https://open.er-api.com/v6/latest/USD", &er); err == nil {
		if v, ok := er.Rates["TWD"]; ok && v > 0 {
			return decimal.NewFromFloat(v), nil
		}
	}
	var fr struct {
		Rates map[string]float64 `json:"rates"`
	}
	if err := httpGetJSON(ctx, "https://api.frankfurter.app/latest?from=USD&to=TWD", &fr); err == nil {
		if v, ok := fr.Rates["TWD"]; ok && v > 0 {
			return decimal.NewFromFloat(v), nil
		}
	}
	return decimal.Zero, fmt.Errorf("fx unavailable")
}

func fetchQuote(ctx context.Context, symbol, assetClass string) (decimal.Decimal, string, error) {
	symbol = strings.ToUpper(strings.TrimSpace(symbol))
	switch assetClass {
	case "tw_stock":
		if p, err := fetchTWSE(ctx, symbol); err == nil {
			return p, "TWD", nil
		}
		if p, err := fetchYahoo(ctx, symbol+".TW"); err == nil {
			return p, "TWD", nil
		}
	case "us_stock":
		if p, err := fetchYahoo(ctx, symbol); err == nil {
			return p, "USD", nil
		}
	case "crypto":
		if p, err := fetchCoinGecko(ctx, symbol); err == nil {
			return p, "USD", nil
		}
		if p, err := fetchYahoo(ctx, symbol+"-USD"); err == nil {
			return p, "USD", nil
		}
	case "fx":
		if p, err := fetchYahoo(ctx, symbol); err == nil {
			return p, "USD", nil
		}
	}
	return decimal.Zero, "", fmt.Errorf("no quote")
}

func fetchYahoo(ctx context.Context, symbol string) (decimal.Decimal, error) {
	var y map[string]any
	url := "https://query1.finance.yahoo.com/v8/finance/chart/" + symbol + "?interval=1d&range=1d"
	if err := httpGetJSON(ctx, url, &y); err != nil {
		return decimal.Zero, err
	}
	p := yahooLast(y)
	if p == nil {
		return decimal.Zero, fmt.Errorf("empty")
	}
	return *p, nil
}

func yahooLast(y map[string]any) *decimal.Decimal {
	ch, _ := y["chart"].(map[string]any)
	if ch == nil {
		return nil
	}
	res, _ := ch["result"].([]any)
	if len(res) == 0 {
		return nil
	}
	r0, _ := res[0].(map[string]any)
	meta, _ := r0["meta"].(map[string]any)
	if meta != nil {
		if v, ok := meta["regularMarketPrice"].(float64); ok {
			d := decimal.NewFromFloat(v)
			return &d
		}
	}
	return nil
}

func fetchTWSE(ctx context.Context, symbol string) (decimal.Decimal, error) {
	for _, prefix := range []string{"tse_", "otc_"} {
		url := "https://mis.twse.com.tw/stock/api/getStockInfo.jsp?ex_ch=" + prefix + symbol + ".tw&json=1&delay=0"
		var y map[string]any
		if err := httpGetJSON(ctx, url, &y); err != nil {
			continue
		}
		msg, _ := y["msgArray"].([]any)
		if len(msg) == 0 {
			continue
		}
		m, _ := msg[0].(map[string]any)
		z, _ := m["z"].(string)
		if z == "" || z == "-" {
			z, _ = m["y"].(string)
		}
		if z == "" || z == "-" {
			continue
		}
		return decimal.NewFromString(z)
	}
	return decimal.Zero, fmt.Errorf("empty")
}

func fetchCoinGecko(ctx context.Context, symbol string) (decimal.Decimal, error) {
	ids := map[string]string{
		"BTC": "bitcoin", "ETH": "ethereum", "USDT": "tether", "USDC": "usd-coin",
		"BNB": "binancecoin", "SOL": "solana", "XRP": "ripple", "DOGE": "dogecoin",
	}
	id, ok := ids[strings.ToUpper(symbol)]
	if !ok {
		id = strings.ToLower(symbol)
	}
	var y map[string]map[string]float64
	url := "https://api.coingecko.com/api/v3/simple/price?ids=" + id + "&vs_currencies=usd"
	if err := httpGetJSON(ctx, url, &y); err != nil {
		return decimal.Zero, err
	}
	if v, ok := y[id]["usd"]; ok {
		return decimal.NewFromFloat(v), nil
	}
	return decimal.Zero, fmt.Errorf("empty")
}
