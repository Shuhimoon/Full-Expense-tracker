package app

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/shopspring/decimal"
)

type AccountOut struct {
	ID          uuid.UUID  `json:"id"`
	BookID      uuid.UUID  `json:"book_id"`
	Name        string     `json:"name"`
	Type        string     `json:"type"`
	ArchivedAt  *time.Time `json:"archived_at"`
	CreatedAt   time.Time  `json:"created_at"`
	Version     int        `json:"version"`
	CashBalance int64      `json:"cash_balance"`
	PositionMV  *int64     `json:"position_mv,omitempty"`
}

func (a *App) accountsWithBalance(ctx context.Context, bookID uuid.UUID) ([]AccountOut, error) {
	rows, err := a.pool.Query(ctx, `
		SELECT a.id, a.book_id, a.name, a.type::text, a.archived_at, a.created_at, a.version
		FROM accounts a WHERE a.book_id=$1 ORDER BY a.type, a.created_at`, bookID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []AccountOut
	for rows.Next() {
		var ac AccountOut
		if err := rows.Scan(&ac.ID, &ac.BookID, &ac.Name, &ac.Type, &ac.ArchivedAt, &ac.CreatedAt, &ac.Version); err != nil {
			return nil, err
		}
		list = append(list, ac)
	}
	if list == nil {
		list = []AccountOut{}
	}
	for i := range list {
		bal, err := a.accountCash(ctx, list[i].ID)
		if err != nil {
			return nil, err
		}
		list[i].CashBalance = bal
		if list[i].Type == "broker" || list[i].Type == "exchange" {
			mv, err := a.accountPositionMV(ctx, bookID, list[i].ID)
			if err == nil {
				list[i].PositionMV = &mv
			}
		}
	}
	return list, nil
}

func (a *App) accountCash(ctx context.Context, accountID uuid.UUID) (int64, error) {
	var entryBal int64
	err := a.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(
			CASE
				WHEN type IN ('opening_balance','income') AND account_id=$1 THEN amount
				WHEN type='expense' AND account_id=$1 THEN -amount
				WHEN type='transfer' AND account_id=$1 THEN -amount
				WHEN type='transfer' AND to_account_id=$1 THEN amount
				ELSE 0
			END
		),0) FROM entries WHERE deleted_at IS NULL AND (account_id=$1 OR to_account_id=$1)`, accountID).Scan(&entryBal)
	if err != nil {
		return 0, err
	}
	var tradeBal int64
	err = a.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(
			CASE
				WHEN side='buy' THEN -proceeds_or_cost_twd
				WHEN side='sell' THEN proceeds_or_cost_twd
				ELSE 0
			END
		),0) FROM trades WHERE deleted_at IS NULL AND account_id=$1`, accountID).Scan(&tradeBal)
	if err != nil {
		return 0, err
	}
	return entryBal + tradeBal, nil
}

func (a *App) accountPositionMV(ctx context.Context, bookID, accountID uuid.UUID) (int64, error) {
	rows, err := a.pool.Query(ctx, `
		SELECT p.qty, p.cost_twd, i.quote_currency, q.price, q.ccy, f.usd_twd
		FROM positions p
		JOIN instruments i ON i.id=p.instrument_id
		LEFT JOIN quotes q ON q.instrument_id=p.instrument_id
		LEFT JOIN fx_rates f ON f.book_id=p.book_id
		WHERE p.account_id=$1 AND p.qty>0`, accountID)
	if err != nil {
		return 0, err
	}
	defer rows.Close()
	var total decimal.Decimal
	for rows.Next() {
		var qty, cost decimal.Decimal
		var qccy string
		var price *decimal.Decimal
		var pccy *string
		var fx *decimal.Decimal
		if err := rows.Scan(&qty, &cost, &qccy, &price, &pccy, &fx); err != nil {
			return 0, err
		}
		if price != nil {
			px := *price
			if pccy != nil && *pccy == "USD" {
				mult := decimal.NewFromInt(32)
				if fx != nil {
					mult = *fx
				}
				px = px.Mul(mult)
			}
			total = total.Add(qty.Mul(px))
		} else {
			total = total.Add(cost)
		}
	}
	return total.Round(0).IntPart(), nil
}

