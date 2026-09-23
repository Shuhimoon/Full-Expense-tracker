import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import type { Ctx } from "../App";
import { api, ApiError, type Book, type Category } from "../api";
import BookBar from "../components/BookBar";

export default function Settings({ ctx, onLogout }: { ctx: Ctx; onLogout: () => void }) {
  const nav = useNavigate();
  const [name, setName] = useState("生活");
  const [cats, setCats] = useState<Category[]>([]);
  const [oldPw, setOldPw] = useState("");
  const [newPw, setNewPw] = useState("");
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");
  const book = ctx.book;

  useEffect(() => {
    if (!book) return;
    api.get<Category[]>(`/api/categories?book_id=${book.id}`).then(setCats).catch(() => {});
  }, [book?.id]);

  async function addBook() {
    setErr("");
    setMsg("");
    const n = name.trim();
    if (!n) {
      setErr("請填帳本名稱");
      return;
    }
    try {
      const b = await api.post<Book>("/api/books", { name: n });
      await ctx.selectBook(b.id);
      nav("/opening");
    } catch (e: any) {
      setErr(e.message);
    }
  }

  async function rename(b: Book) {
    setErr("");
    const n = window.prompt("帳本新名稱", b.name);
    if (n == null) return;
    const trimmed = n.trim();
    if (!trimmed) {
      setErr("名稱不能空");
      return;
    }
    try {
      await api.patch(`/api/books/${b.id}`, { name: trimmed, version: b.version });
      await ctx.reload();
      setMsg("已改名");
    } catch (e: any) {
      if (e instanceof ApiError && e.status === 409) {
        await ctx.reload();
        setErr("資料已被更新，請再試一次");
      } else {
        setErr(e.message);
      }
    }
  }

  async function archive(b: Book) {
    setErr("");
    try {
      await api.post(`/api/books/${b.id}/archive`);
      await ctx.reload();
    } catch (e: any) {
      setErr(e.message);
    }
  }

  async function unarchive(b: Book) {
    setErr("");
    try {
      await api.post(`/api/books/${b.id}/unarchive`);
      await ctx.reload();
    } catch (e: any) {
      setErr(e.message);
    }
  }

  async function switchTo(b: Book) {
    setErr("");
    try {
      await ctx.selectBook(b.id);
    } catch (e: any) {
      setErr(e.message);
    }
  }

  async function del(b: Book) {
    setErr("");
    if (!window.confirm(`刪除「${b.name}」？只有沒有帳戶或分錄的帳本才能刪，否則請改封存。`)) return;
    try {
      await api.del(`/api/books/${b.id}`);
      await ctx.reload();
      setMsg("已刪除");
    } catch (e: any) {
      setErr(e.message || "帳本還有帳戶或分錄，只能封存");
    }
  }

  async function logout() {
    await api.post("/api/logout");
    onLogout();
  }

  async function changePw() {
    setErr("");
    try {
      await api.post("/api/password", { old: oldPw, new: newPw });
      setMsg("密碼已更新");
      setOldPw("");
      setNewPw("");
    } catch (e: any) {
      setErr(e.message);
    }
  }

  async function exportBook() {
    if (!book) return;
    const data = await api.get<any>(`/api/books/${book.id}/export`);
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `${book.name}-backup.json`;
    a.click();
  }

  async function importBook(file: File) {
    if (!book) return;
    setErr("");
    try {
      const text = await file.text();
      const data = JSON.parse(text);
      await api.post(`/api/books/${book.id}/import`, data);
      await ctx.reload();
      setMsg("已還原");
    } catch (e: any) {
      setErr(e.message || "還原失敗");
    }
  }

  const live = ctx.books.filter((b) => !b.archived_at);
  const archived = ctx.books.filter((b) => b.archived_at);

  function bookRow(b: Book, archivedRow: boolean) {
    return (
      <div className="settings-row" key={b.id}>
        <div className="settings-ico" aria-hidden>
          📒
        </div>
        <div className="settings-meta">
          <div className="settings-name">
            {b.name}
            {b.id === book?.id ? "（目前）" : ""}
          </div>
          <div className="settings-sub">{archivedRow ? "已封存" : b.opening_locked ? `已開帳 ${b.opening_date || ""}` : "尚未開帳"}</div>
        </div>
        <div className="settings-actions">
          {!archivedRow && b.id !== book?.id && (
            <button type="button" className="btn ghost sm" onClick={() => switchTo(b)}>
              切換
            </button>
          )}
          {!archivedRow && (
            <button type="button" className="btn ghost sm" onClick={() => rename(b)}>
              改名
            </button>
          )}
          {!archivedRow && (
            <button type="button" className="btn ghost sm" onClick={() => archive(b)}>
              封存
            </button>
          )}
          {archivedRow && (
            <button type="button" className="btn ghost sm" onClick={() => unarchive(b)}>
              取消封存
            </button>
          )}
          <button type="button" className="btn ghost sm" onClick={() => del(b)}>
            刪除
          </button>
        </div>
      </div>
    );
  }

  return (
    <>
      <BookBar ctx={ctx} />
      <div className="settings-page">
        <div className="settings-topbar">
          <h1>設定</h1>
        </div>

        <div className="settings-section-label">帳本</div>
        <div className="settings-group card">
          {live.length === 0 && <div className="muted" style={{ padding: "12px 14px" }}>尚無未封存帳本</div>}
          {live.map((b) => bookRow(b, false))}
          {archived.length > 0 && <div className="settings-divider-label">已封存</div>}
          {archived.map((b) => bookRow(b, true))}
          <div className="settings-add">
            <div className="field" style={{ margin: 0, flex: 1 }}>
              <label>新增帳本</label>
              <input value={name} onChange={(e) => setName(e.target.value)} placeholder="生活" />
            </div>
            <button type="button" className="btn" onClick={addBook}>
              新增
            </button>
          </div>
          <p className="hint" style={{ margin: "8px 14px 12px" }}>
            封存中不能記帳、不能開帳。頂欄切換器只列未封存。
          </p>
        </div>

        <div className="settings-section-label">開帳入口</div>
        <div className="settings-group card">
          <button type="button" className="settings-row linkish" onClick={() => nav("/opening")}>
            <div className="settings-ico" aria-hidden>
              🏁
            </div>
            <div className="settings-meta">
              <div className="settings-name">開始開帳</div>
              <div className="settings-sub">
                {book?.opening_locked
                  ? `已鎖定 ${book.opening_date || ""}`
                  : "選開帳日 → 帳戶餘額 → 現倉 → 鎖定"}
              </div>
            </div>
            <span className="settings-chev" aria-hidden>
              ›
            </span>
          </button>
        </div>

        <div className="settings-section-label">分類</div>
        <div className="settings-group card">
          <div className="settings-row">
            <div className="settings-ico" aria-hidden>
              🏷
            </div>
            <div className="settings-meta">
              <div className="settings-name">分類管理</div>
              <div className="settings-sub">支出 · 收入（含系統「股利」）</div>
            </div>
          </div>
          <div className="settings-cats">
            {cats.filter((c) => !c.archived_at).length === 0 && <div className="muted">尚無分類</div>}
            {cats
              .filter((c) => !c.archived_at)
              .map((c) => (
                <div className="settings-cat-chip" key={c.id}>
                  <span className="settings-cat-kind">{c.kind === "income" ? "收" : "支"}</span>
                  {c.name}
                  {c.is_system ? "（系統）" : ""}
                </div>
              ))}
          </div>
        </div>

        <div className="settings-section-label">備份</div>
        <div className="settings-group card">
          <div className="settings-row">
            <div className="settings-ico" aria-hidden>
              ☁️
            </div>
            <div className="settings-meta">
              <div className="settings-name">備份與還原</div>
              <div className="settings-sub">匯出／匯入 JSON（僅當前帳本）</div>
            </div>
          </div>
          <div className="settings-backup-actions">
            <button type="button" className="btn" onClick={exportBook} disabled={!book}>
              匯出 JSON
            </button>
            <label className="btn ghost file-btn">
              匯入還原
              <input
                type="file"
                accept="application/json"
                hidden
                onChange={(e) => e.target.files && importBook(e.target.files[0])}
              />
            </label>
          </div>
        </div>

        <div className="settings-section-label">帳號</div>
        <div className="settings-group card">
          <div className="settings-row">
            <div className="settings-ico" aria-hidden>
              👤
            </div>
            <div className="settings-meta">
              <div className="settings-name">{ctx.user.email}</div>
              <div className="settings-sub">登入帳號</div>
            </div>
          </div>
          <div className="settings-pw">
            <div className="field">
              <label>舊密碼</label>
              <input type="password" value={oldPw} onChange={(e) => setOldPw(e.target.value)} autoComplete="current-password" />
            </div>
            <div className="field">
              <label>新密碼</label>
              <input type="password" value={newPw} onChange={(e) => setNewPw(e.target.value)} autoComplete="new-password" />
            </div>
            <button type="button" className="btn ghost block" onClick={changePw}>
              更新密碼
            </button>
          </div>
          <button type="button" className="settings-row linkish danger" onClick={logout}>
            <div className="settings-ico danger" aria-hidden>
              ⤴
            </div>
            <div className="settings-meta">
              <div className="settings-name">登出</div>
            </div>
          </button>
        </div>

        <div className="settings-section-label">關於</div>
        <div className="settings-group card">
          <div className="settings-about">
            <p>基準幣 TWD（寫死）。成本法：移動平均。</p>
            <p>正本在 PostgreSQL。時區 Asia/Taipei。</p>
          </div>
        </div>

        {msg && (
          <div className="card" style={{ color: "var(--accent-d)", fontWeight: 600 }}>
            {msg}
          </div>
        )}
        {err && <div className="error">{err}</div>}
      </div>
    </>
  );
}
