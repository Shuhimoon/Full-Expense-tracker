package app

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/shopspring/decimal"
)

type TradeOut struct {
	ID                uuid.UUID  `json:"id"`
	BookID            uuid.UUID  `json:"book_id"`
	Date              string     `json:"date"`
	AccountID         uuid.UUID  `json:"account_id"`
	InstrumentID      uuid.UUID  `json:"instrument_id"`
	Side              string     `json:"side"`
	Qty               string     `json:"qty"`
	Price             *string    `json:"price"`
	PriceCcy          *string    `json:"price_ccy"`
	FeeTwd            int64      `json:"fee_twd"`
	ProceedsOrCostTwd int64      `json:"proceeds_or_cost_twd"`
	FxUsdTwd          string     `json:"fx_usd_twd"`
	RealizedTwd       *int64     `json:"realized_twd"`
	PairID            *uuid.UUID `json:"pair_id"`
	Note              string     `json:"note"`
	CreatedAt         time.Time  `json:"created_at"`
	Version           int        `json:"version"`
}

func (a *App) handleTradesList(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	q := `SELECT id, book_id, date::text, account_id, instrument_id, side::text, qty::text, price::text, price_ccy::text, fee_twd, proceeds_or_cost_twd, fx_usd_twd::text, realized_twd, pair_id, note, created_at, version
		FROM trades WHERE book_id=$1 AND deleted_at IS NULL`
	args := []any{b.ID}
	n := 2
	if d := r.URL.Query().Get("date"); d != "" {
		q += ` AND date=$` + itoa(n)
		args = append(args, d)
		n++
	}
	if from := r.URL.Query().Get("from"); from != "" {
		q += ` AND date>=$` + itoa(n)
		args = append(args, from)
		n++
	}
	if to := r.URL.Query().Get("to"); to != "" {
		q += ` AND date<=$` + itoa(n)
		args = append(args, to)
		n++
	}
	if iid := r.URL.Query().Get("instrument_id"); iid != "" {
		q += ` AND instrument_id=$` + itoa(n)
		args = append(args, iid)
		n++
	}
	if acc := r.URL.Query().Get("account_id"); acc != "" {
		q += ` AND account_id=$` + itoa(n)
		args = append(args, acc)
	}
	q += ` ORDER BY date, created_at`
	rows, err := a.pool.Query(r.Context(), q, args...)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer rows.Close()
	out := []TradeOut{}
	for rows.Next() {
		t, err := scanTrade(rows)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		out = append(out, t)
	}
	writeJSON(w, http.StatusOK, out)
}

func scanTrade(row pgx.Row) (TradeOut, error) {
	var t TradeOut
	err := row.Scan(&t.ID, &t.BookID, &t.Date, &t.AccountID, &t.InstrumentID, &t.Side, &t.Qty, &t.Price, &t.PriceCcy, &t.FeeTwd, &t.ProceedsOrCostTwd, &t.FxUsdTwd, &t.RealizedTwd, &t.PairID, &t.Note, &t.CreatedAt, &t.Version)
	return t, err
}

