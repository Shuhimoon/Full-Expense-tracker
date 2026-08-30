export function money(n: number | null | undefined): string {
  if (n === null || n === undefined || Number.isNaN(n)) return "—";
  const neg = n < 0;
  const abs = Math.abs(Math.round(n));
  const s = abs.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return (neg ? "−" : "") + s;
}

export function ntd(n: number | null | undefined): string {
  if (n === null || n === undefined || Number.isNaN(n)) return "—";
  return "NT$" + money(n);
}

export function shortAmt(n: number): string {
  if (!n) return "";
  const abs = Math.abs(n);
  if (abs > 9999) {
    const w = abs / 10000;
    const t = w >= 10 ? w.toFixed(0) : w.toFixed(1).replace(/\.0$/, "");
    return (n < 0 ? "−" : "") + t + "萬";
  }
  return money(n);
}

export function todayISO(): string {
  const p = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Taipei",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  return p;
}

export function ym(d = new Date()): string {
  return todayISO().slice(0, 7);
}

export function pad2(n: number): string {
  return n < 10 ? "0" + n : String(n);
}

export const ACCOUNT_TYPES: { id: string; label: string }[] = [
  { id: "cash", label: "現金" },
  { id: "bank", label: "銀行活存" },
  { id: "credit_card", label: "信用卡" },
  { id: "broker", label: "券商" },
  { id: "exchange", label: "交易所／錢包" },
];

export function typeLabel(t: string): string {
  return ACCOUNT_TYPES.find((x) => x.id === t)?.label ?? t;
}
