import { useState } from "react";
import { Link } from "react-router-dom";
import type { Ctx } from "../App";

export default function BookBar({ ctx, extra }: { ctx: Ctx; extra?: React.ReactNode }) {
  const [open, setOpen] = useState(false);
  const book = ctx.book;
  const active = ctx.books.filter((b) => !b.archived_at);
  return (
    <div className="topbar">
      <button
        className="book"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-haspopup="menu"
      >
        {book?.name || "選擇帳本"} <span className="chevron" aria-hidden="true">▾</span>
      </button>
      {extra}
      {open && (
        <div className="switcher">
          {active.map((b) => (
            <button
              key={b.id}
              className={b.id === book?.id ? "active" : undefined}
              aria-pressed={b.id === book?.id}
              onClick={async () => {
                setOpen(false);
                if (b.id !== book?.id) await ctx.selectBook(b.id);
              }}
            >
              <span>{b.name}</span>
              {b.id === book?.id && <span className="switcher-check" aria-hidden="true">✓</span>}
            </button>
          ))}
          <Link to="/settings" onClick={() => setOpen(false)}>管理帳本</Link>
        </div>
      )}
    </div>
  );
}
