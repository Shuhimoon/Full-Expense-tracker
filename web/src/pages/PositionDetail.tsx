import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import type { Ctx } from "../App";
import { api } from "../api";
import { ntd } from "../format";
import BookBar from "../components/BookBar";

export default function PositionDetail({ ctx }: { ctx: Ctx }) {
  const { id } = useParams();
  const nav = useNavigate();
  const book = ctx.book;
  const [pos, setPos] = useState<any>(null);
  const [detail, setDetail] = useState<any>(null);
  const [price, setPrice] = useState("");
  const [err, setErr] = useState("");

  async function load() {
    if (!book || !id) return;
    try { await ctx.refreshQuotes(); } catch {}
    const list = await api.get<any[]>(`/api/positions?book_id=${book.id}`);
    setPos(list.find((p) => p.id === id) || null);
    setDetail(await api.get<any>(`/api/positions/${id}`));
  }
  useEffect(() => { load().catch((e) => setErr(e.message)); }, [id, book?.id]);

  if (!pos) return <div className="empty">載入中…</div>;
  const sideLabel: Record<string, string> = { buy: "買", sell: "賣", opening: "開倉", airdrop: "空投", transfer_in: "轉入", transfer_out: "轉出" };

  async function savePrice() {
    setErr("");
    try {
      await api.post("/api/quotes", { book_id: book!.id, instrument_id: pos.instrument_id, price, ccy: pos.quote_currency, locked: true });
      await load();
    } catch (e: any) {
      setErr(e.message);
    }
  }

  return (
    <>
      <BookBar ctx={ctx} />
      <div className="card">
        <h2 style={{ marginTop: 0 }}>{pos.symbol} {pos.name}</h2>
        <div className="muted">{pos.account_name}</div>
        <div className="list-item"><span>數量</span><span>{pos.qty}</span></div>
        <div className="list-item"><span>均價</span><span>{pos.avg_cost_twd}</span></div>
        <div className="list-item"><span>剩餘成本</span><span>{ntd(Number(pos.cost_twd))}</span></div>
        <div className="list-item"><span>現值</span><span>{pos.market_value == null ? "—" : ntd(pos.market_value)}</span></div>
        <div className="list-item"><span>未實現</span><span>{pos.unrealized == null ? "—" : ntd(pos.unrealized)}</span></div>
        <div className="list-item"><span>已實現</span><span>{ntd(pos.realized_twd)}</span></div>
        <div className="list-item"><span>累計</span><span>{pos.unrealized == null ? "—" : ntd(pos.realized_twd + pos.unrealized)}</span></div>
        {pos.cost_unknown && <div className="error">成本未填</div>}
        {pos.quote_as_of && <div className="muted">報價 {new Date(pos.quote_as_of).toLocaleString("zh-TW", { timeZone: "Asia/Taipei" })} {pos.quote_source === "manual" ? "手改" : "自動"}{pos.quote_locked ? "（已鎖）" : ""}</div>}
        {ctx.quoteFailed && <div className="error">報價失敗</div>}
      </div>
      <div className="card">
        <strong>手改現價</strong>
        <div className="field"><input value={price} onChange={(e) => setPrice(e.target.value)} placeholder={pos.quote_currency} /></div>
        <button className="btn ghost" onClick={savePrice}>鎖定手改價</button>
        {err && <div className="error">{err}</div>}
      </div>
      <div className="card">
        <strong>成交</strong>
        {(detail?.trades || []).map((t: any) => (
          <div className="list-item" key={t.id}>
            <div>{t.date} {sideLabel[t.side] || t.side} ×{t.qty}</div>
            <div>{ntd(t.proceeds_or_cost_twd)}</div>
          </div>
        ))}
      </div>
      <p style={{ textAlign: "center" }}>
        <button className="btn" onClick={() => nav(`/record?type=trade&account=${pos.account_id}&symbol=${encodeURIComponent(pos.symbol)}&asset=${pos.asset_class || ""}`)}>買／賣</button>
      </p>
    </>
  );
}
