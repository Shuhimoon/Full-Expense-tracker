package app

import (
	"net/http"
	"strings"
	"time"

	"fulljizhang/internal/auth"

	"github.com/google/uuid"
)

type userJSON struct {
	ID         uuid.UUID  `json:"id"`
	Email      string     `json:"email"`
	LastBookID *uuid.UUID `json:"last_book_id"`
	CreatedAt  time.Time  `json:"created_at"`
}

func (a *App) loadUser(r *http.Request, id uuid.UUID) (userJSON, error) {
	var u userJSON
	err := a.pool.QueryRow(r.Context(),
		`SELECT id, email, last_book_id, created_at FROM users WHERE id=$1`, id,
	).Scan(&u.ID, &u.Email, &u.LastBookID, &u.CreatedAt)
	return u, err
}

func (a *App) createSession(w http.ResponseWriter, r *http.Request, userID uuid.UUID) error {
	sid := uuid.New()
	exp := time.Now().Add(7 * 24 * time.Hour)
	_, err := a.pool.Exec(r.Context(),
		`INSERT INTO sessions (id, user_id, expires_at) VALUES ($1,$2,$3)`, sid, userID, exp)
	if err != nil {
		return err
	}
	setSessionCookie(w, sid, exp)
	return nil
}

func (a *App) handleRegister(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := decodeJSON(r, &body); err != nil {
		writeErr(w, http.StatusBadRequest, "格式不對")
		return
	}
	email := strings.TrimSpace(strings.ToLower(body.Email))
	if email == "" || !strings.Contains(email, "@") {
		writeErr(w, http.StatusBadRequest, "請填 email")
		return
	}
	if len(body.Password) < 8 {
		writeErr(w, http.StatusBadRequest, "密碼至少 8 碼")
		return
	}
	hash, err := auth.Hash(body.Password)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	var id uuid.UUID
	err = a.pool.QueryRow(r.Context(),
		`INSERT INTO users (email, password_hash) VALUES ($1,$2) RETURNING id`,
		email, hash,
	).Scan(&id)
	if isUniqueViolation(err) {
		writeErr(w, http.StatusConflict, "這個 email 已經註冊")
		return
	}
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	if err := a.createSession(w, r, id); err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	u, _ := a.loadUser(r, id)
	writeJSON(w, http.StatusCreated, u)
}

func (a *App) handleLogin(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := decodeJSON(r, &body); err != nil {
		writeErr(w, http.StatusBadRequest, "格式不對")
		return
	}
	email := strings.TrimSpace(strings.ToLower(body.Email))
	var id uuid.UUID
	var hash string
	err := a.pool.QueryRow(r.Context(),
		`SELECT id, password_hash FROM users WHERE email=$1`, email,
	).Scan(&id, &hash)
	if err != nil || !auth.Verify(body.Password, hash) {
		writeErr(w, http.StatusUnauthorized, "帳號或密碼不對")
		return
	}
	if err := a.createSession(w, r, id); err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	u, _ := a.loadUser(r, id)
	writeJSON(w, http.StatusOK, u)
}

func (a *App) handleLogout(w http.ResponseWriter, r *http.Request) {
	if c, err := r.Cookie("sid"); err == nil {
		if id, err := uuid.Parse(c.Value); err == nil {
			_, _ = a.pool.Exec(r.Context(), `DELETE FROM sessions WHERE id=$1`, id)
		}
	}
	clearSessionCookie(w)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *App) handleMe(w http.ResponseWriter, r *http.Request) {
	u, err := a.loadUser(r, userID(r))
	if err != nil {
		writeErr(w, http.StatusUnauthorized, "請先登入")
		return
	}
	writeJSON(w, http.StatusOK, u)
}

func (a *App) handlePassword(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Old string `json:"old"`
		New string `json:"new"`
	}
	if err := decodeJSON(r, &body); err != nil {
		writeErr(w, http.StatusBadRequest, "格式不對")
		return
	}
	if len(body.New) < 8 {
		writeErr(w, http.StatusBadRequest, "密碼至少 8 碼")
		return
	}
	var hash string
	uid := userID(r)
	if err := a.pool.QueryRow(r.Context(), `SELECT password_hash FROM users WHERE id=$1`, uid).Scan(&hash); err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	if !auth.Verify(body.Old, hash) {
		writeErr(w, http.StatusUnauthorized, "帳號或密碼不對")
		return
	}
	nh, err := auth.Hash(body.New)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	_, _ = a.pool.Exec(r.Context(), `UPDATE users SET password_hash=$1 WHERE id=$2`, nh, uid)
	_, _ = a.pool.Exec(r.Context(), `DELETE FROM sessions WHERE user_id=$1`, uid)
	_ = a.createSession(w, r, uid)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
