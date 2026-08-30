package app

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"github.com/google/uuid"
)

func (a *App) handleBooksList(w http.ResponseWriter, r *http.Request) {
	rows, err := a.pool.Query(r.Context(),
		`SELECT `+bookCols+` FROM books WHERE user_id=$1 ORDER BY archived_at NULLS FIRST, created_at`, userID(r))
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer rows.Close()
	out := []Book{}
	for rows.Next() {
		b, err := scanBook(rows)
		if err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		out = append(out, b)
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *App) handleBooksCreate(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Name string `json:"name"`
	}
	if err := decodeJSON(r, &body); err != nil {
		writeErr(w, http.StatusBadRequest, "格式不對")
		return
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		name = "生活"
	}
	uid := userID(r)
	tx, err := a.pool.Begin(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer tx.Rollback(r.Context())
	var id uuid.UUID
	err = tx.QueryRow(r.Context(),
		`INSERT INTO books (user_id, name) VALUES ($1,$2) RETURNING id`, uid, name,
	).Scan(&id)
	if isUniqueViolation(err) {
		writeErr(w, http.StatusConflict, "已有同名帳本")
		return
	}
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	if err := a.seedCategories(r.Context(), tx, id); err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	_, _ = tx.Exec(r.Context(), `UPDATE users SET last_book_id=$1 WHERE id=$2 AND last_book_id IS NULL`, id, uid)
	if err := tx.Commit(r.Context()); err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	b, _ := a.loadBook(r.Context(), uid, id)
	writeJSON(w, http.StatusCreated, b)
}

func (a *App) handleBooksPatch(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	if rejectArchivedWrite(w, b) {
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
	name := b.Name
	if body.Name != nil {
		name = strings.TrimSpace(*body.Name)
		if name == "" {
			writeErr(w, http.StatusBadRequest, "名稱不能空")
			return
		}
	}
	tag, err := a.pool.Exec(r.Context(),
		`UPDATE books SET name=$1, version=version+1 WHERE id=$2 AND user_id=$3 AND version=$4`,
		name, b.ID, userID(r), body.Version)
	if err != nil {
		if isUniqueViolation(err) {
			writeErr(w, http.StatusConflict, "已有同名帳本")
			return
		}
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusConflict, "資料已被更新，請重抓再送")
		return
	}
	nb, _ := a.loadBook(r.Context(), userID(r), b.ID)
	writeJSON(w, http.StatusOK, nb)
}

func (a *App) handleBooksArchive(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	_, err := a.pool.Exec(r.Context(),
		`UPDATE books SET archived_at=now(), version=version+1 WHERE id=$1 AND user_id=$2 AND archived_at IS NULL`,
		b.ID, userID(r))
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	nb, _ := a.loadBook(r.Context(), userID(r), b.ID)
	writeJSON(w, http.StatusOK, nb)
}

func (a *App) handleBooksUnarchive(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	_, err := a.pool.Exec(r.Context(),
		`UPDATE books SET archived_at=NULL, version=version+1 WHERE id=$1 AND user_id=$2`,
		b.ID, userID(r))
	if isUniqueViolation(err) {
		writeErr(w, http.StatusConflict, "已有同名未封存帳本")
		return
	}
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	nb, _ := a.loadBook(r.Context(), userID(r), b.ID)
	writeJSON(w, http.StatusOK, nb)
}

func (a *App) handleBooksDelete(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	var nAcc, nEnt, nTr int
	_ = a.pool.QueryRow(r.Context(), `SELECT COUNT(*) FROM accounts WHERE book_id=$1`, b.ID).Scan(&nAcc)
	_ = a.pool.QueryRow(r.Context(), `SELECT COUNT(*) FROM entries WHERE book_id=$1 AND deleted_at IS NULL`, b.ID).Scan(&nEnt)
	_ = a.pool.QueryRow(r.Context(), `SELECT COUNT(*) FROM trades WHERE book_id=$1 AND deleted_at IS NULL`, b.ID).Scan(&nTr)
	if nAcc+nEnt+nTr > 0 {
		writeErr(w, http.StatusConflict, "帳本還有帳戶或分錄，只能封存")
		return
	}
	_, err := a.pool.Exec(r.Context(), `DELETE FROM books WHERE id=$1 AND user_id=$2`, b.ID, userID(r))
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *App) handleBooksSelect(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	if b.ArchivedAt != nil {
		writeErr(w, http.StatusConflict, "帳本已封存，請先取消封存")
		return
	}
	_, err := a.pool.Exec(r.Context(), `UPDATE users SET last_book_id=$1 WHERE id=$2`, b.ID, userID(r))
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	writeJSON(w, http.StatusOK, b)
}

func (a *App) handleBooksExport(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	payload, err := a.exportBook(r.Context(), b.ID)
	if err != nil {
		log.Printf("export: %v", err)
		writeErr(w, http.StatusInternalServerError, "匯出失敗")
		return
	}
	writeJSON(w, http.StatusOK, payload)
}

func (a *App) handleBooksImport(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	if rejectArchivedWrite(w, b) {
		return
	}
	var payload map[string]json.RawMessage
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeErr(w, http.StatusBadRequest, "JSON 格式不對")
		return
	}
	if err := a.importBook(r.Context(), b.ID, payload); err != nil {
		log.Printf("import: %v", err)
		writeErr(w, http.StatusBadRequest, "還原失敗："+err.Error())
		return
	}
	nb, _ := a.loadBook(r.Context(), userID(r), b.ID)
	writeJSON(w, http.StatusOK, nb)
}
