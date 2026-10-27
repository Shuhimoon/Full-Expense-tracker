import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';

// Analytics series from real SQLite entries.
//
// Purpose: the 分析 line chart plots recorded expense (and income when
// that toggle is selected). The pie groups those expenses by category.
// This file is the rule for both the page and the unit tests, so a
// placeholder or a running cash balance cannot sneak in as "trend data".
//
// Rules enforced:
// - Only `expense` and `income` rows contribute to the line. `transfer`
//   and `opening_balance` are skipped, even if they sit in the same
//   table and the same day.
// - A selected month is one point per calendar day. A year (or a range
//   longer than a month) is one point per YYYY-MM, summing the days.
// - Pie slices are expense totals for the same period, one slice per
//   category. Null / empty category_id is grouped as 未分類.
// - Slice percentages are integers that sum to 100 (largest remainder).
//
// Key logic: callers pass the live rows (or the daily points already
// filtered by LocalApi.statsDaily). Nothing here reads cashNet.

/// Sentinel id for expenses that have no category row.
const uncategorizedCategoryId = '';

/// Legend label for [uncategorizedCategoryId].
const uncategorizedCategoryName = '未分類';

/// One point on the 分析 line: a day (`YYYY-MM-DD`) or a month (`YYYY-MM`).
class RecordedAmount {
  const RecordedAmount({
    required this.period,
    required this.expense,
    required this.income,
  });

  final String period;
  final int expense;
  final int income;
}

/// One pie slice after grouping. [percent] is 0–100; the list sums to 100.
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.percent,
  });

  final String categoryId;
  final String name;
  final int amount;
  final int percent;
}

/// Per-day expense and income totals for [[from], [to]] inclusive.
///
/// Rule: `transfer` and `opening_balance` do not add to either series.
/// Days with no matching rows still appear as zeros so the axis is the
/// whole selected month, not only the days that were booked.
List<RecordedAmount> recordedAmountsByDay({
  required Iterable<Entry> entries,
  required String from,
  required String to,
}) {
  final exp = <String, int>{};
  final inc = <String, int>{};
  for (final entry in entries) {
    if (entry.date.compareTo(from) < 0 || entry.date.compareTo(to) > 0) {
      continue;
    }
    if (entry.type == 'expense') {
      exp[entry.date] = (exp[entry.date] ?? 0) + entry.amount;
    } else if (entry.type == 'income') {
      inc[entry.date] = (inc[entry.date] ?? 0) + entry.amount;
    }
  }
  final out = <RecordedAmount>[];
  var cur = _utcDate(from);
  final last = _utcDate(to);
  while (!cur.isAfter(last)) {
    final date =
        '${cur.year}-${pad2(cur.month)}-${pad2(cur.day)}';
    out.add(
      RecordedAmount(
        period: date,
        expense: exp[date] ?? 0,
        income: inc[date] ?? 0,
      ),
    );
    cur = DateTime.utc(cur.year, cur.month, cur.day + 1);
  }
  return out;
}

/// Per-month expense and income totals for [[fromMonth], [toMonth]] inclusive.
///
/// Rule: same type filter as [recordedAmountsByDay]. Used when 分析 is
/// showing a year or a longer range, so the line is 12 (or fewer) points
/// of real booked amounts, not a daily running balance.
List<RecordedAmount> recordedAmountsByMonth({
  required Iterable<Entry> entries,
  required String fromMonth,
  required String toMonth,
}) {
  final from = '$fromMonth-01';
  final to = monthEnd(toMonth);
  return rollUpRecordedToMonths(
    recordedAmountsByDay(entries: entries, from: from, to: to),
  );
}

/// Sums daily points into `YYYY-MM` points, preserving month order.
///
/// Expense and income are added. This is how a year-long [statsDaily]
/// result becomes the year line without using cashNet.
List<RecordedAmount> rollUpRecordedToMonths(List<RecordedAmount> daily) {
  final sums = <String, RecordedAmount>{};
  final order = <String>[];
  for (final point in daily) {
    final month = point.period.length >= 7
        ? point.period.substring(0, 7)
        : point.period;
    final prev = sums[month];
    if (prev == null) {
      order.add(month);
      sums[month] = RecordedAmount(
        period: month,
        expense: point.expense,
        income: point.income,
      );
    } else {
      sums[month] = RecordedAmount(
        period: month,
        expense: prev.expense + point.expense,
        income: prev.income + point.income,
      );
    }
  }
  return [for (final month in order) sums[month]!];
}

