package app

import (
	"context"
	"errors"
	"log"
	"net/http"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/shopspring/decimal"
)

type openingAccountIn struct {
	AccountID uuid.UUID `json:"account_id"`
	Name      string    `json:"name"`
	Type      string    `json:"type"`
	Amount    int64     `json:"amount"`
}

type openingPosIn struct {
	AccountID     uuid.UUID  `json:"account_id"`
	InstrumentID  *uuid.UUID `json:"instrument_id"`
	Symbol        string     `json:"symbol"`
	Name          string     `json:"name"`
	AssetClass    string     `json:"asset_class"`
	QuoteCurrency string     `json:"quote_currency"`
	Qty           string     `json:"qty"`
	CostTwd       string     `json:"cost_twd"`
	CostUnknown   bool       `json:"cost_unknown"`
}

func (a *App) handleOpeningGet(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	accounts, err := a.accountsWithBalance(r.Context(), b.ID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	type cashDraft struct {
		AccountID uuid.UUID `json:"account_id"`
		Amount    int64     `json:"amount"`
	}
	drafts := []cashDraft{}
	rows, err := a.pool.Query(r.Context(), `SELECT account_id, amount FROM opening_cash_drafts WHERE book_id=$1`, b.ID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var d cashDraft
			if err := rows.Scan(&d.AccountID, &d.Amount); err == nil {
				drafts = append(drafts, d)
			}
		}
	}
	type posDraft struct {
		ID            uuid.UUID  `json:"id"`
		AccountID     uuid.UUID  `json:"account_id"`
		InstrumentID  *uuid.UUID `json:"instrument_id"`
		Symbol        string     `json:"symbol"`
		Name          string     `json:"name"`
		AssetClass    string     `json:"asset_class"`
		QuoteCurrency string     `json:"quote_currency"`
		Qty           string     `json:"qty"`
		CostTwd       string     `json:"cost_twd"`
		CostUnknown   bool       `json:"cost_unknown"`
	}
	poss := []posDraft{}
	prows, err := a.pool.Query(r.Context(),
		`SELECT id, account_id, instrument_id, symbol, name, asset_class, quote_currency, qty::text, cost_twd::text, cost_unknown
		 FROM opening_position_drafts WHERE book_id=$1`, b.ID)
	if err == nil {
		defer prows.Close()
		for prows.Next() {
			var p posDraft
			if err := prows.Scan(&p.ID, &p.AccountID, &p.InstrumentID, &p.Symbol, &p.Name, &p.AssetClass, &p.QuoteCurrency, &p.Qty, &p.CostTwd, &p.CostUnknown); err == nil {
				poss = append(poss, p)
			}
		}
	}

	var preview int64
	for _, d := range drafts {
		var typ string
		for _, ac := range accounts {
			if ac.ID == d.AccountID {
				typ = ac.Type
				break
			}
		}
		if typ == "credit_card" {
			preview -= d.Amount
		} else {
			preview += d.Amount
		}
	}
	for _, p := range poss {
		c, err := decimal.NewFromString(p.CostTwd)
		if err == nil {
			preview += c.Round(0).IntPart()
		}
	}

	hasUnknown := false
	for _, p := range poss {
		if p.CostUnknown {
			hasUnknown = true
			break
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"opening_date":      b.OpeningDate,
		"accounts":          accounts,
		"cash_drafts":       drafts,
		"position_drafts":   poss,
		"preview_net_worth": preview,
		"some_cost_unknown": hasUnknown,
	})
}

