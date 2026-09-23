import { useCallback, useEffect, useState } from "react";
import { Link, Navigate, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { api, ApiError, type Book, type User } from "./api";
import Auth from "./pages/Auth";
import Home from "./pages/Home";
import Record from "./pages/Record";
import AccountDetail from "./pages/AccountDetail";
import Assets from "./pages/Assets";
import Analytics from "./pages/Analytics";
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
  const nav = useNavigate();

  async function reload() {
    const u = await api.get<User>("/api/me");
    setUser(u);
    setBooks(await api.get<Book[]>("/api/books"));
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
      if (document.visibilityState === "visible") refreshQuotes().catch(() => {});
    }
    document.addEventListener("visibilitychange", onFg);
    window.addEventListener("focus", onFg);
    return () => {
      document.removeEventListener("visibilitychange", onFg);
      window.removeEventListener("focus", onFg);
    };
  }, [refreshQuotes]);

  if (user === undefined) return <div className="empty muted">載入中…</div>;
  if (!user) {
    return (
      <Routes>
        <Route path="/register" element={<Auth mode="register" onAuthed={reload} />} />
        <Route path="*" element={<Auth mode="login" onAuthed={reload} />} />
      </Routes>
    );
  }

  const ctx: Ctx = { user, books, book: active, reload, selectBook, quoteFailed, quoteFailedSymbols, refreshQuotes };
  const hideChrome = loc.pathname === "/record" || loc.pathname.startsWith("/opening");

  return (
    <div className={`app${hideChrome ? " hide-chrome" : ""}`}>
      <Routes>
        <Route path="/opening" element={<Opening ctx={ctx} />} />
        <Route path="/record" element={<Record ctx={ctx} asSheet />} />
        <Route path="/accounts/:id" element={<AccountDetail ctx={ctx} />} />
        <Route path="/accounts" element={<Navigate to="/assets" replace />} />
        <Route path="/invest/:id" element={<PositionDetail ctx={ctx} />} />
        <Route path="/invest" element={<Navigate to="/assets" replace />} />
        <Route path="/assets" element={<Assets ctx={ctx} />} />
        <Route path="/analytics" element={<Analytics ctx={ctx} />} />
        <Route path="/settings" element={<Settings ctx={ctx} onLogout={() => setUser(null)} />} />
        <Route path="/day/:date" element={<DayLedger ctx={ctx} />} />
        <Route path="/" element={<Home ctx={ctx} />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
      {!hideChrome && (
        <>
          <button type="button" className="fab-btn" aria-label="記一筆" onClick={() => nav("/record")}>
            ＋
          </button>
          <Nav path={loc.pathname} />
        </>
      )}
    </div>
  );
}

function Nav({ path }: { path: string }) {
  const items = [
    { to: "/", label: "帳本", ico: "📒" },
    { to: "/analytics", label: "分析圖", ico: "📊" },
    { to: "/assets", label: "資產", ico: "💼" },
    { to: "/settings", label: "設定", ico: "⚙️" },
  ];
  return (
    <nav className="nav">
      {items.map((it) => {
        const on = it.to === "/" ? path === "/" : path === it.to || path.startsWith(it.to + "/");
        return (
          <Link key={it.to} to={it.to} className={on ? "on" : ""}>
            <span className="nav-ico" aria-hidden>{it.ico}</span>
            {it.label}
          </Link>
        );
      })}
    </nav>
  );
}
