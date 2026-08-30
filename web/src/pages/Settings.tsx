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
    api.get<Category[]>(`/api/categories?book_id=${book.id}`).then(setCats);
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
      <div className="list-item" key={b.id} style={{ flexWrap: "wrap", gap: 6 }}>
        <span>{b.name}{b.id === book?.id ? "（目前）" : ""}</span>
        <span style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
          {!archivedRow && b.id !== book?.id && (
            <button className="btn ghost" onClick={() => switchTo(b)}>切換</button>
          )}
          {!archivedRow && <button className="btn ghost" onClick={() => rename(b)}>改名</button>}
          {!archivedRow && <button className="btn ghost" onClick={() => archive(b)}>封存</button>}
          {archivedRow && <button className="btn ghost" onClick={() => unarchive(b)}>取消封存</button>}
          <button className="btn ghost" onClick={() => del(b)}>刪除</button>
        </span>
      </div>
    );
  }

  return (
    <>
      <BookBar ctx={ctx} />
      <div className="card">
        <strong>帳本</strong>
        <p className="muted">未封存／已封存分組。封存中不能記帳、不能開帳、不能寫入。頂欄切換器只列未封存。</p>
        <div className="muted" style={{ marginTop: 8 }}>未封存</div>
        {live.length === 0 && <div className="muted">尚無</div>}
        {live.map((b) => bookRow(b, false))}
        {archived.length > 0 && <div className="muted" style={{ marginTop: 12 }}>已封存</div>}
        {archived.map((b) => bookRow(b, true))}
        <div className="field">
          <label>新增帳本（必填名稱）</label>
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder="生活" />
        </div>
        <button className="btn" onClick={addBook}>新增</button>
      </div>
      <div className="card">
        <strong>開帳</strong>
        <p className="muted">{book?.opening_locked ? `已鎖定 ${book.opening_date}` : "尚未鎖定"}</p>
        <button className="btn ghost" onClick={() => nav("/opening")}>開帳設定</button>
      </div>
      <div className="card">
        <strong>分類</strong>
        {cats.filter((c) => !c.archived_at).map((c) => (
          <div className="list-item" key={c.id}>
            <span>{c.kind === "income" ? "收" : "支"} {c.name}{c.is_system ? "（系統）" : ""}</span>
          </div>
        ))}
      </div>
      <div className="card">
        <strong>備份</strong>
        <p className="muted">匯出／還原只針對當前這本。JSON 不是資料庫。</p>
        <button className="btn ghost" onClick={exportBook}>匯出 JSON</button>
        <input type="file" accept="application/json" onChange={(e) => e.target.files && importBook(e.target.files[0])} />
      </div>
      <div className="card">
        <strong>帳號</strong>
        <p>{ctx.user.email}</p>
        <div className="field"><label>舊密碼</label><input type="password" value={oldPw} onChange={(e) => setOldPw(e.target.value)} /></div>
        <div className="field"><label>新密碼</label><input type="password" value={newPw} onChange={(e) => setNewPw(e.target.value)} /></div>
        <button className="btn ghost" onClick={changePw}>改密碼</button>
        <button className="btn" onClick={logout} style={{ marginLeft: 8 }}>登出</button>
      </div>
      <div className="card">
        <strong>關於</strong>
        <p>基準幣 TWD（寫死）。成本法：移動平均。正本在 PostgreSQL。時區 Asia/Taipei。</p>
      </div>
      {msg && <div className="card">{msg}</div>}
      {err && <div className="error">{err}</div>}
    </>
  );
}
