package app

import (
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type CategoryOut struct {
	ID         uuid.UUID  `json:"id"`
	BookID     uuid.UUID  `json:"book_id"`
	Name       string     `json:"name"`
	Kind       string     `json:"kind"`
	IsSystem   bool       `json:"is_system"`
	ArchivedAt *time.Time `json:"archived_at"`
	Sort       int        `json:"sort"`
	Version    int        `json:"version"`
}

func (a *App) handleCategoriesList(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	rows, err := a.pool.Query(r.Context(),
		`SELECT id, book_id, name, kind::text, is_system, archived_at, sort, version FROM categories WHERE book_id=$1 ORDER BY kind, sort, name`, b.ID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer rows.Close()
	out := []CategoryOut{}
	for rows.Next() {
		var c CategoryOut
		if err := rows.Scan(&c.ID, &c.BookID, &c.Name, &c.Kind, &c.IsSystem, &c.ArchivedAt, &c.Sort, &c.Version); err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		out = append(out, c)
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *App) handleCategoriesCreate(w http.ResponseWriter, r *http.Request) {
	var body struct {
		BookID string `json:"book_id"`
		Name   string `json:"name"`
		Kind   string `json:"kind"`
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
		writeErr(w, http.StatusBadRequest, "請填分類名稱")
		return
	}
	if body.Kind != "income" && body.Kind != "expense" {
		writeErr(w, http.StatusBadRequest, "分類必須是收入或支出")
		return
	}
	var sort int
	_ = a.pool.QueryRow(r.Context(), `SELECT COALESCE(MAX(sort),0)+1 FROM categories WHERE book_id=$1 AND kind=$2`, b.ID, body.Kind).Scan(&sort)
	var c CategoryOut
	err = a.pool.QueryRow(r.Context(),
		`INSERT INTO categories (book_id, name, kind, is_system, sort) VALUES ($1,$2,$3,false,$4)
		 RETURNING id, book_id, name, kind::text, is_system, archived_at, sort, version`,
		b.ID, name, body.Kind, sort,
	).Scan(&c.ID, &c.BookID, &c.Name, &c.Kind, &c.IsSystem, &c.ArchivedAt, &c.Sort, &c.Version)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	writeJSON(w, http.StatusCreated, c)
}

func (a *App) handleCategoriesPatch(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到分類")
		return
	}
	var body struct {
		Name    *string `json:"name"`
		Sort    *int    `json:"sort"`
		Version int     `json:"version"`
	}
	if err := decodeJSON(r, &body); err != nil {
		writeErr(w, http.StatusBadRequest, "格式不對")
		return
	}
	var bookID uuid.UUID
	var name string
	var sort int
	err = a.pool.QueryRow(r.Context(), `SELECT book_id, name, sort FROM categories WHERE id=$1`, id).Scan(&bookID, &name, &sort)
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到分類")
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
	if body.Sort != nil {
		sort = *body.Sort
	}
	tag, err := a.pool.Exec(r.Context(),
		`UPDATE categories SET name=$1, sort=$2, version=version+1 WHERE id=$3 AND version=$4`,
		name, sort, id, body.Version)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusConflict, "資料已被更新，請重抓再送")
		return
	}
	var c CategoryOut
	_ = a.pool.QueryRow(r.Context(),
		`SELECT id, book_id, name, kind::text, is_system, archived_at, sort, version FROM categories WHERE id=$1`, id,
	).Scan(&c.ID, &c.BookID, &c.Name, &c.Kind, &c.IsSystem, &c.ArchivedAt, &c.Sort, &c.Version)
	writeJSON(w, http.StatusOK, c)
}

func (a *App) handleCategoriesArchive(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到分類")
		return
	}
	var bookID uuid.UUID
	err = a.pool.QueryRow(r.Context(), `SELECT book_id FROM categories WHERE id=$1`, id).Scan(&bookID)
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到分類")
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
	_, _ = a.pool.Exec(r.Context(), `UPDATE categories SET archived_at=now(), version=version+1 WHERE id=$1`, id)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *App) handleCategoriesDelete(w http.ResponseWriter, r *http.Request) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到分類")
		return
	}
	var bookID uuid.UUID
	var sys bool
	err = a.pool.QueryRow(r.Context(), `SELECT book_id, is_system FROM categories WHERE id=$1`, id).Scan(&bookID, &sys)
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到分類")
		return
	}
	if sys {
		writeErr(w, http.StatusConflict, "系統分類不能刪，請改封存")
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
	_ = a.pool.QueryRow(r.Context(), `SELECT COUNT(*) FROM entries WHERE category_id=$1 AND deleted_at IS NULL`, id).Scan(&n)
	if n > 0 {
		writeErr(w, http.StatusConflict, "分類還有分錄，請改封存")
		return
	}
	_, err = a.pool.Exec(r.Context(), `DELETE FROM categories WHERE id=$1`, id)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
