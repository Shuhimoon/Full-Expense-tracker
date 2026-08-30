package app

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ctxKey int

const (
	ctxUser ctxKey = iota
	ctxReqID
)

var taipei *time.Location

func init() {
	var err error
	taipei, err = time.LoadLocation("Asia/Taipei")
	if err != nil {
		taipei = time.FixedZone("Asia/Taipei", 8*3600)
	}
}

type App struct {
	pool        *pgxpool.Pool
	quoteMu     sync.Mutex
	lastAttempt map[string]time.Time
	lastFail    map[string][]string
}

func New(pool *pgxpool.Pool) *App {
	return &App{
		pool:        pool,
		lastAttempt: map[string]time.Time{},
		lastFail:    map[string][]string{},
	}
}

func (a *App) Router() http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.Recoverer)
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(a.cors)
	r.Use(a.timeout)

	r.Get("/api/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	})

	r.Post("/api/register", a.handleRegister)
	r.Post("/api/login", a.handleLogin)
	r.Post("/api/logout", a.handleLogout)

	r.Group(func(r chi.Router) {
		r.Use(a.requireSession)
		r.Use(a.idempotency)
		r.Get("/api/me", a.handleMe)
		r.Post("/api/password", a.handlePassword)

		r.Get("/api/books", a.handleBooksList)
		r.Post("/api/books", a.handleBooksCreate)
		r.Patch("/api/books/{id}", a.handleBooksPatch)
		r.Post("/api/books/{id}/archive", a.handleBooksArchive)
		r.Post("/api/books/{id}/unarchive", a.handleBooksUnarchive)
		r.Delete("/api/books/{id}", a.handleBooksDelete)
		r.Post("/api/books/{id}/select", a.handleBooksSelect)
		r.Get("/api/books/{id}/export", a.handleBooksExport)
		r.Post("/api/books/{id}/import", a.handleBooksImport)

		r.Get("/api/books/{id}/opening", a.handleOpeningGet)
		r.Put("/api/books/{id}/opening", a.handleOpeningPut)
		r.Post("/api/books/{id}/opening/lock", a.handleOpeningLock)

		r.Get("/api/accounts", a.handleAccountsList)
		r.Post("/api/accounts", a.handleAccountsCreate)
		r.Patch("/api/accounts/{id}", a.handleAccountsPatch)
		r.Post("/api/accounts/{id}/archive", a.handleAccountsArchive)
		r.Delete("/api/accounts/{id}", a.handleAccountsDelete)

		r.Get("/api/categories", a.handleCategoriesList)
		r.Post("/api/categories", a.handleCategoriesCreate)
		r.Patch("/api/categories/{id}", a.handleCategoriesPatch)
		r.Post("/api/categories/{id}/archive", a.handleCategoriesArchive)
		r.Delete("/api/categories/{id}", a.handleCategoriesDelete)

		r.Get("/api/entries", a.handleEntriesList)
		r.Post("/api/entries", a.handleEntriesCreate)
		r.Patch("/api/entries/{id}", a.handleEntriesPatch)
		r.Delete("/api/entries/{id}", a.handleEntriesDelete)

		r.Get("/api/stats/summary", a.handleStatsSummary)
		r.Get("/api/stats/daily", a.handleStatsDaily)
		r.Get("/api/stats/expense-by-category", a.handleStatsByCat)

		r.Get("/api/instruments", a.handleInstrumentsList)
		r.Post("/api/instruments", a.handleInstrumentsCreate)

		r.Get("/api/trades", a.handleTradesList)
		r.Post("/api/trades", a.handleTradesCreate)
		r.Delete("/api/trades/{id}", a.handleTradesDelete)

		r.Get("/api/positions", a.handlePositionsList)
		r.Get("/api/positions/{id}", a.handlePositionsGet)

		r.Post("/api/quotes/refresh", a.handleQuotesRefresh)
		r.Post("/api/quotes", a.handleQuotesManual)
		r.Get("/api/quotes", a.handleQuotesList)
		r.Get("/api/fx", a.handleFxGet)
		r.Post("/api/fx", a.handleFxSet)
	})
	return r
}

func (a *App) cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Idempotency-Key")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (a *App) timeout(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 25*time.Second)
		defer cancel()
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (a *App) requireSession(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := r.Cookie("sid")
		if err != nil || c.Value == "" {
			writeErr(w, http.StatusUnauthorized, "請先登入")
			return
		}
		id, err := uuid.Parse(c.Value)
		if err != nil {
			writeErr(w, http.StatusUnauthorized, "請先登入")
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		var userID uuid.UUID
		var exp time.Time
		err = a.pool.QueryRow(ctx, `SELECT user_id, expires_at FROM sessions WHERE id=$1`, id).Scan(&userID, &exp)
		if err != nil || time.Now().After(exp) {
			writeErr(w, http.StatusUnauthorized, "請先登入")
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), ctxUser, userID)))
	})
}

type capture struct {
	http.ResponseWriter
	status int
	buf    bytes.Buffer
}

func (c *capture) WriteHeader(code int) {
	c.status = code
	c.ResponseWriter.WriteHeader(code)
}

func (c *capture) Write(b []byte) (int, error) {
	c.buf.Write(b)
	return c.ResponseWriter.Write(b)
}

