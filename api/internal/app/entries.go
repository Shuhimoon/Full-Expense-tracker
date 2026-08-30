package app

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type EntryOut struct {
	ID           uuid.UUID  `json:"id"`
	BookID       uuid.UUID  `json:"book_id"`
	Date         string     `json:"date"`
	Type         string     `json:"type"`
	Amount       int64      `json:"amount"`
	AccountID    uuid.UUID  `json:"account_id"`
	ToAccountID  *uuid.UUID `json:"to_account_id"`
	CategoryID   *uuid.UUID `json:"category_id"`
	Note         string     `json:"note"`
	InstrumentID *uuid.UUID `json:"instrument_id"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
	Version      int        `json:"version"`
}

func scanEntry(row pgx.Row) (EntryOut, error) {
	var e EntryOut
	var d time.Time
	err := row.Scan(&e.ID, &e.BookID, &d, &e.Type, &e.Amount, &e.AccountID, &e.ToAccountID, &e.CategoryID, &e.Note, &e.InstrumentID, &e.CreatedAt, &e.UpdatedAt, &e.Version)
	e.Date = d.Format("2006-01-02")
	return e, err
}

const entryCols = `id, book_id, date, type::text, amount, account_id, to_account_id, category_id, note, instrument_id, created_at, updated_at, version`

func (a *App) handleEntriesList(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	q := r.URL.Query()
	date := q.Get("date")
	from := q.Get("from")
	to := q.Get("to")
	sql := `SELECT ` + entryCols + ` FROM entries WHERE book_id=$1 AND deleted_at IS NULL`
	args := []any{b.ID}
	n := 2
	if date != "" {
		sql += ` AND date=$2`
		args = append(args, date)
		n = 3
	} else {
		if from != "" {
			sql += ` AND date>=$` + itoa(n)
			args = append(args, from)
			n++
		}
		if to != "" {
			sql += ` AND date<=$` + itoa(n)
			args = append(args, to)
			n++
		}
	}
	if acc := q.Get("account_id"); acc != "" {
		sql += ` AND (account_id=$` + itoa(n) + ` OR to_account_id=$` + itoa(n) + `)`
		args = append(args, acc)
		n++
	}
	if cat := q.Get("category_id"); cat != "" {
		sql += ` AND category_id=$` + itoa(n)
		args = append(args, cat)
	}
	sql += ` ORDER BY date, created_at`
	rows, err := a.pool.Query(r.Context(), sql, args...)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer rows.Close()
	out := []EntryOut{}
	for rows.Next() {
		e, err := scanEntry(rows)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		out = append(out, e)
	}
	writeJSON(w, http.StatusOK, out)
}

func itoa(n int) string {
	if n < 10 {
		return string(rune('0' + n))
	}
	return string(rune('0'+n/10)) + string(rune('0'+n%10))
}

func (a *App) handleEntriesCreate(w http.ResponseWriter, r *http.Request) {
	var body struct {
		BookID       string     `json:"book_id"`
		Type         string     `json:"type"`
		Amount       int64      `json:"amount"`
		AccountID    uuid.UUID  `json:"account_id"`
		ToAccountID  *uuid.UUID `json:"to_account_id"`
		CategoryID   *uuid.UUID `json:"category_id"`
		Date         string     `json:"date"`
		Note         string     `json:"note"`
		InstrumentID *uuid.UUID `json:"instrument_id"`
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
		writeErr(w, http.StatusConflict, "請先鎖定開帳再記帳")
		return
	}
	if body.Type == "opening_balance" {
		writeErr(w, http.StatusBadRequest, "開帳分錄只能由系統寫入")
		return
	}
	if body.Amount <= 0 {
		writeErr(w, http.StatusBadRequest, "金額必須大於 0")
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
	if err := a.validateEntry(r, b.ID, body.Type, body.AccountID, body.ToAccountID, body.CategoryID); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	var e EntryOut
	var d time.Time
	err = a.pool.QueryRow(r.Context(),
		`INSERT INTO entries (book_id, date, type, amount, account_id, to_account_id, category_id, note, instrument_id)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
		 RETURNING `+entryCols,
		b.ID, body.Date, body.Type, body.Amount, body.AccountID, body.ToAccountID, body.CategoryID, body.Note, body.InstrumentID,
	).Scan(&e.ID, &e.BookID, &d, &e.Type, &e.Amount, &e.AccountID, &e.ToAccountID, &e.CategoryID, &e.Note, &e.InstrumentID, &e.CreatedAt, &e.UpdatedAt, &e.Version)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	e.Date = d.Format("2006-01-02")
	writeJSON(w, http.StatusCreated, e)
}

func (a *App) validateEntry(r *http.Request, bookID uuid.UUID, typ string, acc uuid.UUID, to *uuid.UUID, cat *uuid.UUID) error {
	var accBook uuid.UUID
	var accType string
	if err := a.pool.QueryRow(r.Context(), `SELECT book_id, type::text FROM accounts WHERE id=$1`, acc).Scan(&accBook, &accType); err != nil {
		return errString("帳戶不存在")
	}
	if accBook != bookID {
		return errString("帳戶不屬於這本帳")
	}
	switch typ {
	case "expense", "income":
		if cat == nil {
			return errString("請選分類")
		}
		var ck string
		var cbook uuid.UUID
		if err := a.pool.QueryRow(r.Context(), `SELECT book_id, kind::text FROM categories WHERE id=$1`, *cat).Scan(&cbook, &ck); err != nil {
			return errString("分類不存在")
		}
		if cbook != bookID {
			return errString("分類不屬於這本帳")
		}
		if ck != typ {
			return errString("分類種類和收支不符")
		}
		if to != nil {
			return errString("收支不要填轉入帳戶")
		}
	case "transfer":
		if to == nil {
			return errString("轉帳請選轉入帳戶")
		}
		if *to == acc {
			return errString("不能轉給自己")
		}
		var toBook uuid.UUID
		var toType string
		if err := a.pool.QueryRow(r.Context(), `SELECT book_id, type::text FROM accounts WHERE id=$1`, *to).Scan(&toBook, &toType); err != nil {
			return errString("轉入帳戶不存在")
		}
		if toBook != bookID {
			return errString("轉入帳戶不屬於這本帳")
		}
		if accType == "credit_card" && toType == "credit_card" {
			return errString("兩張信用卡之間不能轉帳")
		}
		if cat != nil {
			return errString("轉帳不要填分類")
		}
	default:
		return errString("類型不對")
	}
	return nil
}

type errString string

func (e errString) Error() string { return string(e) }

func (a *App) handleEntriesPatch(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到分錄")
		return
	}
	var body struct {
		Amount       *int64     `json:"amount"`
		AccountID    *uuid.UUID `json:"account_id"`
		ToAccountID  *uuid.UUID `json:"to_account_id"`
		CategoryID   *uuid.UUID `json:"category_id"`
		Date         *string    `json:"date"`
		Note         *string    `json:"note"`
		InstrumentID *uuid.UUID `json:"instrument_id"`
		Version      int        `json:"version"`
	}
	if err := decodeJSON(r, &body); err != nil {
		writeErr(w, http.StatusBadRequest, "格式不對")
		return
	}
	e, err := scanEntry(a.pool.QueryRow(r.Context(), `SELECT `+entryCols+` FROM entries WHERE id=$1 AND deleted_at IS NULL`, id))
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到分錄")
		return
	}
	b, err := a.loadBook(r.Context(), userID(r), e.BookID)
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到帳本")
		return
	}
	if rejectArchivedWrite(w, b) {
		return
	}
	if e.Type == "opening_balance" {
		writeErr(w, http.StatusConflict, "開帳分錄不能改")
		return
	}
	if body.Amount != nil {
		if *body.Amount <= 0 {
			writeErr(w, http.StatusBadRequest, "金額必須大於 0")
			return
		}
		e.Amount = *body.Amount
	}
	if body.AccountID != nil {
		e.AccountID = *body.AccountID
	}
	if body.Date != nil {
		if _, err := parseDate(*body.Date); err != nil {
			writeErr(w, http.StatusBadRequest, "日期格式不對")
			return
		}
		if b.OpeningDate != nil && *body.Date < *b.OpeningDate {
			writeErr(w, http.StatusBadRequest, "不能記開帳日之前的帳")
			return
		}
		e.Date = *body.Date
	}
	if body.Note != nil {
		e.Note = *body.Note
	}
	if body.ToAccountID != nil {
		e.ToAccountID = body.ToAccountID
	}
	if body.CategoryID != nil {
		e.CategoryID = body.CategoryID
	}
	if body.InstrumentID != nil {
		e.InstrumentID = body.InstrumentID
	}
	if err := a.validateEntry(r, b.ID, e.Type, e.AccountID, e.ToAccountID, e.CategoryID); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	tag, err := a.pool.Exec(r.Context(),
		`UPDATE entries SET amount=$1, account_id=$2, to_account_id=$3, category_id=$4, date=$5, note=$6, instrument_id=$7, updated_at=now(), version=version+1
		 WHERE id=$8 AND version=$9 AND deleted_at IS NULL`,
		e.Amount, e.AccountID, e.ToAccountID, e.CategoryID, e.Date, e.Note, e.InstrumentID, id, body.Version)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusConflict, "資料已被更新，請重抓再送")
		return
	}
	ne, _ := scanEntry(a.pool.QueryRow(r.Context(), `SELECT `+entryCols+` FROM entries WHERE id=$1`, id))
	writeJSON(w, http.StatusOK, ne)
}

func (a *App) handleEntriesDelete(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到分錄")
		return
	}
	var body struct {
		Version int `json:"version"`
	}
	_ = decodeJSON(r, &body)
	if v := r.URL.Query().Get("version"); v != "" && body.Version == 0 {
		body.Version = atoi(v)
	}
	e, err := scanEntry(a.pool.QueryRow(r.Context(), `SELECT `+entryCols+` FROM entries WHERE id=$1 AND deleted_at IS NULL`, id))
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到分錄")
		return
	}
	b, err := a.loadBook(r.Context(), userID(r), e.BookID)
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到帳本")
		return
	}
	if rejectArchivedWrite(w, b) {
		return
	}
	if e.Type == "opening_balance" {
		writeErr(w, http.StatusConflict, "開帳分錄不能刪")
		return
	}
	tag, err := a.pool.Exec(r.Context(),
		`UPDATE entries SET deleted_at=now(), version=version+1 WHERE id=$1 AND version=$2 AND deleted_at IS NULL`,
		id, body.Version)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusConflict, "資料已被更新，請重抓再送")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func atoi(s string) int {
	n := 0
	for _, c := range s {
		if c < '0' || c > '9' {
			break
		}
		n = n*10 + int(c-'0')
	}
	return n
}
