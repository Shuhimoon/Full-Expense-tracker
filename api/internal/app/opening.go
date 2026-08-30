package app

import (
	"log"
	"net/http"

	"github.com/google/uuid"

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
		"opening_locked":    b.OpeningLocked,
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
	if b.OpeningLocked {
		writeErr(w, http.StatusConflict, "開帳已鎖定，不能改")
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
	if err := tx.Commit(r.Context()); err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	a.handleOpeningGet(w, r)
}

func (a *App) handleOpeningLock(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	if rejectArchivedWrite(w, b) {
		return
	}
	if b.OpeningLocked {
		writeErr(w, http.StatusConflict, "已經鎖定")
		return
	}
	var body struct {
		Confirm bool `json:"confirm"`
	}
	_ = decodeJSON(r, &body)

	tx, err := a.pool.Begin(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer tx.Rollback(r.Context())

	var od *string
	var locked bool
	err = tx.QueryRow(r.Context(), `SELECT opening_date::text, opening_locked FROM books WHERE id=$1 FOR UPDATE`, b.ID).Scan(&od, &locked)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	if locked {
		writeErr(w, http.StatusConflict, "已經鎖定")
		return
	}
	if od == nil || *od == "" {
		writeErr(w, http.StatusBadRequest, "請先設定開帳日")
		return
	}

	var unknownCount int
	_ = tx.QueryRow(r.Context(), `SELECT COUNT(*) FROM opening_position_drafts WHERE book_id=$1 AND cost_unknown`, b.ID).Scan(&unknownCount)
	if unknownCount > 0 && !body.Confirm {
		writeErr(w, http.StatusBadRequest, "有持倉成本未填，請確認後再鎖")
		return
	}

	crows, err := tx.Query(r.Context(), `SELECT account_id, amount FROM opening_cash_drafts WHERE book_id=$1`, b.ID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
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
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		cas = append(cas, x)
	}
	crows.Close()

	for _, x := range cas {
		if x.amt <= 0 {
			continue
		}
		_, err = tx.Exec(r.Context(),
			`INSERT INTO entries (book_id, date, type, amount, account_id, note)
			 VALUES ($1,$2,'opening_balance',$3,$4,'開帳')`,
			b.ID, *od, x.amt, x.aid)
		if err != nil {
			log.Printf("opening entry: %v", err)
			writeErr(w, http.StatusInternalServerError, "寫入開帳分錄失敗")
			return
		}
	}

	prows, err := tx.Query(r.Context(),
		`SELECT account_id, instrument_id, symbol, name, asset_class, quote_currency, qty, cost_twd, cost_unknown
		 FROM opening_position_drafts WHERE book_id=$1`, b.ID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
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
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		p.qty, p.cost = qty, cost
		pds = append(pds, p)
	}
	prows.Close()

	for _, p := range pds {
		iid := uuid.Nil
		if p.iidPtr != nil {
			iid = *p.iidPtr
		}
		if iid == uuid.Nil {
			err = tx.QueryRow(r.Context(),
				`INSERT INTO instruments (book_id, symbol, name, asset_class, quote_currency)
				 VALUES ($1,$2,$3,$4,$5)
				 ON CONFLICT (book_id, asset_class, symbol) DO UPDATE SET name=COALESCE(NULLIF(EXCLUDED.name,''), instruments.name)
				 RETURNING id`,
				b.ID, p.symbol, p.name, p.ac, p.ccy).Scan(&iid)
			if err != nil {
				log.Printf("instrument: %v", err)
				writeErr(w, http.StatusInternalServerError, "建立標的失敗")
				return
			}
		}
		var price *decimal.Decimal
		if p.qty.GreaterThan(decimal.Zero) && p.cost.GreaterThan(decimal.Zero) {
			pr := p.cost.Div(p.qty)
			price = &pr
		}
		costInt := p.cost.Round(0).IntPart()
		_, err = tx.Exec(r.Context(),
			`INSERT INTO trades (book_id, date, account_id, instrument_id, side, qty, price, price_ccy, fee_twd, proceeds_or_cost_twd, fx_usd_twd, note)
			 VALUES ($1,$2,$3,$4,'opening',$5,$6,$7,0,$8,1,'開帳')`,
			b.ID, *od, p.aid, iid, p.qty, price, p.ccy, costInt)
		if err != nil {
			log.Printf("opening trade: %v", err)
			writeErr(w, http.StatusInternalServerError, "寫入開倉成交失敗")
			return
		}
		_, err = tx.Exec(r.Context(),
			`INSERT INTO positions (book_id, account_id, instrument_id, qty, cost_twd, realized_twd, cost_unknown)
			 VALUES ($1,$2,$3,$4,$5,0,$6)
			 ON CONFLICT (account_id, instrument_id) DO UPDATE SET qty=EXCLUDED.qty, cost_twd=EXCLUDED.cost_twd, cost_unknown=EXCLUDED.cost_unknown, version=positions.version+1, updated_at=now()`,
			b.ID, p.aid, iid, p.qty, p.cost, p.unknown)
		if err != nil {
			log.Printf("opening pos: %v", err)
			writeErr(w, http.StatusInternalServerError, "寫入持倉失敗")
			return
		}
	}

	tag, err := tx.Exec(r.Context(),
		`UPDATE books SET opening_locked=true, version=version+1 WHERE id=$1 AND opening_locked=false`, b.ID)
	if err != nil || tag.RowsAffected() == 0 {
		writeErr(w, http.StatusConflict, "鎖定失敗")
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	nb, _ := a.loadBook(r.Context(), userID(r), b.ID)
	writeJSON(w, http.StatusOK, nb)
}
