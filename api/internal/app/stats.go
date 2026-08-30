package app

import (
	"context"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/shopspring/decimal"
)

func (a *App) handleStatsSummary(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	month := r.URL.Query().Get("month")
	if month == "" {
		month = time.Now().In(taipei).Format("2006-01")
	}
	start := month + "-01"
	t, err := time.ParseInLocation("2006-01-02", start, taipei)
	if err != nil {
		writeErr(w, http.StatusBadRequest, "月份格式不對")
		return
	}
	end := t.AddDate(0, 1, 0).Format("2006-01-02")
	today := todayStr()

	var todayExp, monthExp, monthInc int64
	_ = a.pool.QueryRow(r.Context(),
		`SELECT COALESCE(SUM(amount),0) FROM entries WHERE book_id=$1 AND deleted_at IS NULL AND type='expense' AND date=$2`,
		b.ID, today).Scan(&todayExp)
	_ = a.pool.QueryRow(r.Context(),
		`SELECT COALESCE(SUM(amount),0) FROM entries WHERE book_id=$1 AND deleted_at IS NULL AND type='expense' AND date>=$2 AND date<$3`,
		b.ID, start, end).Scan(&monthExp)
	_ = a.pool.QueryRow(r.Context(),
		`SELECT COALESCE(SUM(amount),0) FROM entries WHERE book_id=$1 AND deleted_at IS NULL AND type='income' AND date>=$2 AND date<$3`,
		b.ID, start, end).Scan(&monthInc)

	cashNet, err := a.cashNetAt(r.Context(), b.ID, today)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	posMV, unreal, asOf, unquoted, err := a.positionMark(r.Context(), b.ID)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	netWorth := cashNet + posMV

	var openingNet int64
	if b.OpeningDate != nil {
		openingNet, _ = a.cashNetAt(r.Context(), b.ID, *b.OpeningDate)
		var openCost int64
		_ = a.pool.QueryRow(r.Context(),
			`SELECT COALESCE(SUM(proceeds_or_cost_twd),0) FROM trades WHERE book_id=$1 AND deleted_at IS NULL AND side='opening'`,
			b.ID).Scan(&openCost)
		openingNet += openCost
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"today_expense":               todayExp,
		"month_expense":               monthExp,
		"month_income":                monthInc,
		"net_worth":                   netWorth,
		"net_worth_change_vs_opening": netWorth - openingNet,
		"cash_net":                    cashNet,
		"position_mv":                 posMV,
		"unrealized":                  unreal,
		"quote_as_of":                 asOf,
		"some_positions_unquoted":     unquoted,
		"today":                       today,
		"month":                       month,
	})
}

