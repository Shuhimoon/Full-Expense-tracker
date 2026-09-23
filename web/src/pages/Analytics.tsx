import { useEffect, useState } from "react";
import { CartesianGrid, Cell, Line, LineChart, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import type { Ctx } from "../App";
import { api, type Daily } from "../api";
import { ntd, todayISO, ym } from "../format";
import BookBar from "../components/BookBar";

const PIE_COLORS = ["#8FB09F", "#5F8574", "#B8C9C0", "#D4C4B0", "#E8D5C4", "#8B1A3A", "#78716c", "#57534e"];

export default function Analytics({ ctx }: { ctx: Ctx }) {
  const book = ctx.book;
  const [month, setMonth] = useState(ym());
  const [daily, setDaily] = useState<Daily[]>([]);
  const [pie, setPie] = useState<{ category_id: string; name: string; amount: number }[]>([]);
  const [series, setSeries] = useState<"expense" | "income" | "cash_net">("expense");
  const [err, setErr] = useState("");

  async function load(m = month) {
    if (!book?.opening_locked) return;
    const [y, mo] = m.split("-").map(Number);
    let from = `${m}-01`;
    if (book.opening_date && from < book.opening_date) from = book.opening_date;
    const last = new Date(y, mo, 0).getDate();
    const to = `${m}-${String(last).padStart(2, "0")}`;
    setDaily(await api.get<Daily[]>(`/api/stats/daily?book_id=${book.id}&from=${from}&to=${to}`));
    setPie(
      await api.get<{ category_id: string; name: string; amount: number }[]>(
        `/api/stats/expense-by-category?book_id=${book.id}&month=${m}`
      )
    );
  }

  useEffect(() => {
    if (!book) return;
    load().catch((e) => setErr(e.message));
  }, [book?.id, month]);

  if (!book) return <div className="empty">請先新增帳本</div>;
  if (!book.opening_locked) {
    return (
      <>
        <BookBar ctx={ctx} />
        <div className="empty">
          <h2>先開帳</h2>
          <p className="muted">開帳後才能看分析圖</p>
        </div>
      </>
    );
  }

  const today = todayISO();
  const todayMonth = today.slice(0, 7);
  const [y, mo] = month.split("-").map(Number);
  const openMonth = (book.opening_date || "0000-01").slice(0, 7);
  const canPrev = month > openMonth;

  const lineData = daily
    .filter((d) => (month === todayMonth ? d.date <= today : true))
    .map((d) => ({
      date: d.date.slice(8),
      expense: d.expense,
      income: d.income,
      cash_net: d.cash_net,
    }));

  const seriesLabel =
    series === "expense" ? "支出" : series === "income" ? "收入" : "現金淨資產（不含持倉）";

  return (
    <>
      <BookBar ctx={ctx} />
      {err && <div className="error">{err}</div>}
      <div className="card">
        <div className="row" style={{ marginBottom: 8 }}>
          <button className="btn ghost" disabled={!canPrev} onClick={() => setMonth(shiftMonth(month, -1))}>
            ‹
          </button>
          <strong>
            {y} 年 {mo} 月
          </strong>
          <button className="btn ghost" onClick={() => setMonth(shiftMonth(month, 1))}>
            ›
          </button>
        </div>
      </div>

      <div className="card">
        <div className="row">
          <strong>每日走勢</strong>
          <select value={series} onChange={(e) => setSeries(e.target.value as typeof series)}>
            <option value="expense">支出</option>
            <option value="income">收入</option>
            <option value="cash_net">現金淨資產（不含持倉）</option>
          </select>
        </div>
        <p className="muted" style={{ margin: "4px 0 8px" }}>
          {seriesLabel}
        </p>
        <div className="charts">
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={lineData}>
              <CartesianGrid stroke="rgba(60,60,67,0.08)" />
              <XAxis dataKey="date" tick={{ fontSize: 10 }} />
              <YAxis tick={{ fontSize: 10 }} width={48} />
              <Tooltip formatter={(v: number) => ntd(Number(v))} />
              <Line type="monotone" dataKey={series} stroke="#8FB09F" dot={false} strokeWidth={2} />
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
                    {pie.map((_, i) => (
                      <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip formatter={(v: number) => ntd(Number(v))} />
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="legend">
              {pie.map((p, i) => (
                <div key={p.category_id} className="list-item">
                  <span>
                    <span style={{ color: PIE_COLORS[i % PIE_COLORS.length] }}>●</span> {p.name}
                  </span>
                  <span>{ntd(p.amount)}</span>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
    </>
  );
}

function shiftMonth(m: string, delta: number): string {
  const [y, mo] = m.split("-").map(Number);
  const d = new Date(y, mo - 1 + delta, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}
