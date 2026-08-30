import { useCallback, useEffect, useState } from "react";
import { Link, Navigate, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { api, ApiError, type Book, type User } from "./api";
import Auth from "./pages/Auth";
import Home from "./pages/Home";
import Record from "./pages/Record";
import Accounts from "./pages/Accounts";
import AccountDetail from "./pages/AccountDetail";
import Invest from "./pages/Invest";
import Settings from "./pages/Settings";
import Opening from "./pages/Opening";
import DayLedger from "./pages/DayLedger";
import PositionDetail from "./pages/PositionDetail";

export type QuoteRefresh = { updated: number; failed: string[]; message: string; quote_failed?: boolean };

export type Ctx = {
  user: User;
  books: Book[];
  book: Book | null;
  reload: () => Promise<void>;
  selectBook: (id: string) => Promise<void>;
  quoteFailed: boolean;
  quoteFailedSymbols: string[];
  refreshQuotes: () => Promise<QuoteRefresh>;
};

export default function App() {
  const [user, setUser] = useState<User | null | undefined>(undefined);
  const [books, setBooks] = useState<Book[]>([]);
  const [quoteFailed, setQuoteFailed] = useState(false);
  const [quoteFailedSymbols, setQuoteFailedSymbols] = useState<string[]>([]);
  const loc = useLocation();

  async function reload() {
    const u = await api.get<User>("/api/me");
    setUser(u);
    const bs = await api.get<Book[]>("/api/books");
    setBooks(bs);
  }

  useEffect(() => {
    api
      .get<User>("/api/me")
      .then(async (u) => {
        setUser(u);
        setBooks(await api.get<Book[]>("/api/books"));
      })
      .catch((e) => {
        if (e instanceof ApiError && e.status === 401) setUser(null);
        else setUser(null);
      });
  }, []);

  async function selectBook(id: string) {
    await api.post(`/api/books/${id}/select`);
    await reload();
  }

  const live = books.filter((b) => !b.archived_at);
  const active = (user && live.find((b) => b.id === user.last_book_id)) || live[0] || null;

  const refreshQuotes = useCallback(async (): Promise<QuoteRefresh> => {
    if (!active) return { updated: 0, failed: [], message: "" };
    try {
      const r = await api.post<QuoteRefresh>(`/api/quotes/refresh?book_id=${active.id}`);
      const failed = r.failed || [];
      setQuoteFailed(failed.length > 0 || !!r.quote_failed);
      setQuoteFailedSymbols(failed);
      return r;
    } catch {
      setQuoteFailed(true);
      return { updated: 0, failed: ["網路"], message: "報價失敗" };
    }
  }, [active?.id]);

  useEffect(() => {
    function onFg() {
      if (document.visibilityState === "visible") {
        refreshQuotes().catch(() => {});
      }
    }
    document.addEventListener("visibilitychange", onFg);
    window.addEventListener("focus", onFg);
    return () => {
      document.removeEventListener("visibilitychange", onFg);
      window.removeEventListener("focus", onFg);
    };
  }, [refreshQuotes]);

  if (user === undefined) {
    return <div className="empty muted">載入中…</div>;
  }
  if (!user) {
    return (
      <Routes>
        <Route path="/register" element={<Auth mode="register" onAuthed={reload} />} />
        <Route path="*" element={<Auth mode="login" onAuthed={reload} />} />
      </Routes>
    );
  }

  const ctx: Ctx = { user, books, book: active, reload, selectBook, quoteFailed, quoteFailedSymbols, refreshQuotes };

  return (
    <div className="app">
      <Routes>
        <Route path="/opening" element={<Opening ctx={ctx} />} />
        <Route path="/record" element={<Record ctx={ctx} />} />
        <Route path="/accounts/:id" element={<AccountDetail ctx={ctx} />} />
        <Route path="/accounts" element={<Accounts ctx={ctx} />} />
        <Route path="/invest/:id" element={<PositionDetail ctx={ctx} />} />
        <Route path="/invest" element={<Invest ctx={ctx} />} />
        <Route path="/settings" element={<Settings ctx={ctx} onLogout={() => setUser(null)} />} />
        <Route path="/day/:date" element={<DayLedger ctx={ctx} />} />
        <Route path="/" element={<Home ctx={ctx} />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      <Nav path={loc.pathname} />
    </div>
  );
}

function Nav({ path }: { path: string }) {
  const nav = useNavigate();
  const items = [
    { to: "/", label: "首頁" },
    { to: "/record", label: "記一筆", fab: true },
    { to: "/accounts", label: "帳戶" },
    { to: "/invest", label: "投資" },
    { to: "/settings", label: "設定" },
  ];
  return (
    <nav className="nav">
      {items.map((it) => (
        <Link
          key={it.to}
          to={it.to}
          className={path === it.to || (it.to !== "/" && path.startsWith(it.to)) ? "on" : ""}
          onClick={(e) => {
            if (it.fab) {
              e.preventDefault();
              nav("/record");
            }
          }}
        >
          {it.fab ? <span className="fab">＋</span> : it.label}
          {it.fab ? <span>記一筆</span> : null}
        </Link>
      ))}
    </nav>
  );
}
