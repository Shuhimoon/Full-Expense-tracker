import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import type { Ctx } from "../App";
import { api, type Account } from "../api";
import { ACCOUNT_TYPES, ntd, typeLabel } from "../format";
import BookBar from "../components/BookBar";

export default function Accounts({ ctx }: { ctx: Ctx }) {
  const nav = useNavigate();
  const book = ctx.book;
  const [list, setList] = useState<Account[]>([]);
  const [name, setName] = useState("");
  const [type, setType] = useState("bank");
  const [err, setErr] = useState("");

  async function load() {
    if (!book) return;
    setList(await api.get<Account[]>(`/api/accounts?book_id=${book.id}`));
  }
  useEffect(() => { load().catch((e) => setErr(e.message)); }, [book?.id]);

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

  return (
    <>
      <BookBar ctx={ctx} />
      {ACCOUNT_TYPES.map((g) => {
        const items = list.filter((a) => a.type === g.id && !a.archived_at);
        return (
          <div key={g.id}>
            <div className="group-title">{g.label}</div>
            <div className="card">
              {items.length === 0 && <div className="muted">尚無</div>}
              {items.map((a) => (
                <div className="list-item" key={a.id} style={{ cursor: "pointer" }} onClick={() => nav(`/accounts/${a.id}`)}>
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
      <div className="card">
        <strong>新增帳戶</strong>
        <div className="field">
          <label>名稱</label>
          <input value={name} onChange={(e) => setName(e.target.value)} />
        </div>
        <div className="field">
          <label>類型</label>
          <select value={type} onChange={(e) => setType(e.target.value)}>
            {ACCOUNT_TYPES.map((t) => <option key={t.id} value={t.id}>{t.label}</option>)}
          </select>
        </div>
        {err && <div className="error">{err}</div>}
        <button className="btn" onClick={add}>新增</button>
        <p className="muted">{typeLabel(type)}，幣別鎖定 TWD</p>
      </div>
    </>
  );
}
