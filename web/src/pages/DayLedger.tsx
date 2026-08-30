import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import type { Ctx } from "../App";
import { api, type Account, type Category, type Entry } from "../api";
import { ntd } from "../format";
import BookBar from "../components/BookBar";

export default function DayLedger({ ctx }: { ctx: Ctx }) {
  const { date } = useParams();
  const nav = useNavigate();
  const book = ctx.book;
  const [entries, setEntries] = useState<Entry[]>([]);
  const [trades, setTrades] = useState<any[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [cats, setCats] = useState<Category[]>([]);

  useEffect(() => {
    if (!book || !date) return;
    api.get<Entry[]>(`/api/entries?book_id=${book.id}&date=${date}`).then(setEntries);
    api.get<any[]>(`/api/trades?book_id=${book.id}&date=${date}`).then(setTrades);
    api.get<Account[]>(`/api/accounts?book_id=${book.id}`).then(setAccounts);
    api.get<Category[]>(`/api/categories?book_id=${book.id}`).then(setCats);
  }, [book?.id, date]);

  const acc = (id?: string | null) => accounts.find((a) => a.id === id)?.name || "";
  const cat = (id?: string | null) => cats.find((c) => c.id === id)?.name || "";
  const typeLabel: Record<string, string> = { expense: "支出", income: "收入", transfer: "轉帳", opening_balance: "開帳" };
  const sideLabel: Record<string, string> = { buy: "買", sell: "賣", opening: "開倉", airdrop: "空投", transfer_in: "轉入", transfer_out: "轉出" };

  const items = [
    ...entries.map((e) => ({ kind: "entry" as const, at: e.date, created: e.id, e })),
    ...trades.map((t) => ({ kind: "trade" as const, at: t.date, created: t.id, t })),
  ];

  return (
    <>
      <BookBar ctx={ctx} />
      <div className="topbar"><h1>{date} 流水</h1></div>
      <div className="card">
        {items.length === 0 && <div className="muted">這天沒有流水</div>}
        {entries.map((e) => (
          <div className="list-item" key={e.id}>
            <div>
              <div>{typeLabel[e.type] || e.type} {e.type !== "transfer" && cat(e.category_id)}</div>
              <div className="muted">{acc(e.account_id)}{e.to_account_id ? ` → ${acc(e.to_account_id)}` : ""} {e.note}</div>
            </div>
            <div className={e.type === "expense" ? "minus" : e.type === "income" ? "plus" : ""}>{ntd(e.amount)}</div>
          </div>
        ))}
        {trades.map((t) => (
          <div className="list-item" key={t.id}>
            <div>
              <div>成交 {sideLabel[t.side] || t.side}</div>
              <div className="muted">{acc(t.account_id)} ×{t.qty} {t.note}</div>
            </div>
            <div>{ntd(t.proceeds_or_cost_twd)}</div>
          </div>
        ))}
      </div>
      <Link className="btn block big-record" to={`/record?date=${date}`}>記一筆（{date}）</Link>
      <p style={{ textAlign: "center" }}><button className="btn ghost" onClick={() => nav("/")}>回首頁</button></p>
    </>
  );
}