func (a *App) handleOpeningPut(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	if rejectArchivedWrite(w, b) {
		return
	}
	var body struct {
		OpeningDate *string            `json:"opening_date"`
		Accounts    []openingAccountIn `json:"accounts"`
		Positions   []openingPosIn     `json:"positions"`
	}
	if err := decodeJSON(r, &body); err != nil {
		writeErr(w, http.StatusBadRequest, "格式不對")
		return
	}
	tx, err := a.pool.Begin(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer tx.Rollback(r.Context())
	if body.OpeningDate != nil {
		if *body.OpeningDate == "" {
			_, err = tx.Exec(r.Context(), `UPDATE books SET opening_date=NULL, version=version+1 WHERE id=$1`, b.ID)
		} else {
			if _, err := parseDate(*body.OpeningDate); err != nil {
				writeErr(w, http.StatusBadRequest, "開帳日格式不對")
				return
			}
			var earliest *string
			_ = tx.QueryRow(r.Context(), `SELECT LEAST((SELECT MIN(date)::text FROM entries WHERE book_id=$1 AND type<>'opening_balance'),(SELECT MIN(date)::text FROM trades WHERE book_id=$1 AND side<>'opening'))`, b.ID).Scan(&earliest)
			if earliest != nil && *earliest < *body.OpeningDate {
				writeErr(w, http.StatusBadRequest, "已有早於新開帳日的紀錄（"+*earliest+"），不能把開帳日往後改")
				return
			}
			_, err = tx.Exec(r.Context(), `UPDATE books SET opening_date=$1, version=version+1 WHERE id=$2`, *body.OpeningDate, b.ID)
		}
		if err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
	}
	if body.Accounts != nil {
		_, _ = tx.Exec(r.Context(), `DELETE FROM opening_cash_drafts WHERE book_id=$1`, b.ID)
		for _, ac := range body.Accounts {
			if ac.Amount < 0 {
				writeErr(w, http.StatusBadRequest, "開帳金額不能為負")
				return
			}
			if ac.AccountID == uuid.Nil {
				writeErr(w, http.StatusBadRequest, "缺少 account_id")
				return
			}
			_, err = tx.Exec(r.Context(),
				`INSERT INTO opening_cash_drafts (book_id, account_id, amount) VALUES ($1,$2,$3)
				 ON CONFLICT (book_id, account_id) DO UPDATE SET amount=EXCLUDED.amount`,
				b.ID, ac.AccountID, ac.Amount)
			if err != nil {
				writeErr(w, http.StatusBadRequest, "帳戶不存在或不屬於這本帳")
				return
			}
		}
	}
	if body.Positions != nil {
		_, _ = tx.Exec(r.Context(), `DELETE FROM opening_position_drafts WHERE book_id=$1`, b.ID)
		for _, p := range body.Positions {
			qty, err := decimal.NewFromString(p.Qty)
			if err != nil || !qty.GreaterThan(decimal.Zero) {
				writeErr(w, http.StatusBadRequest, "數量必須大於 0")
				return
			}
			cost := decimal.Zero
			if p.CostTwd != "" {
				cost, err = decimal.NewFromString(p.CostTwd)
				if err != nil || cost.LessThan(decimal.Zero) {
					writeErr(w, http.StatusBadRequest, "成本不對")
					return
				}
			}
			if p.CostUnknown {
				cost = decimal.Zero
			}
			if p.Symbol == "" {
				writeErr(w, http.StatusBadRequest, "請填標的代號")
				return
			}
			if p.AssetClass == "" {
				p.AssetClass = "tw_stock"
			}
			if p.QuoteCurrency == "" {
				if p.AssetClass == "tw_stock" {
					p.QuoteCurrency = "TWD"
				} else {
					p.QuoteCurrency = "USD"
				}
			}
			_, err = tx.Exec(r.Context(),
				`INSERT INTO opening_position_drafts (book_id, account_id, instrument_id, symbol, name, asset_class, quote_currency, qty, cost_twd, cost_unknown)
				 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
				b.ID, p.AccountID, p.InstrumentID, p.Symbol, p.Name, p.AssetClass, p.QuoteCurrency, qty.String(), cost.String(), p.CostUnknown)
			if err != nil {
				log.Printf("opening pos draft: %v", err)
				writeErr(w, http.StatusBadRequest, "現倉暫存失敗")
				return
			}
		}
	}
	if err := applyOpening(r.Context(), tx, b.ID, body.Positions != nil); err != nil {
		var oe *openingErr
		if errors.As(err, &oe) {
			writeErr(w, oe.code, oe.msg)
		} else {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		}
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	a.handleOpeningGet(w, r)
}

type openingErr struct {
	code int
	msg  string
}

func (e *openingErr) Error() string { return e.msg }

// applyOpening materializes opening drafts into real rows (2026-10-20: no lock step).
// Cash drafts always replace the opening_balance entries. Position drafts may be
// replaced at any time; positions and moving-average cost are then replayed from
// the new opening trades plus every later trade.
func applyOpening(ctx context.Context, tx pgx.Tx, bookID uuid.UUID, applyPositions bool) error {
	var odPtr *string
	if err := tx.QueryRow(ctx, `SELECT opening_date::text FROM books WHERE id=$1 FOR UPDATE`, bookID).Scan(&odPtr); err != nil {
		return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
	}
	if odPtr == nil || *odPtr == "" {
		return nil
	}
	od := *odPtr
	if _, err := tx.Exec(ctx, `DELETE FROM entries WHERE book_id=$1 AND type='opening_balance'`, bookID); err != nil {
		return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
	}
	if !applyPositions {
		// only re-date existing opening trades
		_, _ = tx.Exec(ctx, `UPDATE trades SET date=$2 WHERE book_id=$1 AND side='opening'`, bookID, od)
	} else if _, err := tx.Exec(ctx, `DELETE FROM trades WHERE book_id=$1 AND side='opening'`, bookID); err != nil {
		return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
	}
	crows, err := tx.Query(ctx, `SELECT account_id, amount FROM opening_cash_drafts WHERE book_id=$1`, bookID)
	if err != nil {
		return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
	}
	type ca struct {
		aid uuid.UUID
		amt int64
	}
	var cas []ca
	for crows.Next() {
		var x ca
		if err := crows.Scan(&x.aid, &x.amt); err != nil {
			crows.Close()
			return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
		}
		cas = append(cas, x)
	}
	crows.Close()

	for _, x := range cas {
		if x.amt <= 0 {
			continue
		}
		_, err := tx.Exec(ctx,
			`INSERT INTO entries (book_id, date, type, amount, account_id, note)
			 VALUES ($1,$2,'opening_balance',$3,$4,'開帳')`,
			bookID, od, x.amt, x.aid)
		if err != nil {
			log.Printf("opening entry: %v", err)
			return &openingErr{http.StatusInternalServerError, "寫入開帳分錄失敗"}
		}
	}

	if !applyPositions {
		return nil
	}
	prows, err := tx.Query(ctx,
		`SELECT account_id, instrument_id, symbol, name, asset_class, quote_currency, qty, cost_twd, cost_unknown
		 FROM opening_position_drafts WHERE book_id=$1`, bookID)
	if err != nil {
		return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
	}
	type pd struct {
		aid, iid     uuid.UUID
		iidPtr       *uuid.UUID
		symbol, name string
		ac, ccy      string
		qty, cost    decimal.Decimal
		unknown      bool
	}
	var pds []pd
	for prows.Next() {
		var p pd
		var qty, cost decimal.Decimal
		if err := prows.Scan(&p.aid, &p.iidPtr, &p.symbol, &p.name, &p.ac, &p.ccy, &qty, &cost, &p.unknown); err != nil {
			prows.Close()
			return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
		}
		p.qty, p.cost = qty, cost
		pds = append(pds, p)
	}
	prows.Close()

	openingCost := map[uuid.UUID]decimal.Decimal{}
	unknown := map[posKey]bool{}
	for _, p := range pds {
		iid := uuid.Nil
		if p.iidPtr != nil {
			iid = *p.iidPtr
		}
		if iid == uuid.Nil {
			err := tx.QueryRow(ctx,
				`INSERT INTO instruments (book_id, symbol, name, asset_class, quote_currency)
				 VALUES ($1,$2,$3,$4,$5)
				 ON CONFLICT (book_id, asset_class, symbol) DO UPDATE SET name=COALESCE(NULLIF(EXCLUDED.name,''), instruments.name)
				 RETURNING id`,
				bookID, p.symbol, p.name, p.ac, p.ccy).Scan(&iid)
			if err != nil {
				log.Printf("instrument: %v", err)
				return &openingErr{http.StatusInternalServerError, "建立標的失敗"}
			}
		}
		var price *decimal.Decimal
		if p.qty.GreaterThan(decimal.Zero) && p.cost.GreaterThan(decimal.Zero) {
			pr := p.cost.Div(p.qty)
			price = &pr
		}
		costInt := p.cost.Round(0).IntPart()
		var tid uuid.UUID
		err := tx.QueryRow(ctx,
			`INSERT INTO trades (book_id, date, account_id, instrument_id, side, qty, price, price_ccy, fee_twd, proceeds_or_cost_twd, fx_usd_twd, note)
			 VALUES ($1,$2,$3,$4,'opening',$5,$6,$7,0,$8,1,'開帳') RETURNING id`,
			bookID, od, p.aid, iid, p.qty, price, p.ccy, costInt).Scan(&tid)
		if err != nil {
			log.Printf("opening trade: %v", err)
			return &openingErr{http.StatusInternalServerError, "寫入開倉成交失敗"}
		}
		openingCost[tid] = p.cost
		if p.unknown {
			unknown[posKey{p.aid, iid}] = true
		}
	}
	return rebuildPositions(ctx, tx, bookID, openingCost, unknown)
}

// msgNegativeHolding is the only new rejection when an opening edit would make
// a holding negative somewhere on the trade timeline.
const msgNegativeHolding = "修改後持倉會變負數"

type posKey struct {
	acc uuid.UUID
	iid uuid.UUID
}

type replayTrade struct {
	id       uuid.UUID
	acc      uuid.UUID
	iid      uuid.UUID
	pair     *uuid.UUID
	side     string
	qty      decimal.Decimal
	proceeds int64
}

type posState struct {
	qty      decimal.Decimal
	cost     decimal.Decimal
	realized int64
}

// rebuildPositions replays opening + every other trade and rewrites stored
// positions (qty, moving-average cost, realized). Timeline order is trade date,
// then id. Opening lots on that date are applied first: the snapshot is the
// start of the day, and a regenerated opening id must not sort after a same-day sell.
func rebuildPositions(ctx context.Context, tx pgx.Tx, bookID uuid.UUID, openingCost map[uuid.UUID]decimal.Decimal, unknown map[posKey]bool) error {
	rows, err := tx.Query(ctx, `
		SELECT id, account_id, instrument_id, side::text, qty, proceeds_or_cost_twd, pair_id
		FROM trades
		WHERE book_id=$1 AND deleted_at IS NULL
		ORDER BY date ASC, CASE WHEN side='opening' THEN 0 ELSE 1 END, id ASC`, bookID)
	if err != nil {
		log.Printf("rebuild list trades: %v", err)
		return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
	}
	var trades []replayTrade
	for rows.Next() {
		var t replayTrade
		if err := rows.Scan(&t.id, &t.acc, &t.iid, &t.side, &t.qty, &t.proceeds, &t.pair); err != nil {
			rows.Close()
			log.Printf("rebuild scan trade: %v", err)
			return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
		}
		trades = append(trades, t)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		log.Printf("rebuild trades rows: %v", err)
		return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
	}

	qtyNow := map[posKey]decimal.Decimal{}
	for _, t := range trades {
		k := posKey{t.acc, t.iid}
		q := qtyNow[k]
		switch t.side {
		case "buy", "airdrop", "opening", "transfer_in":
			q = q.Add(t.qty)
		case "sell", "transfer_out":
			if t.qty.GreaterThan(q) {
				return &openingErr{http.StatusUnprocessableEntity, msgNegativeHolding}
			}
			q = q.Sub(t.qty)
		default:
			log.Printf("rebuild unknown side %s", t.side)
			return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
		}
		qtyNow[k] = q
	}

	byID := map[uuid.UUID]replayTrade{}
	grouped := map[posKey][]replayTrade{}
	for _, t := range trades {
		byID[t.id] = t
		k := posKey{t.acc, t.iid}
		grouped[k] = append(grouped[k], t)
	}

	moveCost := map[uuid.UUID]decimal.Decimal{}
	computing := map[uuid.UUID]bool{}

	var ensureMove func(outID uuid.UUID) (decimal.Decimal, error)
	var fold func(st *posState, t replayTrade) error

	stateBefore := func(k posKey, before uuid.UUID) (posState, error) {
		var st posState
		found := false
		for _, t := range grouped[k] {
			if t.id == before {
				found = true
				break
			}
			if err := fold(&st, t); err != nil {
				return st, err
			}
		}
		if !found {
			return st, &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
		}
		return st, nil
	}

	fold = func(st *posState, t replayTrade) error {
		switch t.side {
		case "opening":
			add := decimal.NewFromInt(t.proceeds)
			if c, ok := openingCost[t.id]; ok {
				add = c
			}
			st.cost = st.cost.Add(add)
			st.qty = st.qty.Add(t.qty)
		case "buy":
			st.cost = st.cost.Add(decimal.NewFromInt(t.proceeds))
			st.qty = st.qty.Add(t.qty)
		case "airdrop":
			st.qty = st.qty.Add(t.qty)
		case "sell":
			if t.qty.GreaterThan(st.qty) {
				return &openingErr{http.StatusUnprocessableEntity, msgNegativeHolding}
			}
			avg := decimal.Zero
			if st.qty.GreaterThan(decimal.Zero) {
				avg = st.cost.Div(st.qty)
			}
			rlz := decimal.NewFromInt(t.proceeds).Sub(avg.Mul(t.qty)).Round(0).IntPart()
			st.qty = st.qty.Sub(t.qty)
			st.cost = st.cost.Sub(avg.Mul(t.qty))
			if st.cost.LessThan(decimal.Zero) {
				st.cost = decimal.Zero
			}
			st.realized += rlz
		case "transfer_out":
			mc, err := ensureMove(t.id)
			if err != nil {
				return err
			}
			if t.qty.GreaterThan(st.qty) {
				return &openingErr{http.StatusUnprocessableEntity, msgNegativeHolding}
			}
			st.qty = st.qty.Sub(t.qty)
			st.cost = st.cost.Sub(mc)
			if st.cost.LessThan(decimal.Zero) {
				st.cost = decimal.Zero
			}
		case "transfer_in":
			var mc decimal.Decimal
			if t.pair == nil {
				mc = decimal.NewFromInt(t.proceeds)
			} else {
				var err error
				mc, err = ensureMove(*t.pair)
				if err != nil {
					return err
				}
			}
			st.qty = st.qty.Add(t.qty)
			st.cost = st.cost.Add(mc)
		default:
			return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
		}
		return nil
	}

	ensureMove = func(outID uuid.UUID) (decimal.Decimal, error) {
		if c, ok := moveCost[outID]; ok {
			return c, nil
		}
		if computing[outID] {
			// Mutual same-day transfers can cycle when ids put each leg's in before its out.
			// Keep the cost already stored on the transfer_in so both legs stay consistent.
			fb := decimal.Zero
			for _, t := range trades {
				if t.side == "transfer_in" && t.pair != nil && *t.pair == outID {
					fb = decimal.NewFromInt(t.proceeds)
					break
				}
			}
			moveCost[outID] = fb
			return fb, nil
		}
		computing[outID] = true
		defer delete(computing, outID)
		out, ok := byID[outID]
		if !ok {
			return decimal.Zero, &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
		}
		st, err := stateBefore(posKey{out.acc, out.iid}, out.id)
		if err != nil {
			return decimal.Zero, err
		}
		if c, ok := moveCost[outID]; ok {
			return c, nil
		}
		if out.qty.GreaterThan(st.qty) {
			return decimal.Zero, &openingErr{http.StatusUnprocessableEntity, msgNegativeHolding}
		}
		avg := decimal.Zero
		if st.qty.GreaterThan(decimal.Zero) {
			avg = st.cost.Div(st.qty)
		}
		mc := avg.Mul(out.qty)
		moveCost[outID] = mc
		return mc, nil
	}

	for _, t := range trades {
		if t.side != "transfer_out" {
			continue
		}
		if _, err := ensureMove(t.id); err != nil {
			return err
		}
	}

	states := map[posKey]posState{}
	for k, list := range grouped {
		var st posState
		for _, t := range list {
			prevReal := st.realized
			prevCost := st.cost
			if err := fold(&st, t); err != nil {
				return err
			}
			if t.side == "sell" {
				rlz := st.realized - prevReal
				if _, err := tx.Exec(ctx, `UPDATE trades SET realized_twd=$2 WHERE id=$1`, t.id, rlz); err != nil {
					log.Printf("rebuild realized: %v", err)
					return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
				}
			}
			if t.side == "transfer_in" {
				moved := st.cost.Sub(prevCost).Round(0).IntPart()
				if moved != t.proceeds {
					if _, err := tx.Exec(ctx, `UPDATE trades SET proceeds_or_cost_twd=$2 WHERE id=$1`, t.id, moved); err != nil {
						log.Printf("rebuild transfer cost: %v", err)
						return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
					}
				}
			}
		}
		states[k] = st
	}

	if _, err := tx.Exec(ctx, `DELETE FROM positions WHERE book_id=$1`, bookID); err != nil {
		log.Printf("rebuild delete positions: %v", err)
		return &openingErr{http.StatusInternalServerError, "伺服器錯誤"}
	}
	for k, st := range states {
		if _, err := tx.Exec(ctx,
			`INSERT INTO positions (book_id, account_id, instrument_id, qty, cost_twd, realized_twd, cost_unknown)
			 VALUES ($1,$2,$3,$4,$5,$6,$7)`,
			bookID, k.acc, k.iid, st.qty.String(), st.cost.String(), st.realized, unknown[k]); err != nil {
			log.Printf("rebuild insert position: %v", err)
			return &openingErr{http.StatusInternalServerError, "寫入持倉失敗"}
		}
	}
	return nil
}