func (a *App) handleTradesCreate(w http.ResponseWriter, r *http.Request) {
	var body struct {
		BookID       string     `json:"book_id"`
		Date         string     `json:"date"`
		AccountID    uuid.UUID  `json:"account_id"`
		ToAccountID  *uuid.UUID `json:"to_account_id"`
		InstrumentID *uuid.UUID `json:"instrument_id"`
		Symbol       string     `json:"symbol"`
		Name         string     `json:"name"`
		AssetClass   string     `json:"asset_class"`
		QuoteCcy     string     `json:"quote_currency"`
		Side         string     `json:"side"`
		Qty          string     `json:"qty"`
		Price        string     `json:"price"`
		PriceCcy     string     `json:"price_ccy"`
		FeeTwd       int64      `json:"fee_twd"`
		Note         string     `json:"note"`
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
	if !b.OpeningLocked {
		writeErr(w, http.StatusConflict, "請先鎖定開帳再記成交")
		return
	}
	if body.Date == "" {
		body.Date = todayStr()
	}
	if _, err := parseDate(body.Date); err != nil {
		writeErr(w, http.StatusBadRequest, "日期格式不對")
		return
	}
	if b.OpeningDate != nil && body.Date < *b.OpeningDate {
		writeErr(w, http.StatusBadRequest, "不能記開帳日之前的帳")
		return
	}
	qty, err := decimal.NewFromString(body.Qty)
	if err != nil || !qty.GreaterThan(decimal.Zero) {
		writeErr(w, http.StatusBadRequest, "數量必須大於 0")
		return
	}
	if body.FeeTwd < 0 {
		writeErr(w, http.StatusBadRequest, "手續費不能為負")
		return
	}
	side := body.Side
	switch side {
	case "buy", "sell", "airdrop", "transfer_in", "transfer_out", "transfer":
	default:
		writeErr(w, http.StatusBadRequest, "成交方向不對")
		return
	}

	tx, err := a.pool.Begin(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer tx.Rollback(r.Context())

	var accType string
	var accBook uuid.UUID
	if err := tx.QueryRow(r.Context(), `SELECT book_id, type::text FROM accounts WHERE id=$1`, body.AccountID).Scan(&accBook, &accType); err != nil {
		writeErr(w, http.StatusBadRequest, "帳戶不存在")
		return
	}
	if accBook != b.ID || (accType != "broker" && accType != "exchange") {
		writeErr(w, http.StatusBadRequest, "成交帳戶必須是券商或交易所")
		return
	}

	iid, err := a.ensureInstrument(r.Context(), tx, b.ID, body.InstrumentID, body.Symbol, body.Name, body.AssetClass, body.QuoteCcy)
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}

	fx := decimal.NewFromInt(1)
	var fxStored decimal.Decimal
	_ = tx.QueryRow(r.Context(), `SELECT usd_twd FROM fx_rates WHERE book_id=$1`, b.ID).Scan(&fxStored)
	if !fxStored.IsZero() {
		fx = fxStored
	}

	if side == "transfer" {
		if body.ToAccountID == nil {
			writeErr(w, http.StatusBadRequest, "轉倉請選轉入帳戶")
			return
		}
		outT, inT, err := a.applyTransfer(r.Context(), tx, b.ID, body.Date, body.AccountID, *body.ToAccountID, iid, qty, body.FeeTwd, body.Note, fx)
		if err != nil {
			writeErr(w, http.StatusBadRequest, err.Error())
			return
		}
		if err := tx.Commit(r.Context()); err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		writeJSON(w, http.StatusCreated, map[string]any{"out": outT, "in": inT})
		return
	}

	var price decimal.Decimal
	priceCcy := body.PriceCcy
	if side == "buy" || side == "sell" {
		if body.Price == "" {
			writeErr(w, http.StatusBadRequest, "買賣請填單價")
			return
		}
		price, err = decimal.NewFromString(body.Price)
		if err != nil || price.LessThan(decimal.Zero) {
			writeErr(w, http.StatusBadRequest, "單價不對")
			return
		}
		if priceCcy == "" {
			priceCcy = "TWD"
		}
	}
	useFx := fx
	if priceCcy == "TWD" || priceCcy == "" {
		useFx = decimal.NewFromInt(1)
	}
	var proceeds int64
	var realized *int64
	switch side {
	case "buy":
		gross := qty.Mul(price).Mul(useFx).Round(0).IntPart()
		proceeds = gross + body.FeeTwd
	case "sell":
		gross := qty.Mul(price).Mul(useFx).Round(0).IntPart()
		if body.FeeTwd > gross {
			writeErr(w, http.StatusBadRequest, "手續費大於成交額")
			return
		}
		proceeds = gross - body.FeeTwd
	case "airdrop":
		proceeds = 0
		priceCcy = ""
	}

	var posQty, posCost decimal.Decimal
	var posReal int64
	var posVer int
	var posID uuid.UUID
	err = tx.QueryRow(r.Context(),
		`SELECT id, qty, cost_twd, realized_twd, version FROM positions WHERE account_id=$1 AND instrument_id=$2 FOR UPDATE`,
		body.AccountID, iid).Scan(&posID, &posQty, &posCost, &posReal, &posVer)
	if err == pgx.ErrNoRows {
		posQty = decimal.Zero
		posCost = decimal.Zero
	} else if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}

	avg := decimal.Zero
	if posQty.GreaterThan(decimal.Zero) {
		avg = posCost.Div(posQty)
	}

	switch side {
	case "buy", "airdrop":
		addCost := decimal.NewFromInt(proceeds)
		if side == "airdrop" {
			addCost = decimal.Zero
		}
		posCost = posCost.Add(addCost)
		posQty = posQty.Add(qty)
	case "sell":
		if qty.GreaterThan(posQty) {
			writeErr(w, http.StatusConflict, "賣出數量大於持倉")
			return
		}
		rlzDec := decimal.NewFromInt(proceeds).Sub(avg.Mul(qty))
		rlz := rlzDec.Round(0).IntPart()
		realized = &rlz
		posQty = posQty.Sub(qty)
		posCost = posCost.Sub(avg.Mul(qty))
		if posCost.LessThan(decimal.Zero) {
			posCost = decimal.Zero
		}
		posReal += rlz
	}

	var pricePtr *decimal.Decimal
	var ccyPtr *string
	if side == "buy" || side == "sell" {
		pricePtr = &price
		ccyPtr = &priceCcy
	}
	var tid uuid.UUID
	err = tx.QueryRow(r.Context(),
		`INSERT INTO trades (book_id, date, account_id, instrument_id, side, qty, price, price_ccy, fee_twd, proceeds_or_cost_twd, fx_usd_twd, realized_twd, note)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING id`,
		b.ID, body.Date, body.AccountID, iid, side, qty, pricePtr, ccyPtr, body.FeeTwd, proceeds, useFx, realized, body.Note).Scan(&tid)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	if posID == uuid.Nil {
		_, err = tx.Exec(r.Context(),
			`INSERT INTO positions (book_id, account_id, instrument_id, qty, cost_twd, realized_twd) VALUES ($1,$2,$3,$4,$5,$6)`,
			b.ID, body.AccountID, iid, posQty, posCost, posReal)
	} else {
		_, err = tx.Exec(r.Context(),
			`UPDATE positions SET qty=$1, cost_twd=$2, realized_twd=$3, version=version+1, updated_at=now() WHERE id=$4`,
			posQty, posCost, posReal, posID)
	}
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	t, _ := scanTrade(a.pool.QueryRow(r.Context(),
		`SELECT id, book_id, date::text, account_id, instrument_id, side::text, qty::text, price::text, price_ccy::text, fee_twd, proceeds_or_cost_twd, fx_usd_twd::text, realized_twd, pair_id, note, created_at, version FROM trades WHERE id=$1`, tid))
	writeJSON(w, http.StatusCreated, t)
}

