package app

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func (a *App) exportBook(ctx context.Context, bookID uuid.UUID) (map[string]any, error) {
	out := map[string]any{}
	b, err := scanBook(a.pool.QueryRow(ctx, `SELECT `+bookCols+` FROM books WHERE id=$1`, bookID))
	if err != nil {
		return nil, err
	}
	out["book"] = b

	out["accounts"], err = queryMaps(ctx, a.pool, `SELECT id, name, type, archived_at, created_at, version FROM accounts WHERE book_id=$1 ORDER BY created_at`, bookID)
	if err != nil {
		return nil, err
	}
	out["categories"], err = queryMaps(ctx, a.pool, `SELECT id, name, kind, is_system, archived_at, sort, version FROM categories WHERE book_id=$1 ORDER BY kind, sort`, bookID)
	if err != nil {
		return nil, err
	}
	out["instruments"], err = queryMaps(ctx, a.pool, `SELECT id, symbol, name, asset_class, quote_currency FROM instruments WHERE book_id=$1`, bookID)
	if err != nil {
		return nil, err
	}
	out["entries"], err = queryMaps(ctx, a.pool, `SELECT id, date, type, amount, account_id, to_account_id, category_id, note, instrument_id, created_at, updated_at, deleted_at, version FROM entries WHERE book_id=$1 ORDER BY date, created_at`, bookID)
	if err != nil {
		return nil, err
	}
	out["trades"], err = queryMaps(ctx, a.pool, `SELECT id, date, account_id, instrument_id, side, qty, price, price_ccy, fee_twd, proceeds_or_cost_twd, fx_usd_twd, realized_twd, pair_id, note, created_at, updated_at, deleted_at, version FROM trades WHERE book_id=$1 ORDER BY date, created_at`, bookID)
	if err != nil {
		return nil, err
	}
	out["positions"], err = queryMaps(ctx, a.pool, `SELECT id, account_id, instrument_id, qty, cost_twd, realized_twd, cost_unknown, version, updated_at FROM positions WHERE book_id=$1`, bookID)
	if err != nil {
		return nil, err
	}
	out["quotes"], err = queryMaps(ctx, a.pool, `SELECT q.instrument_id, q.price, q.ccy, q.as_of, q.source, q.locked FROM quotes q JOIN instruments i ON i.id=q.instrument_id WHERE i.book_id=$1`, bookID)
	if err != nil {
		return nil, err
	}
	out["fx_rates"], err = queryMaps(ctx, a.pool, `SELECT book_id, usd_twd, as_of, source FROM fx_rates WHERE book_id=$1`, bookID)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func queryMaps(ctx context.Context, db interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
}, q string, args ...any) ([]map[string]any, error) {
	rows, err := db.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	fds := rows.FieldDescriptions()
	var out []map[string]any
	for rows.Next() {
		vals, err := rows.Values()
		if err != nil {
			return nil, err
		}
		m := map[string]any{}
		for i, fd := range fds {
			m[string(fd.Name)] = exportVal(vals[i])
		}
		out = append(out, m)
	}
	if out == nil {
		out = []map[string]any{}
	}
	return out, rows.Err()
}

func exportVal(v any) any {
	if v == nil {
		return nil
	}
	switch t := v.(type) {
	case [16]byte:
		return uuid.UUID(t).String()
	case uuid.UUID:
		return t.String()
	case *uuid.UUID:
		if t == nil {
			return nil
		}
		return t.String()
	case time.Time:
		return t
	case *time.Time:
		if t == nil {
			return nil
		}
		return *t
	default:
		return v
	}
}

type flexStr string

func (s *flexStr) UnmarshalJSON(b []byte) error {
	b = bytes.TrimSpace(b)
	if len(b) == 0 || string(b) == "null" {
		*s = ""
		return nil
	}
	if b[0] == '"' {
		var v string
		if err := json.Unmarshal(b, &v); err != nil {
			return err
		}
		*s = flexStr(v)
		return nil
	}
	*s = flexStr(b)
	return nil
}

func (s flexStr) String() string { return string(s) }

func asDate(s string) string {
	s = strings.TrimSpace(s)
	if len(s) >= 10 && s[4] == '-' && s[7] == '-' {
		return s[:10]
	}
	return s
}

func nextMapped(old uuid.UUID, m map[uuid.UUID]uuid.UUID) uuid.UUID {
	n := uuid.New()
	if old != uuid.Nil {
		m[old] = n
	}
	return n
}

func lookupUUID(old uuid.UUID, m map[uuid.UUID]uuid.UUID) uuid.UUID {
	if n, ok := m[old]; ok {
		return n
	}
	return old
}