func (a *App) handleAccountsList(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	list, err := a.accountsWithBalance(r.Context(), b.ID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	writeJSON(w, http.StatusOK, list)
}

func (a *App) handleAccountsCreate(w http.ResponseWriter, r *http.Request) {
	var body struct {
		BookID string `json:"book_id"`
		Name   string `json:"name"`
		Type   string `json:"type"`
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
	name := strings.TrimSpace(body.Name)
	if name == "" {
		writeErr(w, http.StatusBadRequest, "請填帳戶名稱")
		return
	}
	switch body.Type {
	case "cash", "bank", "credit_card", "broker", "exchange":
	default:
		writeErr(w, http.StatusBadRequest, "帳戶類型不對")
		return
	}
	var id uuid.UUID
	err = a.pool.QueryRow(r.Context(),
		`INSERT INTO accounts (book_id, name, type) VALUES ($1,$2,$3) RETURNING id`,
		b.ID, name, body.Type).Scan(&id)
	if isUniqueViolation(err) {
		writeErr(w, http.StatusConflict, "已有同名帳戶")
		return
	}
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	list, _ := a.accountsWithBalance(r.Context(), b.ID)
	for _, ac := range list {
		if ac.ID == id {
			writeJSON(w, http.StatusCreated, ac)
			return
		}
	}
	writeJSON(w, http.StatusCreated, map[string]any{"id": id})
}

func (a *App) handleAccountsPatch(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到帳戶")
		return
	}
	var body struct {
		Name    *string `json:"name"`
		Version int     `json:"version"`
	}
	if err := decodeJSON(r, &body); err != nil {
		writeErr(w, http.StatusBadRequest, "格式不對")
		return
	}
	var bookID uuid.UUID
	var name string
	var ver int
	err = a.pool.QueryRow(r.Context(), `SELECT book_id, name, version FROM accounts WHERE id=$1`, id).Scan(&bookID, &name, &ver)
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到帳戶")
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
	if body.Name != nil {
		name = strings.TrimSpace(*body.Name)
	}
	tag, err := a.pool.Exec(r.Context(),
		`UPDATE accounts SET name=$1, version=version+1 WHERE id=$2 AND version=$3`, name, id, body.Version)
	if isUniqueViolation(err) {
		writeErr(w, http.StatusConflict, "已有同名帳戶")
		return
	}
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusConflict, "資料已被更新，請重抓再送")
		return
	}
	list, _ := a.accountsWithBalance(r.Context(), b.ID)
	for _, ac := range list {
		if ac.ID == id {
			writeJSON(w, http.StatusOK, ac)
			return
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"id": id})
}

func (a *App) handleAccountsArchive(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到帳戶")
		return
	}
	var bookID uuid.UUID
	err = a.pool.QueryRow(r.Context(), `SELECT book_id FROM accounts WHERE id=$1`, id).Scan(&bookID)
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到帳戶")
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
	_, err = a.pool.Exec(r.Context(), `UPDATE accounts SET archived_at=now(), version=version+1 WHERE id=$1`, id)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *App) handleAccountsDelete(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到帳戶")
		return
	}
	var bookID uuid.UUID
	err = a.pool.QueryRow(r.Context(), `SELECT book_id FROM accounts WHERE id=$1`, id).Scan(&bookID)
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到帳戶")
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
	var n int
	_ = a.pool.QueryRow(r.Context(), `SELECT COUNT(*) FROM entries WHERE (account_id=$1 OR to_account_id=$1) AND deleted_at IS NULL`, id).Scan(&n)
	var n2 int
	_ = a.pool.QueryRow(r.Context(), `SELECT COUNT(*) FROM trades WHERE account_id=$1 AND deleted_at IS NULL`, id).Scan(&n2)
	if n+n2 > 0 {
		writeErr(w, http.StatusConflict, "帳戶還有流水，請改封存")
		return
	}
	_, err = a.pool.Exec(r.Context(), `DELETE FROM opening_cash_drafts WHERE account_id=$1`, id)
	_, err = a.pool.Exec(r.Context(), `DELETE FROM accounts WHERE id=$1`, id)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
