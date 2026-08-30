package app

import (
	"context"
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/shopspring/decimal"
)

func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://fulljizhang:fulljizhang@127.0.0.1:5432/fulljizhang?sslmode=disable"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Skipf("no postgres: %v", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		t.Skipf("postgres ping: %v", err)
	}
	return pool
}

func TestImportRestoresTradePairID(t *testing.T) {
	pool := testPool(t)
	defer pool.Close()
	ctx := context.Background()
	a := New(pool)

	email := "pair-smoke-" + uuid.NewString() + "@test.local"
	var userID, bookID, accA, accB, instID uuid.UUID
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, password_hash) VALUES ($1,'x') RETURNING id`, email).Scan(&userID); err != nil {
		t.Fatalf("user: %v", err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `DELETE FROM users WHERE id=$1`, userID)
	})
	if err := pool.QueryRow(ctx, `INSERT INTO books (user_id, name, opening_date, opening_locked) VALUES ($1,$2,'2026-01-01',true) RETURNING id`, userID, "pair-smoke").Scan(&bookID); err != nil {
		t.Fatalf("book: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO accounts (book_id, name, type) VALUES ($1,'交易所A','exchange') RETURNING id`, bookID).Scan(&accA); err != nil {
		t.Fatalf("accA: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO accounts (book_id, name, type) VALUES ($1,'交易所B','exchange') RETURNING id`, bookID).Scan(&accB); err != nil {
		t.Fatalf("accB: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO instruments (book_id, symbol, name, asset_class, quote_currency) VALUES ($1,'BTC','Bitcoin','crypto','USD') RETURNING id`, bookID).Scan(&instID); err != nil {
		t.Fatalf("inst: %v", err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO positions (book_id, account_id, instrument_id, qty, cost_twd) VALUES ($1,$2,$3,10,100000)`, bookID, accA, instID); err != nil {
		t.Fatalf("pos: %v", err)
	}

	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	outID, inID, err := a.applyTransfer(ctx, tx, bookID, "2026-08-30", accA, accB, instID, decimal.RequireFromString("3"), 0, "smoke pair", decimal.NewFromInt(32))
	if err != nil {
		_ = tx.Rollback(ctx)
		t.Fatalf("transfer: %v", err)
	}
	if err := tx.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	if outID == uuid.Nil || inID == uuid.Nil {
		t.Fatal("expected both trade ids")
	}

	var outPair, inPair *uuid.UUID
	_ = pool.QueryRow(ctx, `SELECT pair_id FROM trades WHERE id=$1`, outID).Scan(&outPair)
	_ = pool.QueryRow(ctx, `SELECT pair_id FROM trades WHERE id=$1`, inID).Scan(&inPair)
	if outPair == nil || *outPair != inID {
		t.Fatalf("before export out.pair_id=%v want %s", outPair, inID)
	}
	if inPair == nil || *inPair != outID {
		t.Fatalf("before export in.pair_id=%v want %s", inPair, outID)
	}

	payload, err := a.exportBook(ctx, bookID)
	if err != nil {
		t.Fatalf("export: %v", err)
	}
	rawBytes, err := json.Marshal(payload)
	if err != nil {
		t.Fatal(err)
	}
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(rawBytes, &raw); err != nil {
		t.Fatal(err)
	}

	if err := a.importBook(ctx, bookID, raw); err != nil {
		t.Fatalf("import: %v", err)
	}

	rows, err := pool.Query(ctx, `SELECT id, side::text, pair_id FROM trades WHERE book_id=$1 AND side IN ('transfer_out','transfer_in') AND deleted_at IS NULL`, bookID)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	type row struct {
		id   uuid.UUID
		side string
		pair *uuid.UUID
	}
	var got []row
	for rows.Next() {
		var r row
		if err := rows.Scan(&r.id, &r.side, &r.pair); err != nil {
			t.Fatal(err)
		}
		got = append(got, r)
	}
	if len(got) != 2 {
		t.Fatalf("want 2 paired trades, got %d", len(got))
	}
	byID := map[uuid.UUID]row{}
	for _, r := range got {
		if r.pair == nil {
			t.Fatalf("trade %s (%s) pair_id is null after import", r.id, r.side)
		}
		byID[r.id] = r
	}
	for _, r := range got {
		sib, ok := byID[*r.pair]
		if !ok {
			t.Fatalf("trade %s pair_id %s does not point at the sibling in this book (IDs remapped? missing)", r.id, *r.pair)
		}
		want := "transfer_in"
		if r.side == "transfer_in" {
			want = "transfer_out"
		}
		if sib.side != want {
			t.Fatalf("pair mismatch: %s linked to %s", r.side, sib.side)
		}
		if sib.pair == nil || *sib.pair != r.id {
			t.Fatalf("pair_id not reciprocal: %s -> %s, sibling -> %v", r.id, *r.pair, sib.pair)
		}
	}
}