func (a *App) ensureInstrument(ctx context.Context, tx pgx.Tx, bookID uuid.UUID, existing *uuid.UUID, symbol, name, assetClass, quoteCcy string) (uuid.UUID, error) {
	if existing != nil && *existing != uuid.Nil {
		var bid uuid.UUID
		if err := tx.QueryRow(ctx, `SELECT book_id FROM instruments WHERE id=$1`, *existing).Scan(&bid); err != nil {
			return uuid.Nil, errString("標的不存在")
		}
		if bid != bookID {
			return uuid.Nil, errString("標的不屬於這本帳")
		}
		return *existing, nil
	}
	symbol = strings.ToUpper(strings.TrimSpace(symbol))
	if symbol == "" {
		return uuid.Nil, errString("請填標的代號")
	}
	if assetClass == "" {
		assetClass = "tw_stock"
	}
	if quoteCcy == "" {
		if assetClass == "tw_stock" {
			quoteCcy = "TWD"
		} else {
			quoteCcy = "USD"
		}
	}
	var id uuid.UUID
	err := tx.QueryRow(ctx,
		`INSERT INTO instruments (book_id, symbol, name, asset_class, quote_currency)
		 VALUES ($1,$2,$3,$4,$5)
		 ON CONFLICT (book_id, asset_class, symbol) DO UPDATE SET name=COALESCE(NULLIF(EXCLUDED.name,''), instruments.name)
		 RETURNING id`, bookID, symbol, name, assetClass, quoteCcy).Scan(&id)
	if err != nil {
		return uuid.Nil, errString("無法建立標的")
	}
	return id, nil
}

