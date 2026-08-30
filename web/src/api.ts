export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

function newKey(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

async function req<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  if (init.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  if (init.method && init.method !== "GET" && !headers.has("Idempotency-Key")) {
    headers.set("Idempotency-Key", newKey());
  }
  const res = await fetch(path, { ...init, headers, credentials: "include" });
  const text = await res.text();
  let data: any = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = { error: text };
    }
  }
  if (!res.ok) {
    throw new ApiError(res.status, data?.error || "請求失敗");
  }
  return data as T;
}

export const api = {
  get: <T>(path: string) => req<T>(path),
  post: <T>(path: string, body?: unknown) =>
    req<T>(path, { method: "POST", body: body ? JSON.stringify(body) : undefined }),
  put: <T>(path: string, body?: unknown) =>
    req<T>(path, { method: "PUT", body: body ? JSON.stringify(body) : undefined }),
  patch: <T>(path: string, body?: unknown) =>
    req<T>(path, { method: "PATCH", body: body ? JSON.stringify(body) : undefined }),
  del: <T>(path: string, body?: unknown) =>
    req<T>(path, { method: "DELETE", body: body ? JSON.stringify(body) : undefined }),
};

export type User = { id: string; email: string; last_book_id: string | null; created_at: string };
export type Book = {
  id: string;
  name: string;
  archived_at: string | null;
  opening_date: string | null;
  opening_locked: boolean;
  version: number;
};
export type Account = {
  id: string;
  name: string;
  type: string;
  archived_at: string | null;
  version: number;
  cash_balance: number;
  position_mv?: number | null;
};
export type Category = {
  id: string;
  name: string;
  kind: "income" | "expense";
  is_system: boolean;
  archived_at: string | null;
  version: number;
};
export type Entry = {
  id: string;
  date: string;
  type: string;
  amount: number;
  account_id: string;
  to_account_id?: string | null;
  category_id?: string | null;
  note: string;
  created_at?: string;
  version: number;
};
export type Daily = { date: string; expense: number; income: number; cash_net: number };
export type Summary = {
  today_expense: number;
  month_expense: number;
  month_income: number;
  net_worth: number;
  net_worth_change_vs_opening: number;
  cash_net: number;
  position_mv: number;
  unrealized: number;
  quote_as_of?: string | null;
  some_positions_unquoted: boolean;
  today: string;
};
