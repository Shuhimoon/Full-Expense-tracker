import 'package:decimal/decimal.dart';
import 'package:full_jizhang/format.dart';
import 'package:uuid/uuid.dart';

// Decimal, date, and id helpers shared by LocalApi and the opening replay.
// Amounts that hit the database as integers are TWD rounded with [round0],
// matching Go's decimal.Round(0).IntPart(). Dates are `YYYY-MM-DD` strings
// compared lexicographically, the same way `entries.go` and `opening.go`
// compare opening dates. The calendar day itself is Asia/Taipei via
// `format.dart` `taipeiToday` (Go: `now() AT TIME ZONE 'Asia/Taipei'`).

const uuid = Uuid();

/// New UUID, used as a row id and as a client idempotency key.
String newId() => uuid.v4();

/// UTC timestamp stored in `created_at` / `updated_at` columns.
String nowIso([DateTime? clock]) =>
    (clock ?? DateTime.now()).toUtc().toIso8601String();

final taipeiRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// True for a calendar day `YYYY-MM-DD`. Time-of-day strings are rejected.
bool isIsoDateStr(String value) => taipeiRe.hasMatch(value);

/// Parses a decimal quantity, price, or cost. Callers validate the sign.
Decimal dec(String raw) => Decimal.parse(raw);

/// [dec] that treats null and blank as zero (missing quote or cost).
Decimal decOrZero(String? raw) {
  if (raw == null || raw.trim().isEmpty) return Decimal.zero;
  return Decimal.parse(raw.trim());
}

/// Nearest TWD integer. Ports Go `decimal.Round(0).IntPart()` for realized
/// P&L, proceeds, and mark-to-market.
int round0(Decimal value) => value.round().toBigInt().toInt();

/// Integer TWD as a decimal, for moving-average arithmetic.
Decimal dInt(int value) => Decimal.fromInt(value);

/// Moving-average unit cost. Zero divisor returns zero so an empty lot
/// does not throw during a sell or transfer replay (`opening.go` fold).
Decimal div(Decimal a, Decimal b) {
  if (b == Decimal.zero) return Decimal.zero;
  return (a / b).toDecimal(scaleOnInfinitePrecision: 28);
}

/// Trade and opening quantities must be strictly positive (`trades.go`).
bool qtyPositive(Decimal qty) => qty > Decimal.zero;

/// First 10 characters when they are `YYYY-MM-DD`, otherwise null.
String? parseDateOrNull(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (!isIsoDateStr(s.length >= 10 ? s.substring(0, 10) : s)) return null;
  return s.substring(0, 10);
}

/// Date prefix. Opening dates and backup timestamps may carry a time.
String asDate(String s) {
  s = s.trim();
  if (s.length >= 10 && s[4] == '-' && s[7] == '-') return s.substring(0, 10);
  return s;
}

/// Day before [s]. Daily stats start the running cash balance here
/// (`stats.go` `handleStatsDaily`).
String prevDay(String s) {
  final parts = s.split('-');
  if (parts.length < 3) return s;
  final dt = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  final prev = dt.subtract(const Duration(days: 1));
  return '${prev.year}-${pad2(prev.month)}-${pad2(prev.day)}';
}

/// First day of `YYYY-MM`. Summary sums use `[monthStart, monthEndExclusive)`.
String monthStart(String month) => '$month-01';

/// First day of the next month, exclusive end of a stats month.
String monthEndExclusive(String month) {
  final parts = month.split('-');
  var year = int.parse(parts[0]);
  var m = int.parse(parts[1]);
  m += 1;
  if (m > 12) {
    m = 1;
    year += 1;
  }
  return '$year-${pad2(m)}-01';
}

/// JSON number or numeric string as an int. Anything else is 0.
int asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// JSON value as a string. Null becomes empty.
String asStr(Object? value) => value?.toString() ?? '';

/// JSON value as a string, or null when missing, blank, or the literal `null`.
String? asStrN(Object? value) {
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty || s == 'null' ? null : s;
}

/// Default income names. Same list as `app.go` `seedCategories`.
const incomeSeed = ['薪資', '獎金', '股利', '利息', '其他'];
/// Default expense names, including 投資費用 used for transfer fees.
const expenseSeed = [
  '餐飲',
  '交通',
  '居住',
  '日用',
  '訂閱',
  '醫療',
  '娛樂',
  '學習',
  '人情',
  '投資費用',
  '其他',
];

/// HTTP 422 body from `opening.go` when a replayed sell or transfer would
/// drive a holding below zero. The PUT that triggered the replay rolls back.
const msgNegativeHolding = '修改後持倉會變負數';

/// True when SQLite rejected a partial unique index (active book or account name).
/// Mapped to 409 the way `books.go` / `accounts.go` map Postgres unique violations.
bool looksUniqueViolation(Object error) {
  final s = error.toString().toLowerCase();
  return s.contains('unique') ||
      s.contains('constraint failed') ||
      s.contains('2067');
}