func (a *App) applyTransfer(ctx context.Context, tx pgx.Tx, bookID uuid.UUID, date string, fromAcc, toAcc, iid uuid.UUID, qty decimal.Decimal, fee int64, note string, fx decimal.Decimal) (uuid.UUID, uuid.UUID, error) {
	if fromAcc == toAcc {
		return uuid.Nil, uuid.Nil, errString("不能轉給自己")
	}
	var toType string
	var toBook uuid.UUID
	if err := tx.QueryRow(ctx, `SELECT book_id, type::text FROM accounts WHERE id=$1`, toAcc).Scan(&toBook, &toType); err != nil {
		return uuid.Nil, uuid.Nil, errString("轉入帳戶不存在")
	}
	if toBook != bookID || (toType != "broker" && toType != "exchange") {
		return uuid.Nil, uuid.Nil, errString("轉入帳戶必須是券商或交易所")
	}
	var posQty, posCost decimal.Decimal
	var posReal int64
	var posID uuid.UUID
	err := tx.QueryRow(ctx, `SELECT id, qty, cost_twd, realized_twd FROM positions WHERE account_id=$1 AND instrument_id=$2 FOR UPDATE`, fromAcc, iid).Scan(&posID, &posQty, &posCost, &posReal)
	if err != nil {
		return uuid.Nil, uuid.Nil, errString("轉出帳戶沒有此持倉")
	}
	if qty.GreaterThan(posQty) {
		return uuid.Nil, uuid.Nil, errString("轉出數量大於持倉")
	}
	avg := decimal.Zero
	if posQty.GreaterThan(decimal.Zero) {
		avg = posCost.Div(posQty)
	}
	moveCost := avg.Mul(qty)
	posQty = posQty.Sub(qty)
	posCost = posCost.Sub(moveCost)
	if posCost.LessThan(decimal.Zero) {
		posCost = decimal.Zero
	}
	_, err = tx.Exec(ctx, `UPDATE positions SET qty=$1, cost_twd=$2, version=version+1, updated_at=now() WHERE id=$3`, posQty, posCost, posID)
	if err != nil {
		return uuid.Nil, uuid.Nil, errString("更新轉出持倉失敗")
	}
	var outID, inID uuid.UUID
	err = tx.QueryRow(ctx,
		`INSERT INTO trades (book_id, date, account_id, instrument_id, side, qty, fee_twd, proceeds_or_cost_twd, fx_usd_twd, note)
		 VALUES ($1,$2,$3,$4,'transfer_out',$5,$6,0,$7,$8) RETURNING id`,
		bookID, date, fromAcc, iid, qty, fee, fx, note).Scan(&outID)
	if err != nil {
		return uuid.Nil, uuid.Nil, errString("寫入轉出成交失敗")
	}
	err = tx.QueryRow(ctx,
		`INSERT INTO trades (book_id, date, account_id, instrument_id, side, qty, fee_twd, proceeds_or_cost_twd, fx_usd_twd, pair_id, note)
		 VALUES ($1,$2,$3,$4,'transfer_in',$5,0,$6,$7,$8,$9) RETURNING id`,
		bookID, date, toAcc, iid, qty, moveCost.Round(0).IntPart(), fx, outID, note).Scan(&inID)
	if err != nil {
		return uuid.Nil, uuid.Nil, errString("寫入轉入成交失敗")
	}
	_, _ = tx.Exec(ctx, `UPDATE trades SET pair_id=$1 WHERE id=$2`, inID, outID)

	var inPosID uuid.UUID
	var inQty, inCost decimal.Decimal
	var inReal int64
	err = tx.QueryRow(ctx, `SELECT id, qty, cost_twd, realized_twd FROM positions WHERE account_id=$1 AND instrument_id=$2 FOR UPDATE`, toAcc, iid).Scan(&inPosID, &inQty, &inCost, &inReal)
	if err == pgx.ErrNoRows {
		_, err = tx.Exec(ctx, `INSERT INTO positions (book_id, account_id, instrument_id, qty, cost_twd) VALUES ($1,$2,$3,$4,$5)`,
			bookID, toAcc, iid, qty, moveCost)
	} else if err == nil {
		_, err = tx.Exec(ctx, `UPDATE positions SET qty=$1, cost_twd=$2, version=version+1, updated_at=now() WHERE id=$3`,
			inQty.Add(qty), inCost.Add(moveCost), inPosID)
	}
	if err != nil {
		return uuid.Nil, uuid.Nil, errString("更新轉入持倉失敗")
	}
	if fee > 0 {
		var cat uuid.UUID
		_ = tx.QueryRow(ctx, `SELECT id FROM categories WHERE book_id=$1 AND name='投資費用' AND kind='expense' LIMIT 1`, bookID).Scan(&cat)
		if cat != uuid.Nil {
			_, _ = tx.Exec(ctx, `INSERT INTO entries (book_id, date, type, amount, account_id, category_id, note)
				VALUES ($1,$2,'expense',$3,$4,$5,'搬倉手續費')`, bookID, date, fee, fromAcc, cat)
		}
	}
	return outID, inID, nil
}