func lookupPtr(old *uuid.UUID, m map[uuid.UUID]uuid.UUID) *uuid.UUID {
	if old == nil || *old == uuid.Nil {
		return nil
	}
	n := lookupUUID(*old, m)
	return &n
}

func (a *App) importBook(ctx context.Context, bookID uuid.UUID, payload map[string]json.RawMessage) error {
	tx, err := a.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	for _, stmt := range []string{
		`DELETE FROM quotes WHERE instrument_id IN (SELECT id FROM instruments WHERE book_id=$1)`,
		`DELETE FROM trades WHERE book_id=$1`,
		`DELETE FROM positions WHERE book_id=$1`,
		`DELETE FROM entries WHERE book_id=$1`,
		`DELETE FROM opening_position_drafts WHERE book_id=$1`,
		`DELETE FROM opening_cash_drafts WHERE book_id=$1`,
		`DELETE FROM fx_rates WHERE book_id=$1`,
		`DELETE FROM instruments WHERE book_id=$1`,
		`DELETE FROM categories WHERE book_id=$1`,
		`DELETE FROM accounts WHERE book_id=$1`,
	} {
		if _, err := tx.Exec(ctx, stmt, bookID); err != nil {
			return fmt.Errorf("clear: %w", err)
		}
	}

	if raw, ok := payload["book"]; ok {
		var bk map[string]any
		if err := json.Unmarshal(raw, &bk); err == nil {
			if name, _ := bk["name"].(string); name != "" {
				_, _ = tx.Exec(ctx, `UPDATE books SET name=$1 WHERE id=$2`, name, bookID)
			}
			if od, ok := bk["opening_date"].(string); ok && od != "" {
				_, _ = tx.Exec(ctx, `UPDATE books SET opening_date=$1 WHERE id=$2`, asDate(od), bookID)
			}
			if locked, ok := bk["opening_locked"].(bool); ok {
				_, _ = tx.Exec(ctx, `UPDATE books SET opening_locked=$1 WHERE id=$2`, locked, bookID)
			}
		}
	}

	accMap := map[uuid.UUID]uuid.UUID{}
	catMap := map[uuid.UUID]uuid.UUID{}
	instMap := map[uuid.UUID]uuid.UUID{}
	tradeMap := map[uuid.UUID]uuid.UUID{}

	type accIn struct {
		ID         uuid.UUID `json:"id"`
		Name       string    `json:"name"`
		Type       string    `json:"type"`
		ArchivedAt *string   `json:"archived_at"`
		CreatedAt  *string   `json:"created_at"`
		Version    int       `json:"version"`
	}
	var accounts []accIn
	if raw, ok := payload["accounts"]; ok {
		if err := json.Unmarshal(raw, &accounts); err != nil {
			return fmt.Errorf("accounts: %w", err)
		}
	}
	for _, ac := range accounts {
		old := ac.ID
		ac.ID = nextMapped(old, accMap)
		if ac.Version == 0 {
			ac.Version = 1
		}
		_, err := tx.Exec(ctx, `INSERT INTO accounts (id, book_id, name, type, version) VALUES ($1,$2,$3,$4,$5)`,
			ac.ID, bookID, ac.Name, ac.Type, ac.Version)
		if err != nil {
			return fmt.Errorf("account %s: %w", ac.Name, err)
		}
		if ac.ArchivedAt != nil && *ac.ArchivedAt != "" {
			_, _ = tx.Exec(ctx, `UPDATE accounts SET archived_at=now() WHERE id=$1`, ac.ID)
		}
	}

	type catIn struct {
		ID       uuid.UUID `json:"id"`
		Name     string    `json:"name"`
		Kind     string    `json:"kind"`
		IsSystem bool      `json:"is_system"`
		Sort     int       `json:"sort"`
		Version  int       `json:"version"`
	}
	var cats []catIn
	if raw, ok := payload["categories"]; ok {
		_ = json.Unmarshal(raw, &cats)
	}
	if len(cats) == 0 {
		if err := a.seedCategories(ctx, tx, bookID); err != nil {
			return err
		}
	} else {
		for _, c := range cats {
			old := c.ID
			c.ID = nextMapped(old, catMap)
			if c.Version == 0 {
				c.Version = 1
			}
			_, err := tx.Exec(ctx, `INSERT INTO categories (id, book_id, name, kind, is_system, sort, version) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
				c.ID, bookID, c.Name, c.Kind, c.IsSystem, c.Sort, c.Version)
			if err != nil {
				return fmt.Errorf("category %s: %w", c.Name, err)
			}
		}
	}

	type instIn struct {
		ID            uuid.UUID `json:"id"`
		Symbol        string    `json:"symbol"`
		Name          string    `json:"name"`
		AssetClass    string    `json:"asset_class"`
		QuoteCurrency string    `json:"quote_currency"`
	}
	var insts []instIn
	if raw, ok := payload["instruments"]; ok {
		_ = json.Unmarshal(raw, &insts)
	}
	for _, in := range insts {
		old := in.ID
		in.ID = nextMapped(old, instMap)
		_, err := tx.Exec(ctx, `INSERT INTO instruments (id, book_id, symbol, name, asset_class, quote_currency) VALUES ($1,$2,$3,$4,$5,$6)`,
			in.ID, bookID, in.Symbol, in.Name, in.AssetClass, in.QuoteCurrency)
		if err != nil {
			return fmt.Errorf("instrument %s: %w", in.Symbol, err)
		}
	}

	type entIn struct {
		ID           uuid.UUID  `json:"id"`
		Date         flexStr    `json:"date"`
		Type         string     `json:"type"`
		Amount       int64      `json:"amount"`
		AccountID    uuid.UUID  `json:"account_id"`
		ToAccountID  *uuid.UUID `json:"to_account_id"`
		CategoryID   *uuid.UUID `json:"category_id"`
		Note         string     `json:"note"`
		InstrumentID *uuid.UUID `json:"instrument_id"`
		Version      int        `json:"version"`
		DeletedAt    *string    `json:"deleted_at"`
	}
	var ents []entIn
	if raw, ok := payload["entries"]; ok {
		_ = json.Unmarshal(raw, &ents)
	}
	for _, e := range ents {
		if e.ID == uuid.Nil {
			e.ID = uuid.New()
		} else {
			e.ID = uuid.New()
		}
		if e.Version == 0 {
			e.Version = 1
		}
		acc := lookupUUID(e.AccountID, accMap)
		_, err := tx.Exec(ctx, `INSERT INTO entries (id, book_id, date, type, amount, account_id, to_account_id, category_id, note, instrument_id, version) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
			e.ID, bookID, asDate(e.Date.String()), e.Type, e.Amount, acc, lookupPtr(e.ToAccountID, accMap), lookupPtr(e.CategoryID, catMap), e.Note, lookupPtr(e.InstrumentID, instMap), e.Version)
		if err != nil {
			return fmt.Errorf("entry: %w", err)
		}
		if e.DeletedAt != nil {
			_, _ = tx.Exec(ctx, `UPDATE entries SET deleted_at=now() WHERE id=$1`, e.ID)
		}
	}

	type trIn struct {
		ID                uuid.UUID  `json:"id"`
		Date              flexStr    `json:"date"`
		AccountID         uuid.UUID  `json:"account_id"`
		InstrumentID      uuid.UUID  `json:"instrument_id"`
		Side              string     `json:"side"`
		Qty               flexStr    `json:"qty"`
		Price             *flexStr   `json:"price"`
		PriceCcy          *string    `json:"price_ccy"`
		FeeTwd            int64      `json:"fee_twd"`
		ProceedsOrCostTwd int64      `json:"proceeds_or_cost_twd"`
		FxUsdTwd          flexStr    `json:"fx_usd_twd"`
		RealizedTwd       *int64     `json:"realized_twd"`
		PairID            *uuid.UUID `json:"pair_id"`
		Note              string     `json:"note"`
		Version           int        `json:"version"`
	}
	var trades []trIn
	if raw, ok := payload["trades"]; ok {
		if err := json.Unmarshal(raw, &trades); err != nil {
			return fmt.Errorf("trades: %w", err)
		}
	}

	type tradeInserted struct {
		newID  uuid.UUID
		pairOf *uuid.UUID
	}
	inserted := make([]tradeInserted, 0, len(trades))

	for _, t := range trades {
		old := t.ID
		t.ID = nextMapped(old, tradeMap)
		if t.Version == 0 {
			t.Version = 1
		}
		fx := t.FxUsdTwd.String()
		if fx == "" {
			fx = "1"
		}
		var price any
		if t.Price != nil && t.Price.String() != "" {
			price = t.Price.String()
		}
		_, err := tx.Exec(ctx, `INSERT INTO trades (id, book_id, date, account_id, instrument_id, side, qty, price, price_ccy, fee_twd, proceeds_or_cost_twd, fx_usd_twd, realized_twd, pair_id, note, version)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)`,
			t.ID, bookID, asDate(t.Date.String()), lookupUUID(t.AccountID, accMap), lookupUUID(t.InstrumentID, instMap), t.Side, t.Qty.String(), price, t.PriceCcy, t.FeeTwd, t.ProceedsOrCostTwd, fx, t.RealizedTwd, nil, t.Note, t.Version)
		if err != nil {
			return fmt.Errorf("trade: %w", err)
		}
		inserted = append(inserted, tradeInserted{newID: t.ID, pairOf: t.PairID})
	}

	// Second pass: restore pair_id after both siblings exist (self-FK). Remap to new IDs.
	for _, it := range inserted {
		if it.pairOf == nil || *it.pairOf == uuid.Nil {
			continue
		}
		sib, ok := tradeMap[*it.pairOf]
		if !ok {
			continue
		}
		if _, err := tx.Exec(ctx, `UPDATE trades SET pair_id=$1 WHERE id=$2`, sib, it.newID); err != nil {
			return fmt.Errorf("trade pair_id: %w", err)
		}
	}

	type posIn struct {
		ID           uuid.UUID `json:"id"`
		AccountID    uuid.UUID `json:"account_id"`
		InstrumentID uuid.UUID `json:"instrument_id"`
		Qty          flexStr   `json:"qty"`
		CostTwd      flexStr   `json:"cost_twd"`
		RealizedTwd  int64     `json:"realized_twd"`
		CostUnknown  bool      `json:"cost_unknown"`
		Version      int       `json:"version"`
	}
	var poss []posIn
	if raw, ok := payload["positions"]; ok {
		_ = json.Unmarshal(raw, &poss)
	}
	for _, p := range poss {
		if p.ID == uuid.Nil {
			p.ID = uuid.New()
		} else {
			p.ID = uuid.New()
		}
		if p.Version == 0 {
			p.Version = 1
		}
		_, err := tx.Exec(ctx, `INSERT INTO positions (id, book_id, account_id, instrument_id, qty, cost_twd, realized_twd, cost_unknown, version) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
			p.ID, bookID, lookupUUID(p.AccountID, accMap), lookupUUID(p.InstrumentID, instMap), p.Qty.String(), p.CostTwd.String(), p.RealizedTwd, p.CostUnknown, p.Version)
		if err != nil {
			return fmt.Errorf("position: %w", err)
		}
	}

	type qIn struct {
		InstrumentID uuid.UUID `json:"instrument_id"`
		Price        flexStr   `json:"price"`
		Ccy          string    `json:"ccy"`
		AsOf         *string   `json:"as_of"`
		Source       string    `json:"source"`
		Locked       bool      `json:"locked"`
	}
	var qs []qIn
	if raw, ok := payload["quotes"]; ok {
		_ = json.Unmarshal(raw, &qs)
	}
	for _, q := range qs {
		iid := lookupUUID(q.InstrumentID, instMap)
		if iid == uuid.Nil || q.Price.String() == "" {
			continue
		}
		if q.Ccy == "" {
			q.Ccy = "TWD"
		}
		if q.Source == "" {
			q.Source = "manual"
		}
		asof := time.Now()
		if q.AsOf != nil && *q.AsOf != "" {
			if t, err := time.Parse(time.RFC3339Nano, *q.AsOf); err == nil {
				asof = t
			} else if t, err := time.Parse(time.RFC3339, *q.AsOf); err == nil {
				asof = t
			}
		}
		_, err := tx.Exec(ctx, `INSERT INTO quotes (instrument_id, price, ccy, as_of, source, locked) VALUES ($1,$2,$3,$4,$5,$6)
			ON CONFLICT (instrument_id) DO UPDATE SET price=EXCLUDED.price, ccy=EXCLUDED.ccy, as_of=EXCLUDED.as_of, source=EXCLUDED.source, locked=EXCLUDED.locked`,
			iid, q.Price.String(), q.Ccy, asof, q.Source, q.Locked)
		if err != nil {
			return fmt.Errorf("quote: %w", err)
		}
	}

	type fxIn struct {
		UsdTwd flexStr `json:"usd_twd"`
		AsOf   *string `json:"as_of"`
		Source string  `json:"source"`
	}
	var fxs []fxIn
	if raw, ok := payload["fx_rates"]; ok {
		_ = json.Unmarshal(raw, &fxs)
	}
	for _, f := range fxs {
		if f.UsdTwd.String() == "" {
			continue
		}
		if f.Source == "" {
			f.Source = "manual"
		}
		asof := time.Now()
		if f.AsOf != nil && *f.AsOf != "" {
			if t, err := time.Parse(time.RFC3339Nano, *f.AsOf); err == nil {
				asof = t
			} else if t, err := time.Parse(time.RFC3339, *f.AsOf); err == nil {
				asof = t
			}
		}
		_, err := tx.Exec(ctx, `INSERT INTO fx_rates (book_id, usd_twd, as_of, source) VALUES ($1,$2,$3,$4)
			ON CONFLICT (book_id) DO UPDATE SET usd_twd=EXCLUDED.usd_twd, as_of=EXCLUDED.as_of, source=EXCLUDED.source`,
			bookID, f.UsdTwd.String(), asof, f.Source)
		if err != nil {
			return fmt.Errorf("fx: %w", err)
		}
	}

	return tx.Commit(ctx)
}
