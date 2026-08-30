import { useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../api";

export default function Auth({ mode, onAuthed }: { mode: "login" | "register"; onAuthed: () => Promise<void> }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  const isReg = mode === "register";

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr("");
    setBusy(true);
    try {
      await api.post(isReg ? "/api/register" : "/api/login", { email, password });
      await onAuthed();
    } catch (ex: any) {
      setErr(ex.message || "失敗");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="auth">
      <h1>Full 記帳</h1>
      <p className="muted">{isReg ? "註冊一個帳號開始記帳" : "登入後才能看帳、記帳"}</p>
      <form onSubmit={submit}>
        <div className="field">
          <label>Email</label>
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="username" />
        </div>
        <div className="field">
          <label>密碼{isReg ? "（至少 8 碼）" : ""}</label>
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required minLength={isReg ? 8 : 1} autoComplete={isReg ? "new-password" : "current-password"} />
        </div>
        {err && <div className="error">{err}</div>}
        <button className="btn block" disabled={busy}>{busy ? "請稍候…" : isReg ? "註冊" : "登入"}</button>
      </form>
      <p className="muted" style={{ marginTop: 16 }}>
        {isReg ? (
          <>已有帳號？<Link to="/login">登入</Link></>
        ) : (
          <>還沒帳號？<Link to="/register">註冊</Link></>
        )}
      </p>
    </div>
  );
}
