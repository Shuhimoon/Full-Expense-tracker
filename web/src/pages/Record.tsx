import { useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import type { Ctx } from "../App";
import { api, type Account, type Category } from "../api";
import { todayISO } from "../format";
import BookBar from "../components/BookBar";

const TABS = [
  { id: "expense", label: "支出" },
  { id: "income", label: "收入" },
  { id: "transfer", label: "轉帳" },
  { id: "trade", label: "成交" },
] as const;

export default function Record({ ctx }: { ctx: Ctx }) {
  const nav = useNavigate();
  const [sp] = useSearchParams();
  const book = ctx.book;
  const [tab, setTab] = useState<(typeof TABS)[number]["id"]>((sp.get("type") as any) || "expense");
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [cats, setCats] = useState<Category[]>([]);
  const [amount, setAmount] = useState("");
  const [accountId, setAccountId] = useState("");
  const [toId, setToId] = useState("");
  const [catId, setCatId] = useState("");
  const [date, setDate] = useState(sp.get("date") || todayISO());
  const [note, setNote] = useState("");
  const [side, setSide] = useState("buy");
  const [symbol, setSymbol] = useState("");
  const [assetClass, setAssetClass] = useState("tw_stock");
  const [qty, setQty] = useState("");
  const [price, setPrice] = useState("");
  const [priceCcy, setPriceCcy] = useState("TWD");
  const [fee, setFee] = useState("0");
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!book) return;
    api.get<Account[]>(`/api/accounts?book_id=${book.id}`).then((a) => {
      const live = a.filter((x) => !x.archived_at);
      setAccounts(live);
      const preset = sp.get("account");
      if (preset && live.some((x) => x.id === preset)) setAccountId(preset);
      else if (!accountId && live[0]) setAccountId(live[0].id);
    });
    const presetSym = sp.get("symbol");
    if (presetSym) setSymbol(presetSym.toUpperCase());
    const presetAsset = sp.get("asset");
    if (presetAsset) {
      setAssetClass(presetAsset);
      setPriceCcy(presetAsset === "tw_stock" ? "TWD" : "USD");
    }
    const presetSide = sp.get("side");
    if (presetSide) setSide(presetSide);
    api.get<Category[]>(`/api/categories?book_id=${book.id}`).then(setCats);
  }, [book?.id]);

  if (!book) return <div className="empty">請先新增帳本</div>;
  if (book.archived_at) {
    return (
      <div className="empty">
        這本已封存，不能記帳
        <div><button className="btn" onClick={() => nav("/settings")}>去設定</button></div>
      </div>
    );
  }
  if (!book.opening_locked) {
    return (
      <div className="empty">
        請先開帳再記一筆
        <div><button className="btn" onClick={() => nav("/opening")}>去開帳</button></div>
      </div>
    );
  }

  const minDate = book.opening_date || undefined;
  const kindCats = cats.filter((c) => !c.archived_at && c.kind === (tab === "income" ? "income" : "expense"));

  async function save() {
    setErr("");
    setBusy(true);
    try {
      if (tab === "trade") {
        await api.post("/api/trades", {
          book_id: book!.id,
          date,
          account_id: accountId,
          to_account_id: side === "transfer" ? toId : undefined,
          side,
          symbol,
          asset_class: assetClass,
          quote_currency: priceCcy,
          qty,
          price,
          price_ccy: priceCcy,
          fee_twd: Number(fee) || 0,
          note,
        });
      } else if (tab === "transfer") {
        await api.post("/api/entries", {
          book_id: book!.id,
          type: "transfer",
          amount: Number(amount),
          account_id: accountId,
          to_account_id: toId,
          date,
          note,
        });
      } else {
        await api.post("/api/entries", {
          book_id: book!.id,
          type: tab,
          amount: Number(amount),
          account_id: accountId,
          category_id: catId,
          date,
          note,
        });
      }
      nav(`/day/${date}`);
    } catch (e: any) {
      setErr(e.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <BookBar ctx={ctx} />
      <div className="tabs">
        {TABS.map((t) => (
          <button key={t.id} className={tab === t.id ? "on" : ""} onClick={() => setTab(t.id)}>{t.label}</button>
        ))}
      </div>
      <div className="card">
        {tab !== "trade" && (
          <div className="field">
            <label>金額（TWD）</label>
            <input inputMode="numeric" value={amount} onChange={(e) => setAmount(e.target.value)} />
          </div>
        )}
        <div className="field">
          <label>{tab === "transfer" ? "轉出帳戶" : "帳戶"}</label>
          <select value={accountId} onChange={(e) => setAccountId(e.target.value)}>
            {accounts.filter((a) => tab !== "trade" || a.type === "broker" || a.type === "exchange").map((a) => (
              <option key={a.id} value={a.id}>{a.name}</option>
            ))}
          </select>
        </div>
        {tab === "transfer" && (
          <div className="field">
            <label>轉入帳戶</label>
            <select value={toId} onChange={(e) => setToId(e.target.value)}>
              <option value="">請選擇</option>
              {accounts.map((a) => (
                <option key={a.id} value={a.id}>{a.name}</option>
              ))}
            </select>
          </div>
        )}
        {(tab === "expense" || tab === "income") && (
          <div className="field">
            <label>分類</label>
            <select value={catId} onChange={(e) => setCatId(e.target.value)}>
              <option value="">請選擇</option>
              {kindCats.map((c) => (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </div>
        )}
        {tab === "trade" && (
          <>
            <div className="field">
              <label>方向</label>
              <select value={side} onChange={(e) => setSide(e.target.value)}>
                <option value="buy">買</option>
                <option value="sell">賣</option>
                <option value="transfer">轉倉</option>
                <option value="airdrop">空投／股票股利</option>
              </select>
            </div>
            {side === "transfer" && (
              <div className="field">
                <label>轉入帳戶</label>
                <select value={toId} onChange={(e) => setToId(e.target.value)}>
                  <option value="">請選擇</option>
                  {accounts.filter((a) => a.type === "broker" || a.type === "exchange").map((a) => (
                    <option key={a.id} value={a.id}>{a.name}</option>
                  ))}
                </select>
              </div>
            )}
            <div className="field">
              <label>標的代號</label>
              <input value={symbol} onChange={(e) => setSymbol(e.target.value.toUpperCase())} placeholder="2330 / AAPL / BTC" />
            </div>
            <div className="field">
              <label>資產類別</label>
              <select value={assetClass} onChange={(e) => { setAssetClass(e.target.value); setPriceCcy(e.target.value === "tw_stock" ? "TWD" : "USD"); }}>
                <option value="tw_stock">台股</option>
                <option value="us_stock">美股</option>
                <option value="crypto">加密貨幣</option>
                <option value="fx">外匯／穩定幣</option>
              </select>
            </div>
            <div className="field">
              <label>數量</label>
              <input value={qty} onChange={(e) => setQty(e.target.value)} />
            </div>
            {(side === "buy" || side === "sell") && (
              <>
                <div className="field">
                  <label>單價</label>
                  <input value={price} onChange={(e) => setPrice(e.target.value)} />
                </div>
                <div className="field">
                  <label>單價幣別</label>
                  <select value={priceCcy} onChange={(e) => setPriceCcy(e.target.value)}>
                    <option value="TWD">TWD</option>
                    <option value="USD">USD</option>
                  </select>
                </div>
              </>
            )}
            <div className="field">
              <label>手續費 TWD</label>
              <input value={fee} onChange={(e) => setFee(e.target.value)} />
            </div>
          </>
        )}
        <div className="field">
          <label>日期</label>
          <input type="date" value={date} min={minDate} onChange={(e) => setDate(e.target.value)} />
        </div>
        <div className="field">
          <label>備註</label>
          <input value={note} onChange={(e) => setNote(e.target.value)} />
        </div>
        {err && <div className="error">{err}</div>}
        <button className="btn block" disabled={busy} onClick={save}>{busy ? "儲存中…" : "儲存"}</button>
      </div>
    </>
  );
}