func (a *App) handleTradesDelete(w http.ResponseWriter, r *http.Request) {
	writeErr(w, http.StatusConflict, "v1 成交請用反向成交調整，不提供直接刪除重算")
}

func (a *App) handlePositionsList(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	sql := `
		SELECT p.id, p.book_id, p.account_id, a.name, p.instrument_id, i.symbol, i.name, i.asset_class::text, i.quote_currency::text,
			p.qty::text, p.cost_twd::text, p.realized_twd, p.cost_unknown, p.version,
			q.price::text, q.ccy::text, q.as_of, q.source::text, q.locked, f.usd_twd::text
		FROM positions p
		JOIN accounts a ON a.id=p.account_id
		JOIN instruments i ON i.id=p.instrument_id
		LEFT JOIN quotes q ON q.instrument_id=i.id
		LEFT JOIN fx_rates f ON f.book_id=p.book_id
		WHERE p.book_id=$1`
	args := []any{b.ID}
	if acc := r.URL.Query().Get("account_id"); acc != "" {
		if _, err := uuid.Parse(acc); err != nil {
			writeErr(w, http.StatusBadRequest, "account_id 不對")
			return
		}
		sql += ` AND p.account_id=$2`
		args = append(args, acc)
	}
	sql += ` ORDER BY p.qty DESC, i.symbol`
	rows, err := a.pool.Query(r.Context(), sql, args...)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, bookID, accID, iid uuid.UUID
		var accName, symbol, iname, ac, qccy, qty, cost string
		var realized int64
		var unknown bool
		var ver int
		var price, pccy, src, fx *string
		var asof *time.Time
		var locked *bool
		if err := rows.Scan(&id, &bookID, &accID, &accName, &iid, &symbol, &iname, &ac, &qccy, &qty, &cost, &realized, &unknown, &ver, &price, &pccy, &asof, &src, &locked, &fx); err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		item := map[string]any{
			"id": id, "book_id": bookID, "account_id": accID, "account_name": accName,
			"instrument_id": iid, "symbol": symbol, "name": iname, "asset_class": ac, "quote_currency": qccy,
			"qty": qty, "cost_twd": cost, "realized_twd": realized, "cost_unknown": unknown, "version": ver,
		}
		qd, _ := decimal.NewFromString(qty)
		cd, _ := decimal.NewFromString(cost)
		avg := decimal.Zero
		if qd.GreaterThan(decimal.Zero) {
			avg = cd.Div(qd)
		}
		item["avg_cost_twd"] = avg.StringFixed(4)
		if price != nil {
			px, _ := decimal.NewFromString(*price)
			ccy := qccy
			if pccy != nil {
				ccy = *pccy
			}
			if ccy == "USD" {
				mult := decimal.NewFromInt(32)
				if fx != nil {
					if fxd, err := decimal.NewFromString(*fx); err == nil {
						mult = fxd
					}
				}
				px = px.Mul(mult)
			}
			mv := qd.Mul(px)
			unreal := mv.Sub(cd)
			mvI := mv.Round(0).IntPart()
			unI := unreal.Round(0).IntPart()
			item["price_twd"] = px.StringFixed(4)
			item["market_value"] = mvI
			item["unrealized"] = unI
			if !cd.IsZero() {
				item["unrealized_pct"] = unreal.Div(cd).Mul(decimal.NewFromInt(100)).StringFixed(2)
			} else {
				item["unrealized_pct"] = nil
			}
			item["quote_price"] = *price
			item["quote_ccy"] = ccy
			item["quote_as_of"] = asof
			if src != nil {
				item["quote_source"] = *src
			}
			if locked != nil {
				item["quote_locked"] = *locked
			}
		} else {
			item["market_value"] = nil
			item["unrealized"] = nil
			item["unrealized_pct"] = nil
		}
		item["closed"] = !qd.GreaterThan(decimal.Zero)
		out = append(out, item)
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *App) handlePositionsGet(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到持倉")
		return
	}
	var bookID uuid.UUID
	if err := a.pool.QueryRow(r.Context(), `SELECT book_id FROM positions WHERE id=$1`, id).Scan(&bookID); err != nil {
		writeErr(w, http.StatusNotFound, "找不到持倉")
		return
	}
	if _, err := a.loadBook(r.Context(), userID(r), bookID); err != nil {
		writeErr(w, http.StatusNotFound, "找不到帳本")
		return
	}
	var acc uuid.UUID
	var iid uuid.UUID
	_ = a.pool.QueryRow(r.Context(), `SELECT account_id, instrument_id FROM positions WHERE id=$1`, id).Scan(&acc, &iid)
	r2 := r.Clone(r.Context())
	q := r2.URL.Query()
	q.Set("book_id", bookID.String())
	r2.URL.RawQuery = q.Encode()
	listW := &capture{ResponseWriter: w, status: 200}
	_ = listW
	rows, err := a.pool.Query(r.Context(),
		`SELECT id, book_id, date::text, account_id, instrument_id, side::text, qty::text, price::text, price_ccy::text, fee_twd, proceeds_or_cost_twd, fx_usd_twd::text, realized_twd, pair_id, note, created_at, version
		 FROM trades WHERE account_id=$1 AND instrument_id=$2 AND deleted_at IS NULL ORDER BY date, created_at`, acc, iid)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer rows.Close()
	trades := []TradeOut{}
	for rows.Next() {
		t, err := scanTrade(rows)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		trades = append(trades, t)
	}
	writeJSON(w, http.StatusOK, map[string]any{"id": id, "account_id": acc, "instrument_id": iid, "trades": trades})
}

