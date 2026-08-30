import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import type { Ctx } from "../App";
import { api, type Account } from "../api";
import { ACCOUNT_TYPES, ntd, todayISO } from "../format";
import BookBar from "../components/BookBar";

type PosDraft = {
  account_id: string;
  symbol: string;
  name: string;
  asset_class: string;
  quote_currency: string;
  qty: string;
  cost_twd: string;
  cost_unknown: boolean;
};

export default function Opening({ ctx }: { ctx: Ctx }) {
  const nav = useNavigate();
  const book = ctx.book;
  const [date, setDate] = useState(book?.opening_date || todayISO());
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [cash, setCash] = useState<Record<string, string>>({});
  const [positions, setPositions] = useState<PosDraft[]>([]);
  const [newName, setNewName] = useState("");
  const [newType, setNewType] = useState("bank");
  const [err, setErr] = useState("");
  const [preview, setPreview] = useState(0);
  const [unknown, setUnknown] = useState(false);
  const [busy, setBusy] = useState(false);

  async function load() {
    if (!book) return;
    const o = await api.get<any>(`/api/books/${book.id}/opening`);
    setAccounts(o.accounts || []);
    const m: Record<string, string> = {};
    for (const d of o.cash_drafts || []) m[d.account_id] = String(d.amount);
    setCash(m);
    setPositions(
      (o.position_drafts || []).map((p: any) => ({
        account_id: p.account_id,
        symbol: p.symbol,
        name: p.name,
        asset_class: p.asset_class,
        quote_currency: p.quote_currency,
        qty: p.qty,
        cost_twd: p.cost_twd,
        cost_unknown: p.cost_unknown,
      }))
    );
    if (o.opening_date) setDate(o.opening_date);
    setPreview(o.preview_net_worth || 0);
    setUnknown(!!o.some_cost_unknown);
  }

  useEffect(() => {
    load().catch((e) => setErr(e.message));
  }, [book?.id]);

  if (!book) return <div className="empty">請先新增帳本</div>;
  if (book.opening_locked) return <div className="empty">這本帳已鎖定開帳，開帳日與開帳數字不能改。</div>;

  async function addAccount() {
    if (!newName.trim()) return;
    await api.post("/api/accounts", { book_id: book!.id, name: newName.trim(), type: newType });
    setNewName("");
    await load();
  }

  async function saveDraft() {
    setErr("");
    await api.put(`/api/books/${book!.id}/opening`, {
      opening_date: date,
      accounts: accounts.map((a) => ({ account_id: a.id, amount: Number(cash[a.id] || 0) })),
      positions,
    });
    await load();
    await ctx.reload();
  }

  async function lock(confirm = false) {
    setBusy(true);
    setErr("");
    try {
      await saveDraft();
      await api.post(`/api/books/${book!.id}/opening/lock`, { confirm });
      await ctx.reload();
      nav("/");
    } catch (e: any) {
      if (String(e.message).includes("成本未填")) {
        if (window.confirm("有持倉成本未填，未實現會偏大。確定鎖定？")) {
          await api.post(`/api/books/${book!.id}/opening/lock`, { confirm: true });
          await ctx.reload();
          nav("/");
          return;
        }
      }
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }

  const brokers = accounts.filter((a) => a.type === "broker" || a.type === "exchange");

  return (
    <>
      <BookBar ctx={ctx} />
      <div className="card">
        <h2 style={{ marginTop: 0 }}>開帳快照</h2>
        <div className="field">
          <label>開帳日</label>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </div>
      </div>
      <div className="card">
        <strong>帳戶現金／欠款</strong>
        {accounts.map((a) => (
          <div className="field" key={a.id}>
            <label>{a.name}（{ACCOUNT_TYPES.find((t) => t.id === a.type)?.label}）{a.type === "credit_card" ? "欠款" : "現金"}</label>
            <input inputMode="numeric" value={cash[a.id] ?? ""} onChange={(e) => setCash({ ...cash, [a.id]: e.target.value })} />
          </div>
        ))}
        <div className="field">
          <label>新增帳戶</label>
          <input value={newName} onChange={(e) => setNewName(e.target.value)} placeholder="名稱" />
          <select value={newType} onChange={(e) => setNewType(e.target.value)} style={{ marginTop: 6 }}>
            {ACCOUNT_TYPES.map((t) => <option key={t.id} value={t.id}>{t.label}</option>)}
          </select>
          <button className="btn ghost" style={{ marginTop: 8 }} onClick={addAccount}>加入帳戶</button>
        </div>
      </div>
      <div className="card">
        <strong>現倉</strong>
        {positions.map((p, i) => (
          <div key={i} style={{ borderTop: "1px solid var(--line)", paddingTop: 8, marginTop: 8 }}>
            <select value={p.account_id} onChange={(e) => { const c = [...positions]; c[i] = { ...p, account_id: e.target.value }; setPositions(c); }}>
              {brokers.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
            </select>
            <input placeholder="代號" value={p.symbol} onChange={(e) => { const c = [...positions]; c[i] = { ...p, symbol: e.target.value.toUpperCase() }; setPositions(c); }} />
            <input placeholder="數量" value={p.qty} onChange={(e) => { const c = [...positions]; c[i] = { ...p, qty: e.target.value }; setPositions(c); }} />
            <input placeholder="總成本 TWD" value={p.cost_twd} onChange={(e) => { const c = [...positions]; c[i] = { ...p, cost_twd: e.target.value }; setPositions(c); }} />
            <label className="muted"><input type="checkbox" checked={p.cost_unknown} onChange={(e) => { const c = [...positions]; c[i] = { ...p, cost_unknown: e.target.checked, cost_twd: e.target.checked ? "0" : p.cost_twd }; setPositions(c); }} /> 成本不確定</label>
            <button className="btn ghost" onClick={() => setPositions(positions.filter((_, j) => j !== i))}>移除</button>
          </div>
        ))}
        <button className="btn ghost" style={{ marginTop: 8 }} onClick={() => setPositions([...positions, {
          account_id: brokers[0]?.id || "",
          symbol: "",
          name: "",
          asset_class: "tw_stock",
          quote_currency: "TWD",
          qty: "",
          cost_twd: "0",
          cost_unknown: false,
        }])}>加入現倉</button>
      </div>
      <div className="card">
        <div className="muted">預覽淨資產（持倉暫用成本）</div>
        <div className="hero-num" style={{ fontSize: 24 }}>{ntd(preview)}</div>
        {unknown && <div className="error">有持倉成本未填</div>}
        {err && <div className="error">{err}</div>}
        <button className="btn ghost block" onClick={() => saveDraft()} style={{ marginTop: 8 }}>暫存</button>
        <button className="btn block" disabled={busy} onClick={() => lock(false)} style={{ marginTop: 8 }}>確認鎖定開帳</button>
      </div>
    </>
  );
}
