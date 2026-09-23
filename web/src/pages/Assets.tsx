import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import type { Ctx } from "../App";
import { api, type Account } from "../api";
import { ACCOUNT_TYPES, ntd, typeLabel } from "../format";
import BookBar from "../components/BookBar";

export default function Assets({ ctx }: { ctx: Ctx }) {
  const nav = useNavigate();
  const book = ctx.book;
  const [list, setList] = useState<Account[]>([]);
  const [rows, setRows] = useState<any[]>([]);
  const [showClosed, setShowClosed] = useState(false);
  const [name, setName] = useState("");
  const [type, setType] = useState("bank");
  const [err, setErr] = useState("");

  async function load() {
    if (!book) return;
    setList(await api.get<Account[]>(`/api/accounts?book_id=${book.id}`));
    try {
      await ctx.refreshQuotes();
    } catch {}
    setRows(await api.get<any[]>(`/api/positions?book_id=${book.id}`));
  }
  useEffect(() => {
    load().catch((e) => setErr(e.message));
  }, [book?.id]);

  if (!book) return <div className="empty">請先新增帳本</div>;

  async function add() {
    setErr("");
    try {
      await api.post("/api/accounts", { book_id: book!.id, name, type });
      setName("");
      await load();
    } catch (e: any) {
      setErr(e.message);
    }
  }

  const open = rows.filter((r) => !r.closed).sort((a, b) => (b.market_value || 0) - (a.market_value || 0));
  const closed = rows.filter((r) => r.closed);

  return (
    <>
      <BookBar ctx={ctx} extra={<button className="btn ghost" onClick={() => load()}>更新報價</button>} />
      {err && <div className="error">{err}</div>}
      {ctx.quoteFailed && <div className="error">報價失敗</div>}

      <div className="group-title">帳戶</div>
      {ACCOUNT_TYPES.map((g) => {
        const items = list.filter((a) => a.type === g.id && !a.archived_at);
        if (items.length === 0) return null;
        return (
          <div key={g.id}>
            <div className="group-title" style={{ marginTop: 8 }}>
              {g.label}
            </div>
            <div className="card">
              {items.map((a) => (
                <div
                  className="list-item"
                  key={a.id}
                  style={{ cursor: "pointer" }}
                  onClick={() => nav(`/accounts/${a.id}`)}
                >
                  <div>
                    <div>{a.name}</div>
                    {(a.type === "broker" || a.type === "exchange") && (
                      <div className="muted">持倉現值 {ntd(a.position_mv ?? 0)}</div>
                    )}
                  </div>
                  <div>{a.type === "credit_card" ? `欠 ${ntd(a.cash_balance)}` : ntd(a.cash_balance)}</div>
                </div>
              ))}
            </div>
          </div>
        );
      })}
      {list.filter((a) => !a.archived_at).length === 0 && (
        <div className="card">
          <div className="muted">尚無帳戶</div>
        </div>
      )}

      <div className="group-title">持倉</div>
      <div className="card">
        {open.length === 0 && <div className="muted">沒有未平倉</div>}
        {open.map((r) => (
          <div className="list-item" key={r.id} onClick={() => nav(`/invest/${r.id}`)} style={{ cursor: "pointer" }}>
            <div>
              <div>
                {r.symbol} {r.name}
              </div>
              <div className="muted">
                {r.account_name} ×{r.qty}
                {ctx.quoteFailedSymbols.includes(r.symbol) ? " · 報價失敗" : ""}
              </div>
            </div>
            <div style={{ textAlign: "right" }}>
              <div>{r.market_value == null ? "無現價" : ntd(r.market_value)}</div>
              <div className={r.unrealized < 0 ? "minus" : "plus"}>{r.unrealized == null ? "—" : ntd(r.unrealized)}</div>
            </div>
          </div>
        ))}
      </div>
      <div className="card">
        <button className="btn ghost" onClick={() => setShowClosed(!showClosed)}>
          已平倉 {showClosed ? "收合" : "展開"}
        </button>
        {showClosed &&
          closed.map((r) => (
            <div className="list-item" key={r.id} onClick={() => nav(`/invest/${r.id}`)} style={{ cursor: "pointer" }}>
              <div>
                {r.symbol} {r.account_name}
              </div>
              <div className="muted">已實現 {ntd(r.realized_twd)}</div>
            </div>
          ))}
      </div>

      <div className="card">
        <strong>新增帳戶</strong>
        <div className="field">
          <label>名稱</label>
          <input value={name} onChange={(e) => setName(e.target.value)} />
        </div>
        <div className="field">
          <label>類型</label>
          <select value={type} onChange={(e) => setType(e.target.value)}>
            {ACCOUNT_TYPES.map((t) => (
              <option key={t.id} value={t.id}>
                {t.label}
              </option>
            ))}
          </select>
        </div>
        {err && <div className="error">{err}</div>}
        <button className="btn" onClick={add}>
          新增
        </button>
        <p className="muted">{typeLabel(type)}，幣別鎖定 TWD</p>
      </div>
    </>
  );
}
