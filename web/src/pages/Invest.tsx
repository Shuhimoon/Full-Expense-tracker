import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import type { Ctx } from "../App";
import { api } from "../api";
import { ntd } from "../format";
import BookBar from "../components/BookBar";

export default function Invest({ ctx }: { ctx: Ctx }) {
  const nav = useNavigate();
  const book = ctx.book;
  const [rows, setRows] = useState<any[]>([]);
  const [showClosed, setShowClosed] = useState(false);
  const [err, setErr] = useState("");

  async function load() {
    if (!book) return;
    try { await ctx.refreshQuotes(); } catch {}
    setRows(await api.get<any[]>(`/api/positions?book_id=${book.id}`));
  }
  useEffect(() => { load().catch((e) => setErr(e.message)); }, [book?.id]);

  if (!book) return <div className="empty">請先新增帳本</div>;
  const open = rows.filter((r) => !r.closed).sort((a, b) => (b.market_value || 0) - (a.market_value || 0));
  const closed = rows.filter((r) => r.closed);

  return (
    <>
      <BookBar ctx={ctx} extra={<button className="btn ghost" onClick={() => load()}>更新報價</button>} />
      {err && <div className="error">{err}</div>}
      {ctx.quoteFailed && <div className="error">報價失敗</div>}
      <div className="card">
        {open.length === 0 && <div className="muted">沒有未平倉</div>}
        {open.map((r) => (
          <div className="list-item" key={r.id} onClick={() => nav(`/invest/${r.id}`)} style={{ cursor: "pointer" }}>
            <div>
              <div>{r.symbol} {r.name}</div>
              <div className="muted">{r.account_name} ×{r.qty}{ctx.quoteFailedSymbols.includes(r.symbol) ? " · 報價失敗" : ""}</div>
            </div>
            <div style={{ textAlign: "right" }}>
              <div>{r.market_value == null ? "無現價" : ntd(r.market_value)}</div>
              <div className={r.unrealized < 0 ? "minus" : "plus"}>{r.unrealized == null ? "—" : ntd(r.unrealized)}</div>
            </div>
          </div>
        ))}
      </div>
      <div className="card">
        <button className="btn ghost" onClick={() => setShowClosed(!showClosed)}>已平倉 {showClosed ? "收合" : "展開"}</button>
        {showClosed && closed.map((r) => (
          <div className="list-item" key={r.id} onClick={() => nav(`/invest/${r.id}`)}>
            <div>{r.symbol} {r.account_name}</div>
            <div className="muted">已實現 {ntd(r.realized_twd)}</div>
          </div>
        ))}
      </div>
    </>
  );
}