/// Same roll-up on [DailyPoint] so 分析 can keep one list for the line.
///
/// Expense and income are summed. [DailyPoint.cashNet] on the result is
/// the last day's running cash in that month (the 現金淨資產 toggle only).
/// The 支出 / 收入 toggles read [expense] / [income] and never cashNet.
List<DailyPoint> rollUpDailyPointsByMonth(List<DailyPoint> daily) {
  final sums = <String, DailyPoint>{};
  final order = <String>[];
  for (final point in daily) {
    final month = point.date.length >= 7
        ? point.date.substring(0, 7)
        : point.date;
    final prev = sums[month];
    if (prev == null) {
      order.add(month);
      sums[month] = DailyPoint(
        date: '$month-01',
        expense: point.expense,
        income: point.income,
        cashNet: point.cashNet,
      );
    } else {
      sums[month] = DailyPoint(
        date: '$month-01',
        expense: prev.expense + point.expense,
        income: prev.income + point.income,
        cashNet: point.cashNet,
      );
    }
  }
  return [for (final month in order) sums[month]!];
}

/// Expense totals by category for [[from], [to]] inclusive.
///
/// Rule: only `expense` rows. Transfers and opening cash are skipped.
/// Missing category_id becomes 未分類. Zero groups are dropped. Amounts
/// sort descending. [CategorySlice.percent] values sum to 100.
List<CategorySlice> expenseCategorySlices({
  required Iterable<Entry> entries,
  required Map<String, String> categoryNames,
  String? from,
  String? to,
}) {
  final sums = <String, int>{};
  final names = <String, String>{};
  for (final entry in entries) {
    if (entry.type != 'expense') continue;
    if (from != null && entry.date.compareTo(from) < 0) continue;
    if (to != null && entry.date.compareTo(to) > 0) continue;
    final raw = entry.categoryId;
    final id = (raw == null || raw.isEmpty)
        ? uncategorizedCategoryId
        : raw;
    sums[id] = (sums[id] ?? 0) + entry.amount;
    names[id] = id == uncategorizedCategoryId
        ? uncategorizedCategoryName
        : (categoryNames[id] ?? uncategorizedCategoryName);
  }
  final ids = sums.keys.where((id) => (sums[id] ?? 0) > 0).toList()
    ..sort((a, b) => sums[b]!.compareTo(sums[a]!));
  final amounts = [for (final id in ids) sums[id]!];
  final percents = percentagesTotaling100(amounts);
  return [
    for (var i = 0; i < ids.length; i++)
      CategorySlice(
        categoryId: ids[i],
        name: names[ids[i]]!,
        amount: amounts[i],
        percent: percents[i],
      ),
  ];
}

/// Integer percents that sum to 100, using the largest remainder method.
///
/// Rule: an empty or all-zero list returns zeros (not 100 on a ghost
/// slice). Rounding each share independently can yield 99 or 101; this
/// assigns the leftover points to the largest remainders so the legend
/// always reads as a whole.
List<int> percentagesTotaling100(List<int> amounts) {
  if (amounts.isEmpty) return const [];
  final total = amounts.fold<int>(0, (sum, value) => sum + value);
  if (total <= 0) return List<int>.filled(amounts.length, 0);
  final exact = [for (final amount in amounts) amount * 100 / total];
  final floors = [for (final value in exact) value.floor()];
  var used = floors.fold<int>(0, (sum, value) => sum + value);
  final order = List<int>.generate(amounts.length, (i) => i)
    ..sort((a, b) {
      final rem = (exact[b] - floors[b]).compareTo(exact[a] - floors[a]);
      if (rem != 0) return rem;
      return amounts[b].compareTo(amounts[a]);
    });
  var i = 0;
  while (used < 100 && i < order.length) {
    floors[order[i]] += 1;
    used += 1;
    i += 1;
  }
  return floors;
}

DateTime _utcDate(String iso) {
  final parts = iso.split('-');
  return DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
