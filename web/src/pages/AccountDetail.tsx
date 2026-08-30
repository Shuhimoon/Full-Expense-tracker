import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import type { Ctx } from "../App";
import { api, type Account, type Category, type Entry } from "../api";
import { ntd, typeLabel } from "../format";
import BookBar from "../components/BookBar";

const SIDE: Record<string, string> = {
  buy: "買", sell: "賣", opening: "開倉", airdrop: "空投", transfer_in: "轉入", transfer_out: "轉出",
};
const ETYPE: Record<string, string> = {
  expense: "支出", income: "收入", transfer: "轉帳", opening_balance: "開帳",
};

export default function AccountDetail({ ctx }: { ctx: Ctx }) {
  const { id } = useParams();
  const nav = useNavigate();
  const book = ctx.book;
  const [acc, setAcc] = useState<Account | null>(null);
  const [entries, setEntries] = useState<Entry[]>([]);
  const [trades, setTrades] = useState<any[]>([]);
  const [positions, setPositions] = useState<any[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [cats, setCats] = useState<Category[]>([]);
  const [instruments, setInstruments] = useState<any[]>([]);
  const [err, setErr] = useState("");

  async function load() {
    if (!book || !id) return;
    const list = await api.get<Account[]>(`/api/accounts?book_id=${book.id}`);
    setAccounts(list);
    const found = list.find((a) => a.id === id) || null;
    setAcc(found);
    if (!found) return;
    const [ents, trs, insts, catsL] = await Promise.all([
      api.get<Entry[]>(`/api/entries?book_id=${book.id}&account_id=${id}`),
      api.get<any[]>(`/api/trades?book_id=${book.id}&account_id=${id}`),
      api.get<any[]>(`/api/instruments?book_id=${book.id}`),
      api.get<Category[]>(`/api/categories?book_id=${book.id}`),
    ]);
    setEntries(ents);
    setTrades(trs);
    setInstruments(insts);
    setCats(catsL);
    if (found.type === "broker" || found.type === "exchange") {
      setPositions(await api.get<any[]>(`/api/positions?book_id=${book.id}&account_id=${id}`));
    } else {
      setPositions([]);
    }
  }

  useEffect(() => {
    load().catch((e) => setErr(e.message));
  }, [book?.id, id]);

  const accName = (aid?: string | null) => accounts.find((a) => a.id === aid)?.name || "";
  const catName = (cid?: string | null) => cats.find((c) => c.id === cid)?.name || "";
  const instName = (iid?: string | null) => {
    const i = instruments.find((x) => x.id === iid);
    return i ? `${i.symbol}${i.name ? " " + i.name : ""}` : "";
  };

  const ledger = useMemo(() => {
    const rows: { key: string; date: string; created: string; kind: "entry" | "trade"; e?: Entry; t?: any }[] = [
      ...entries.map((e) => ({ key: "e" + e.id, date: e.date, created: e.created_at || e.id, kind: "entry" as const, e })),
      ...trades.map((t) => ({ key: "t" + t.id, date: t.date, created: t.created_at || t.id, kind: "trade" as const, t })),
    ];
    rows.sort((a, b) => (a.date + a.created).localeCompare(b.date + b.created));
    return rows;
  }, [entries, trades]);

  if (!book) return <div className="empty">請先新增帳本</div>;
  if (!acc) return <div className="empty">{err || "載入中…"}</div>;

  const invest = acc.type === "broker" || acc.type === "exchange";
  const openPos = positions.filter((p) => !p.closed);

  return (
    <>
      <BookBar ctx={ctx} extra={<button className="btn ghost" onClick={() => nav("/accounts")}>← 帳戶</button>} />
      <div className="card">
        <div className="muted">{typeLabel(acc.type)}</div>
        <h2 style={{ margin: "4px 0 8px" }}>{acc.name}</h2>
        <div className="hero-num" style={{ fontSize: 26 }}>
          {acc.type === "credit_card" ? `欠 ${ntd(acc.cash_balance)}` : ntd(acc.cash_balance)}
        </div>
        {invest && <div className="muted" style={{ marginTop: 6 }}>持倉現值 {ntd(acc.position_mv ?? 0)}</div>}
      </div>

      {invest && (
        <div className="card">
          <strong>持倉</strong>
          {openPos.length === 0 && <div className="muted">沒有未平倉</div>}
          {openPos.map((p) => (
            <div className="list-item" key={p.id} style={{ cursor: "pointer" }} onClick={() => nav(`/invest/${p.id}`)}>
              <div>
                <div>{p.symbol} {p.name}</div>
                <div className="muted">×{p.qty}　成本 {ntd(Number(p.cost_twd))}</div>
              </div>
              <div style={{ textAlign: "right" }}>
                <div>{p.market_value == null ? "無現價" : ntd(p.market_value)}</div>
                {ctx.quoteFailed && ctx.quoteFailedSymbols.includes(p.symbol) && <div className="minus">報價失敗</div>}
              </div>
            </div>
          ))}
          <button className="btn" style={{ marginTop: 8 }} onClick={() => nav(`/record?type=trade&account=${acc.id}&side=buy`)}>買入</button>
        </div>
      )}

      <div className="card">
        <strong>流水</strong>
        {ledger.length === 0 && <div className="muted">還沒有流水</div>}
        {ledger.map((row) => {
          if (row.kind === "entry" && row.e) {
            const e = row.e;
            const isOut = e.type === "transfer" && e.account_id === acc.id;
            const isIn = e.type === "transfer" && e.to_account_id === acc.id;
            return (
              <div className="list-item" key={row.key}>
                <div>
                  <div>{e.date} {ETYPE[e.type] || e.type} {e.type !== "transfer" ? catName(e.category_id) : ""}</div>
                  <div className="muted">
                    {e.type === "transfer"
                      ? `${accName(e.account_id)} → ${accName(e.to_account_id)}`
                      : accName(e.account_id)}{" "}
                    {e.note}
                  </div>
                </div>
                <div className={e.type === "expense" || isOut ? "minus" : e.type === "income" || isIn ? "plus" : ""}>
                  {ntd(e.amount)}
                </div>
              </div>
            );
          }
          const t = row.t;
          return (
            <div className="list-item" key={row.key}>
              <div>
                <div>{t.date} 成交 {SIDE[t.side] || t.side} {instName(t.instrument_id)}</div>
                <div className="muted">×{t.qty} {t.note}</div>
              </div>
              <div>{ntd(t.proceeds_or_cost_twd)}</div>
            </div>
          );
        })}
      </div>

      {err && <div className="error">{err}</div>}
      <p style={{ margin: "12px 16px" }}>
        <button className="btn block" onClick={() => nav(`/record?account=${acc.id}`)}>記一筆</button>
      </p>
    </>
  );
}