func (a *App) cashNetAt(ctx context.Context, bookID uuid.UUID, asOf string) (int64, error) {
	var n int64
	err := a.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(delta),0) FROM (
			SELECT CASE
				WHEN a.type='credit_card' THEN -e.signed
				ELSE e.signed
			END AS delta
			FROM (
				SELECT account_id AS aid,
					CASE
						WHEN type IN ('opening_balance','income') THEN amount
						WHEN type='expense' THEN -amount
						WHEN type='transfer' THEN -amount
						ELSE 0
					END AS signed
				FROM entries
				WHERE book_id=$1 AND deleted_at IS NULL AND date<=$2::date
				UNION ALL
				SELECT to_account_id,
					amount
				FROM entries
				WHERE book_id=$1 AND deleted_at IS NULL AND date<=$2::date AND type='transfer' AND to_account_id IS NOT NULL
			) e
			JOIN accounts a ON a.id=e.aid
			UNION ALL
			SELECT CASE WHEN a.type='credit_card' THEN -t.signed ELSE t.signed END
			FROM (
				SELECT account_id AS aid,
					CASE WHEN side='buy' THEN -proceeds_or_cost_twd
					     WHEN side='sell' THEN proceeds_or_cost_twd
					     ELSE 0 END AS signed
				FROM trades
				WHERE book_id=$1 AND deleted_at IS NULL AND date<=$2::date
			) t
			JOIN accounts a ON a.id=t.aid
		) s`, bookID, asOf).Scan(&n)
	return n, err
}

func (a *App) positionMark(ctx context.Context, bookID uuid.UUID) (mv int64, unreal int64, asOf *time.Time, unquoted bool, err error) {
	rows, err := a.pool.Query(ctx, `
		SELECT p.qty, p.cost_twd, i.quote_currency, q.price, q.ccy, q.as_of, f.usd_twd
		FROM positions p
		JOIN instruments i ON i.id=p.instrument_id
		LEFT JOIN quotes q ON q.instrument_id=i.id
		LEFT JOIN fx_rates f ON f.book_id=p.book_id
		WHERE p.book_id=$1 AND p.qty>0`, bookID)
	if err != nil {
		return
	}
	defer rows.Close()
	var mvD, costD decimal.Decimal
	for rows.Next() {
		var qty, cost decimal.Decimal
		var qccy string
		var price *decimal.Decimal
		var pccy *string
		var qasof *time.Time
		var fx *decimal.Decimal
		if err = rows.Scan(&qty, &cost, &qccy, &price, &pccy, &qasof, &fx); err != nil {
			return
		}
		costD = costD.Add(cost)
		if price == nil {
			unquoted = true
			mvD = mvD.Add(cost)
			continue
		}
		px := *price
		ccy := qccy
		if pccy != nil {
			ccy = *pccy
		}
		if ccy == "USD" {
			mult := decimal.NewFromInt(32)
			if fx != nil {
				mult = *fx
			}
			px = px.Mul(mult)
		}
		mvD = mvD.Add(qty.Mul(px))
		if qasof != nil && (asOf == nil || qasof.After(*asOf)) {
			asOf = qasof
		}
	}
	mv = mvD.Round(0).IntPart()
	unreal = mvD.Sub(costD).Round(0).IntPart()
	return
}

func (a *App) handleStatsDaily(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	from := r.URL.Query().Get("from")
	to := r.URL.Query().Get("to")
	if from == "" || to == "" {
		writeErr(w, http.StatusBadRequest, "需要 from 與 to")
		return
	}
	if _, err := parseDate(from); err != nil {
		writeErr(w, http.StatusBadRequest, "日期格式不對")
		return
	}
	if _, err := parseDate(to); err != nil {
		writeErr(w, http.StatusBadRequest, "日期格式不對")
		return
	}
	if b.OpeningDate != nil && from < *b.OpeningDate {
		writeErr(w, http.StatusBadRequest, "from 不可早於開帳日")
		return
	}
	rows, err := a.pool.Query(r.Context(), `
		WITH days AS (
			SELECT generate_series($2::date, $3::date, interval '1 day')::date AS d
		),
		agg AS (
			SELECT date,
				COALESCE(SUM(amount) FILTER (WHERE type='expense'),0) AS expense,
				COALESCE(SUM(amount) FILTER (WHERE type='income'),0) AS income
			FROM entries
			WHERE book_id=$1 AND deleted_at IS NULL AND date>=$2::date AND date<=$3::date
			GROUP BY date
		)
		SELECT days.d::text, COALESCE(agg.expense,0), COALESCE(agg.income,0)
		FROM days LEFT JOIN agg ON agg.date=days.d
		ORDER BY days.d`, b.ID, from, to)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer rows.Close()
	type rowT struct {
		Date    string `json:"date"`
		Expense int64  `json:"expense"`
		Income  int64  `json:"income"`
		CashNet int64  `json:"cash_net"`
	}
	out := []rowT{}
	for rows.Next() {
		var x rowT
		if err := rows.Scan(&x.Date, &x.Expense, &x.Income); err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		out = append(out, x)
	}
	baseFrom := from
	if b.OpeningDate != nil {
		baseFrom = *b.OpeningDate
	}
	running, err := a.cashNetAt(r.Context(), b.ID, prevDay(baseFrom))
	if err != nil {
		running = 0
	}
	idx := map[string]int64{}
	drows, err := a.pool.Query(r.Context(), `
		SELECT d::text, COALESCE(SUM(delta),0) FROM (
			SELECT e.date AS d,
				CASE WHEN a.type='credit_card' THEN -e.signed ELSE e.signed END AS delta
			FROM (
				SELECT date, account_id AS aid,
					CASE WHEN type IN ('opening_balance','income') THEN amount
					     WHEN type='expense' THEN -amount
					     WHEN type='transfer' THEN -amount ELSE 0 END AS signed
				FROM entries WHERE book_id=$1 AND deleted_at IS NULL AND date>=$2::date AND date<=$3::date
				UNION ALL
				SELECT date, to_account_id,
					amount
				FROM entries WHERE book_id=$1 AND deleted_at IS NULL AND type='transfer' AND to_account_id IS NOT NULL AND date>=$2::date AND date<=$3::date
			) e JOIN accounts a ON a.id=e.aid
			UNION ALL
			SELECT t.date,
				CASE WHEN a.type='credit_card' THEN -t.signed ELSE t.signed END
			FROM (
				SELECT date, account_id AS aid,
					CASE WHEN side='buy' THEN -proceeds_or_cost_twd WHEN side='sell' THEN proceeds_or_cost_twd ELSE 0 END AS signed
				FROM trades WHERE book_id=$1 AND deleted_at IS NULL AND date>=$2::date AND date<=$3::date
			) t JOIN accounts a ON a.id=t.aid
		) s GROUP BY d`, b.ID, from, to)
	if err == nil {
		defer drows.Close()
		for drows.Next() {
			var d string
			var v int64
			if err := drows.Scan(&d, &v); err == nil {
				idx[d] = v
			}
		}
	}
	for i := range out {
		running += idx[out[i].Date]
		out[i].CashNet = running
	}
	writeJSON(w, http.StatusOK, out)
}

func prevDay(s string) string {
	t, err := time.ParseInLocation("2006-01-02", s, taipei)
	if err != nil {
		return s
	}
	return t.AddDate(0, 0, -1).Format("2006-01-02")
}

func (a *App) handleStatsByCat(w http.ResponseWriter, r *http.Request) {
	b, ok := a.bookFromQuery(w, r)
	if !ok {
		return
	}
	month := r.URL.Query().Get("month")
	if month == "" {
		month = time.Now().In(taipei).Format("2006-01")
	}
	start := month + "-01"
	t, err := time.ParseInLocation("2006-01-02", start, taipei)
	if err != nil {
		writeErr(w, http.StatusBadRequest, "月份格式不對")
		return
	}
	end := t.AddDate(0, 1, 0).Format("2006-01-02")
	rows, err := a.pool.Query(r.Context(), `
		SELECT c.id, c.name, COALESCE(SUM(e.amount),0) AS amount
		FROM entries e
		JOIN categories c ON c.id=e.category_id
		WHERE e.book_id=$1 AND e.deleted_at IS NULL AND e.type='expense' AND e.date>=$2 AND e.date<$3
		GROUP BY c.id, c.name
		HAVING SUM(e.amount) > 0
		ORDER BY amount DESC`, b.ID, start, end)
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
		return
	}
	defer rows.Close()
	type rowT struct {
		CategoryID uuid.UUID `json:"category_id"`
		Name       string    `json:"name"`
		Amount     int64     `json:"amount"`
	}
	out := []rowT{}
	for rows.Next() {
		var x rowT
		if err := rows.Scan(&x.CategoryID, &x.Name, &x.Amount); err != nil {
			writeErr(w, http.StatusInternalServerError, "伺服器錯誤")
			return
		}
		out = append(out, x)
	}
	writeJSON(w, http.StatusOK, out)
}
