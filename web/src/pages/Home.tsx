import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { usePullToRefresh } from "../hooks/usePullToRefresh";
import type { Ctx } from "../App";
import { api, type Account, type Category, type Daily, type Entry, type Summary } from "../api";
import { money, ntd, shortAmt, todayISO, ym } from "../format";
import BookBar from "../components/BookBar";

type FeedItem =
  | { kind: "entry"; id: string; date: string; sort: string; e: Entry }
  | { kind: "trade"; id: string; date: string; sort: string; t: any };

export default function Home({ ctx }: { ctx: Ctx }) {
  const nav = useNavigate();
  const book = ctx.book;
  const [month, setMonth] = useState(ym());
  const [sum, setSum] = useState<Summary | null>(null);
  const [daily, setDaily] = useState<Daily[]>([]);
  const [feed, setFeed] = useState<FeedItem[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [cats, setCats] = useState<Category[]>([]);
  const [err, setErr] = useState("");
  const [feedMode, setFeedMode] = useState<"today" | "recent">("today");

  async function load(m = month) {
    if (!book || !book.opening_locked) return;
    const [y, mo] = m.split("-").map(Number);
    let from = `${m}-01`;
    if (book.opening_date && from < book.opening_date) from = book.opening_date;
    const last = new Date(y, mo, 0).getDate();
    const to = `${m}-${String(last).padStart(2, "0")}`;
    const today = todayISO();

    setSum(await api.get<Summary>(`/api/stats/summary?book_id=${book.id}&month=${m}`));
    setDaily(await api.get<Daily[]>(`/api/stats/daily?book_id=${book.id}&from=${from}&to=${to}`));
    setAccounts(await api.get<Account[]>(`/api/accounts?book_id=${book.id}`));
    setCats(await api.get<Category[]>(`/api/categories?book_id=${book.id}`));

    let entries = await api.get<Entry[]>(`/api/entries?book_id=${book.id}&date=${today}`);
    let trades = await api.get<any[]>(`/api/trades?book_id=${book.id}&date=${today}`);
    let mode: "today" | "recent" = "today";
    if (entries.length === 0 && trades.length === 0) {
      let fr = shiftDate(today, -13);
      if (book.opening_date && fr < book.opening_date) fr = book.opening_date;
      entries = await api.get<Entry[]>(`/api/entries?book_id=${book.id}&from=${fr}&to=${today}`);
      trades = await api.get<any[]>(`/api/trades?book_id=${book.id}&from=${fr}&to=${today}`);
      mode = "recent";
    }
    setFeedMode(mode);

    const items: FeedItem[] = [
      ...entries
        .filter((e) => e.type !== "opening_balance")
        .map((e) => ({ kind: "entry" as const, id: e.id, date: e.date, sort: e.created_at || e.id, e })),
      ...trades
        .filter((t) => t.side !== "opening")
        .map((t) => ({ kind: "trade" as const, id: t.id, date: t.date, sort: t.created_at || t.id, t })),
    ];
    items.sort((a, b) =>
      a.date !== b.date ? b.date.localeCompare(a.date) : String(b.sort).localeCompare(String(a.sort))
    );
    setFeed(items.slice(0, 40));
  }

  useEffect(() => {
    if (!book) return;
    load().catch((e) => setErr(e.message));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [book?.id, month]);

  const refresh = useCallback(async () => {
    setErr("");
    try {
      await ctx.refreshQuotes();
      await load();
    } catch (e: any) {
      setErr(e.message);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [book?.id, month]);

  const { pull, busy } = usePullToRefresh(refresh, !!book?.opening_locked);
  const byDate = useMemo(() => Object.fromEntries(daily.map((d) => [d.date, d])), [daily]);
  const accName = (id?: string | null) => accounts.find((a) => a.id === id)?.name || "";
  const catName = (id?: string | null) => cats.find((c) => c.id === id)?.name || "";
  const typeLabel: Record<string, string> = { expense: "支出", income: "收入", transfer: "轉帳" };
  const sideLabel: Record<string, string> = {
    buy: "買",
    sell: "賣",
    airdrop: "空投",
    transfer: "轉倉",
    transfer_in: "轉入",
    transfer_out: "轉出",
  };

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
          <button className="btn" onClick={() => nav("/opening")}>
            去開帳
          </button>
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
  const feedTitle = feedMode === "today" ? "今天流水" : "最近流水";

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
        <div className="row">
          <div className="hero-num minus">NT${money(sum?.today_expense ?? 0)}</div>
          <div className="muted" style={{ textAlign: "right" }}>
            本月已花
            <div style={{ fontWeight: 600, fontSize: 14, marginTop: 2 }}>
              NT${money(sum?.month_expense ?? 0)}
            </div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="row">
          <div>
            <div className="muted">淨資產</div>
            <div className="hero-num" style={{ fontSize: 24 }}>
              {ntd(sum?.net_worth ?? 0)}
            </div>
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
        {sum?.quote_as_of && (
          <div className="muted">
            報價 {new Date(sum.quote_as_of).toLocaleString("zh-TW", { timeZone: "Asia/Taipei" })}
            {ctx.quoteFailed ? " · 報價失敗" : ""}
          </div>
        )}
      </div>

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
        <div className="cal">
          {["日", "一", "二", "三", "四", "五", "六"].map((d) => (
            <div key={d} className="hd">
              {d}
            </div>
          ))}
          {Array.from({ length: startWd }).map((_, i) => (
            <div key={"e" + i} />
          ))}
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
        <div className="section-h">
          <h2>{feedTitle}</h2>
          <Link className="more" to={`/day/${today}`}>
            全部
          </Link>
        </div>
        {feed.length === 0 && <div className="muted">還沒有流水，點 ＋ 記一筆</div>}
        {feed.map((item) => {
          if (item.kind === "entry") {
            const e = item.e;
            const title =
              e.type === "transfer"
                ? "轉帳"
                : `${typeLabel[e.type] || e.type}${catName(e.category_id) ? ` · ${catName(e.category_id)}` : ""}`;
            const sub =
              e.type === "transfer"
                ? `${accName(e.account_id)} → ${accName(e.to_account_id)}`
                : `${accName(e.account_id)}${e.note ? ` · ${e.note}` : ""}`;
            const amtClass = e.type === "expense" ? "minus" : e.type === "income" ? "plus" : "";
            const prefix = e.type === "expense" ? "−" : e.type === "income" ? "+" : "";
            return (
              <div className="list-item" key={e.id} style={{ cursor: "pointer" }} onClick={() => nav(`/day/${e.date}`)}>
                <div className="tx-ico">{e.type === "expense" ? "支" : e.type === "income" ? "收" : "轉"}</div>
                <div className="tx-meta">
                  <div className="tx-name">{title}</div>
                  <div className="tx-sub">
                    {item.date !== today ? `${item.date} · ` : ""}
                    {sub}
                  </div>
                </div>
                <div className={amtClass} style={{ fontWeight: 600 }}>
                  {e.type === "transfer" ? ntd(e.amount) : `${prefix}${money(e.amount)}`}
                </div>
              </div>
            );
          }
          const t = item.t;
          return (
            <div className="list-item" key={t.id} style={{ cursor: "pointer" }} onClick={() => nav(`/day/${t.date}`)}>
              <div className="tx-ico">成</div>
              <div className="tx-meta">
                <div className="tx-name">成交 · {sideLabel[t.side] || t.side}</div>
                <div className="tx-sub">
                  {item.date !== today ? `${item.date} · ` : ""}
                  {accName(t.account_id)} ×{t.qty}
                  {t.note ? ` · ${t.note}` : ""}
                </div>
              </div>
              <div style={{ fontWeight: 600 }}>{ntd(t.proceeds_or_cost_twd)}</div>
            </div>
          );
        })}
      </div>
    </>
  );
}

function shiftMonth(m: string, delta: number): string {
  const [y, mo] = m.split("-").map(Number);
  const d = new Date(y, mo - 1 + delta, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

function shiftDate(iso: string, deltaDays: number): string {
  const [y, m, d] = iso.split("-").map(Number);
  const dt = new Date(y, m - 1, d + deltaDays);
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, "0")}-${String(dt.getDate()).padStart(2, "0")}`;
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
      <button className="btn" disabled={busy} onClick={create}>
        新增帳本
      </button>
    </div>
  );
}