func (a *App) handleInstrumentsList(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	rows, err := a.pool.Query(r.Context(),
		`SELECT id, book_id, symbol, name, asset_class::text, quote_currency::text FROM instruments WHERE book_id=$1 ORDER BY symbol`, b.ID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer rows.Close()
	out := []map[string]any{}
	for rows.Next() {
		var id, bid uuid.UUID
		var sym, name, ac, ccy string
		if err := rows.Scan(&id, &bid, &sym, &name, &ac, &ccy); err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		out = append(out, map[string]any{"id": id, "book_id": bid, "symbol": sym, "name": name, "asset_class": ac, "quote_currency": ccy})
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *App) handleInstrumentsCreate(w http.ResponseWriter, r *http.Request) {
	var body struct {
		BookID        string `json:"book_id"`
		Symbol        string `json:"symbol"`
		Name          string `json:"name"`
		AssetClass    string `json:"asset_class"`
		QuoteCurrency string `json:"quote_currency"`
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
	tx, err := a.pool.Begin(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer tx.Rollback(r.Context())
	id, err := a.ensureInstrument(r.Context(), tx, b.ID, nil, body.Symbol, body.Name, body.AssetClass, body.QuoteCurrency)
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	_ = tx.Commit(r.Context())
	writeJSON(w, http.StatusCreated, map[string]any{"id": id})
}