func (a *App) idempotency(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost && r.Method != http.MethodPut && r.Method != http.MethodPatch {
			next.ServeHTTP(w, r)
			return
		}
		raw := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
		if raw == "" {
			next.ServeHTTP(w, r)
			return
		}
		key, err := uuid.Parse(raw)
		if err != nil {
			writeErr(w, http.StatusBadRequest, "Idempotency-Key 必須是 UUID")
			return
		}
		uid := userID(r)
		var status int
		var body []byte
		err = a.pool.QueryRow(r.Context(),
			`SELECT response_status, response_body FROM idempotency_keys WHERE key=$1 AND user_id=$2`,
			key, uid,
		).Scan(&status, &body)
		if err == nil {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(status)
			_, _ = w.Write(body)
			return
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		cap := &capture{ResponseWriter: w, status: 200}
		next.ServeHTTP(cap, r)
		_, _ = a.pool.Exec(r.Context(),
			`INSERT INTO idempotency_keys (key, user_id, method, path, response_status, response_body)
			 VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING`,
			key, uid, r.Method, r.URL.Path, cap.status, cap.buf.Bytes(),
		)
	})
}

func userID(r *http.Request) uuid.UUID {
	v, _ := r.Context().Value(ctxUser).(uuid.UUID)
	return v
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if v == nil {
		return
	}
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func decodeJSON(r *http.Request, v any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	return dec.Decode(v)
}

func setSessionCookie(w http.ResponseWriter, sid uuid.UUID, exp time.Time) {
	http.SetCookie(w, &http.Cookie{
		Name:     "sid",
		Value:    sid.String(),
		Path:     "/",
		Expires:  exp,
		MaxAge:   int(time.Until(exp).Seconds()),
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Secure:   false,
	})
}

func clearSessionCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:     "sid",
		Value:    "",
		Path:     "/",
		MaxAge:   -1,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Secure:   false,
	})
}

type Book struct {
	ID            uuid.UUID  `json:"id"`
	UserID        uuid.UUID  `json:"user_id"`
	Name          string     `json:"name"`
	ArchivedAt    *time.Time `json:"archived_at"`
	BaseCurrency  string     `json:"base_currency"`
	OpeningDate   *string    `json:"opening_date"`
	OpeningLocked bool       `json:"opening_locked"`
	Timezone      string     `json:"timezone"`
	CostMethod    string     `json:"cost_method"`
	Version       int        `json:"version"`
	CreatedAt     time.Time  `json:"created_at"`
}

func scanBook(row pgx.Row) (Book, error) {
	var b Book
	var od *time.Time
	err := row.Scan(&b.ID, &b.UserID, &b.Name, &b.ArchivedAt, &b.BaseCurrency, &od, &b.OpeningLocked, &b.Timezone, &b.CostMethod, &b.Version, &b.CreatedAt)
	if od != nil {
		s := od.Format("2006-01-02")
		b.OpeningDate = &s
	}
	return b, err
}

const bookCols = `id, user_id, name, archived_at, base_currency, opening_date, opening_locked, timezone, cost_method, version, created_at`

func (a *App) loadBook(ctx context.Context, userID, bookID uuid.UUID) (Book, error) {
	b, err := scanBook(a.pool.QueryRow(ctx, `SELECT `+bookCols+` FROM books WHERE id=$1 AND user_id=$2`, bookID, userID))
	if err != nil {
		return Book{}, err
	}
	return b, nil
}

func (a *App) bookFromQuery(w http.ResponseWriter, r *http.Request) (Book, bool) {
	raw := r.URL.Query().Get("book_id")
	if raw == "" {
		raw = chi.URLParam(r, "id")
	}
	if raw == "" {
		writeErr(w, http.StatusBadRequest, "缺少 book_id")
		return Book{}, false
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		writeErr(w, http.StatusNotFound, "找不到帳本")
		return Book{}, false
	}
	b, err := a.loadBook(r.Context(), userID(r), id)
	if errors.Is(err, pgx.ErrNoRows) {
		writeErr(w, http.StatusNotFound, "找不到帳本")
		return Book{}, false
	}
	if err != nil {
		log.Printf("load book: %v", err)
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return Book{}, false
	}
	return b, true
}

func rejectArchivedWrite(w http.ResponseWriter, b Book) bool {
	if b.ArchivedAt != nil {
		writeErr(w, http.StatusConflict, "帳本已封存，不能寫入")
		return true
	}
	return false
}

func parseDate(s string) (time.Time, error) {
	return time.ParseInLocation("2006-01-02", s, taipei)
}

func dateStr(t time.Time) string {
	return t.In(taipei).Format("2006-01-02")
}

func todayStr() string {
	return time.Now().In(taipei).Format("2006-01-02")
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

func ptrTimeDate(t *time.Time) *string {
	if t == nil {
		return nil
	}
	s := t.Format("2006-01-02")
	return &s
}

var incomeSeed = []string{"薪資", "獎金", "股利", "利息", "其他"}
var expenseSeed = []string{"餐飲", "交通", "居住", "日用", "訂閱", "醫療", "娛樂", "學習", "人情", "投資費用", "其他"}

func (a *App) seedCategories(ctx context.Context, tx pgx.Tx, bookID uuid.UUID) error {
	sort := 0
	for _, n := range incomeSeed {
		sort++
		if _, err := tx.Exec(ctx, `INSERT INTO categories (book_id, name, kind, is_system, sort) VALUES ($1,$2,'income',true,$3)`, bookID, n, sort); err != nil {
			return err
		}
	}
	sort = 0
	for _, n := range expenseSeed {
		sort++
		if _, err := tx.Exec(ctx, `INSERT INTO categories (book_id, name, kind, is_system, sort) VALUES ($1,$2,'expense',true,$3)`, bookID, n, sort); err != nil {
			return err
		}
	}
	return nil
}

func roundTWD(f float64) int64 {
	if f >= 0 {
		return int64(f + 0.5)
	}
	return int64(f - 0.5)
}
