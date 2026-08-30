import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { usePullToRefresh } from "../hooks/usePullToRefresh";
import { CartesianGrid, Line, LineChart, Pie, PieChart, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { Ctx } from "../App";
import { api, type Daily, type Summary } from "../api";
import { money, ntd, shortAmt, todayISO, ym } from "../format";
import BookBar from "../components/BookBar";

const PIE_COLORS = ["#9a3412", "#c2410c", "#b45309", "#78716c", "#3f6b4a", "#57534e", "#a8a29e", "#44403c"];

export default function Home({ ctx }: { ctx: Ctx }) {
  const nav = useNavigate();
  const book = ctx.book;
  const [month, setMonth] = useState(ym());
  const [sum, setSum] = useState<Summary | null>(null);
  const [daily, setDaily] = useState<Daily[]>([]);
  const [pie, setPie] = useState<{ category_id: string; name: string; amount: number }[]>([]);
  const [series, setSeries] = useState<"expense" | "income" | "cash_net">("expense");
  const [err, setErr] = useState("");

  async function load(m = month) {
    if (!book) return;
    if (!book.opening_locked) return;
    const [y, mo] = m.split("-").map(Number);
    let from = `${m}-01`;
    if (book.opening_date && from < book.opening_date) from = book.opening_date;
    const last = new Date(y, mo, 0).getDate();
    const to = `${m}-${String(last).padStart(2, "0")}`;
    const s = await api.get<Summary>(`/api/stats/summary?book_id=${book!.id}&month=${m}`);
    setSum(s);
    const d = await api.get<Daily[]>(`/api/stats/daily?book_id=${book!.id}&from=${from}&to=${to}`);
    setDaily(d);
    const p = await api.get<{ category_id: string; name: string; amount: number }[]>(
      `/api/stats/expense-by-category?book_id=${book!.id}&month=${m}`
    );
    setPie(p);
  }

  useEffect(() => {
    if (!book) return;
    load().catch((e) => setErr(e.message));
  }, [book?.id, month]);

  const refresh = useCallback(async () => {
    setErr("");
    try {
      await ctx.refreshQuotes();
      await load();
    } catch (e: any) {
      setErr(e.message);
    }
  }, [book?.id, month]);

  const { pull, busy } = usePullToRefresh(refresh, !!book?.opening_locked);
  const byDate = useMemo(() => Object.fromEntries(daily.map((d) => [d.date, d])), [daily]);

  if (!book) {
    return (
      <div className="empty">
        <h2>新增第一本帳</h2>
        <p className="muted">預設名稱「生活」，可改。</p>
        <FirstBook ctx={ctx} />
      </div>
    );
  }
  if (!book.opening_locked) {
    return (
      <>
        <BookBar ctx={ctx} />
        <div className="empty">
          <h2>先開帳</h2>
          <p className="muted">用現況快照鎖定開帳日，之後才能記帳與看日曆。</p>
          <button className="btn" onClick={() => nav("/opening")}>去開帳</button>
        </div>
      </>
    );
  }

  const today = todayISO();
  const opening = book.opening_date || "0000-01-01";
  const [y, mo] = month.split("-").map(Number);
  const daysIn = new Date(y, mo, 0).getDate();
  const startWd = new Date(y, mo - 1, 1).getDay();
  const openMonth = opening.slice(0, 7);
  const canPrev = month > openMonth;
  const todayMonth = today.slice(0, 7);

  const lineData = daily
    .filter((d) => (month === todayMonth ? d.date <= today : true))
    .map((d) => ({
      date: d.date.slice(8),
      expense: d.expense,
      income: d.income,
      cash_net: d.cash_net,
    }));

  return (
    <>
      <div className="ptr-ind" style={{ height: busy ? 36 : pull }}>
        {busy ? "更新中…" : pull >= 48 ? "放開以更新報價" : pull > 8 ? "下拉更新報價" : ""}
      </div>
      <BookBar ctx={ctx} extra={<button className="btn ghost" onClick={refresh}>更新報價</button>} />
      {err && <div className="error">{err}</div>}
      {ctx.quoteFailed && <div className="error">報價失敗</div>}
      <div className="card" onClick={() => nav(`/day/${today}`)} style={{ cursor: "pointer" }}>
        <div className="muted">今天已花</div>
        <div className="hero-num minus">NT${money(sum?.today_expense ?? 0)}</div>
        <div className="muted">本月已花 NT${money(sum?.month_expense ?? 0)}</div>
      </div>
      <div className="card">
        <div className="row">
          <div>
            <div className="muted">淨資產</div>
            <div className="hero-num" style={{ fontSize: 26 }}>{ntd(sum?.net_worth ?? 0)}</div>
          </div>
          <div style={{ textAlign: "right" }}>
            <div className="muted">相對開帳</div>
            <div className={(sum?.net_worth_change_vs_opening ?? 0) < 0 ? "minus" : "plus"}>
              {(sum?.net_worth_change_vs_opening ?? 0) > 0 ? "+" : ""}
              {ntd(sum?.net_worth_change_vs_opening ?? 0)}
            </div>
          </div>
        </div>
        <div className="muted" style={{ marginTop: 8 }}>
          持倉現值 {ntd(sum?.position_mv ?? 0)}　未實現 {ntd(sum?.unrealized ?? 0)}
          {sum?.some_positions_unquoted ? "　部分持倉無現價，用成本估" : ""}
        </div>
        {sum?.quote_as_of && <div className="muted">報價 {new Date(sum.quote_as_of).toLocaleString("zh-TW", { timeZone: "Asia/Taipei" })}{ctx.quoteFailed ? " · 報價失敗" : ""}</div>}
      </div>

      <div className="card">
        <div className="row" style={{ marginBottom: 8 }}>
          <button className="btn ghost" disabled={!canPrev} onClick={() => setMonth(shiftMonth(month, -1))}>‹</button>
          <strong>{y} 年 {mo} 月</strong>
          <button className="btn ghost" onClick={() => setMonth(shiftMonth(month, 1))}>›</button>
        </div>
        <div className="cal">
          {["日", "一", "二", "三", "四", "五", "六"].map((d) => (
            <div key={d} className="hd">{d}</div>
          ))}
          {Array.from({ length: startWd }).map((_, i) => <div key={"e" + i} />)}
          {Array.from({ length: daysIn }).map((_, i) => {
            const day = i + 1;
            const ds = `${month}-${String(day).padStart(2, "0")}`;
            const before = ds < opening;
            const isToday = ds === today;
            const exp = byDate[ds]?.expense ?? 0;
            return (
              <button
                key={ds}
                className={`cell${isToday ? " today" : ""}${before ? " fade" : ""}`}
                disabled={before}
                onClick={() => !before && nav(`/day/${ds}`)}
              >
                <div className="d">{day}</div>
                {!before && exp > 0 && <div className="amt">{shortAmt(exp)}</div>}
              </button>
            );
          })}
        </div>
      </div>

      <div className="card">
        <div className="row">
          <strong>每日走勢</strong>
          <select value={series} onChange={(e) => setSeries(e.target.value as any)}>
            <option value="expense">支出</option>
            <option value="income">收入</option>
            <option value="cash_net">現金淨資產（不含持倉）</option>
          </select>
        </div>
        <div className="charts">
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={lineData}>
              <CartesianGrid stroke="#eee" />
              <XAxis dataKey="date" tick={{ fontSize: 10 }} />
              <YAxis tick={{ fontSize: 10 }} width={48} />
              <Tooltip />
              <Line type="monotone" dataKey={series} stroke="#9a3412" dot={false} strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="card">
        <strong>本月支出分類</strong>
        {pie.length === 0 ? (
          <p className="muted">這個月還沒記支出</p>
        ) : (
          <>
            <div className="charts">
              <ResponsiveContainer width="100%" height={220}>
                <PieChart>
                  <Pie data={pie} dataKey="amount" nameKey="name" innerRadius={40} outerRadius={80}>
                    {pie.map((_, i) => <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />)}
                  </Pie>
                  <Tooltip formatter={(v: any) => ntd(Number(v))} />
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="legend">
              {pie.map((p, i) => (
                <div key={p.category_id} className="list-item" onClick={() => nav(`/day/${month}-01?cat=${p.category_id}`)} style={{ cursor: "pointer" }}>
                  <span><span style={{ color: PIE_COLORS[i % PIE_COLORS.length] }}>●</span> {p.name}</span>
                  <span>{ntd(p.amount)}</span>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
      <Link className="btn block big-record" to="/record">記一筆</Link>
    </>
  );
}

function shiftMonth(m: string, delta: number): string {
  const [y, mo] = m.split("-").map(Number);
  const d = new Date(y, mo - 1 + delta, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

function FirstBook({ ctx }: { ctx: Ctx }) {
  const [name, setName] = useState("生活");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  async function create() {
    setBusy(true);
    setErr("");
    try {
      const b = await api.post<{ id: string }>("/api/books", { name });
      await api.post(`/api/books/${b.id}/select`);
      await ctx.reload();
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <div>
      <div className="field" style={{ textAlign: "left" }}>
        <label>帳本名稱</label>
        <input value={name} onChange={(e) => setName(e.target.value)} />
      </div>
      {err && <div className="error">{err}</div>}
      <button className="btn" disabled={busy} onClick={create}>新增帳本</button>
    </div>
  );
}
