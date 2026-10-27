import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/data/database.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/services/analytics_agg.dart';
import 'package:full_jizhang/services/money.dart';

import 'rules/harness.dart';

// Aggregation for the 分析 line and pie.
//
// Purpose: the line is booked expense / income per day (month) or per
// month (year). Transfers and opening_balance never add. The pie is
// expense by category, with 未分類 and percents that sum to 100.

Entry _entry({
  required String date,
  required String type,
  required int amount,
  String? categoryId,
  String? toAccountId,
}) {
  return Entry(
    id: '$type-$date-$amount-${categoryId ?? ''}',
    bookId: 'b',
    date: date,
    type: type,
    amount: amount,
    accountId: 'a',
    toAccountId: toAccountId,
    categoryId: categoryId,
    note: '',
    createdAt: '',
    version: 1,
  );
}

void main() {
  test('per-day sums skip transfers and opening_balance', () {
    final points = recordedAmountsByDay(
      entries: [
        _entry(date: '2026-01-02', type: 'expense', amount: 100, categoryId: 'food'),
        _entry(date: '2026-01-02', type: 'expense', amount: 40, categoryId: 'food'),
        _entry(date: '2026-01-02', type: 'transfer', amount: 500, toAccountId: 'a2'),
        _entry(date: '2026-01-02', type: 'opening_balance', amount: 10000),
        _entry(date: '2026-01-03', type: 'income', amount: 200, categoryId: 'pay'),
        _entry(date: '2026-01-04', type: 'expense', amount: 10, categoryId: 'food'),
      ],
      from: '2026-01-01',
      to: '2026-01-04',
    );
    expect(points.map((p) => p.period).toList(), [
      '2026-01-01',
      '2026-01-02',
      '2026-01-03',
      '2026-01-04',
    ]);
    expect(points[0].expense, 0);
    expect(points[0].income, 0);
    expect(points[1].expense, 140);
    expect(points[1].income, 0);
    expect(points[2].expense, 0);
    expect(points[2].income, 200);
    expect(points[3].expense, 10);
  });

  test('per-month sums skip transfers and opening_balance', () {
    final points = recordedAmountsByMonth(
      entries: [
        _entry(date: '2026-01-15', type: 'expense', amount: 300, categoryId: 'food'),
        _entry(date: '2026-01-20', type: 'income', amount: 1000, categoryId: 'pay'),
        _entry(date: '2026-01-20', type: 'transfer', amount: 50, toAccountId: 'a2'),
        _entry(date: '2026-01-01', type: 'opening_balance', amount: 8000),
        _entry(date: '2026-02-03', type: 'expense', amount: 70, categoryId: 'food'),
        _entry(date: '2026-03-01', type: 'expense', amount: 9, categoryId: 'food'),
      ],
      fromMonth: '2026-01',
      toMonth: '2026-03',
    );
    expect(points.map((p) => p.period).toList(), [
      '2026-01',
      '2026-02',
      '2026-03',
    ]);
    expect(points[0].expense, 300);
    expect(points[0].income, 1000);
    expect(points[1].expense, 70);
    expect(points[1].income, 0);
    expect(points[2].expense, 9);
  });

  test('roll-up of daily points is monthly booked amounts', () {
    final monthly = rollUpDailyPointsByMonth([
      const DailyPoint(date: '2026-01-01', expense: 10, income: 0, cashNet: 100),
      const DailyPoint(date: '2026-01-02', expense: 5, income: 20, cashNet: 115),
      const DailyPoint(date: '2026-02-01', expense: 8, income: 0, cashNet: 107),
    ]);
    expect(monthly.length, 2);
    expect(monthly[0].date, '2026-01-01');
    expect(monthly[0].expense, 15);
    expect(monthly[0].income, 20);
    expect(monthly[0].cashNet, 115);
    expect(monthly[1].expense, 8);
    expect(monthly[1].income, 0);
  });

  test('category grouping uses 未分類 and percents sum to 100', () {
    final slices = expenseCategorySlices(
      entries: [
        _entry(date: '2026-01-02', type: 'expense', amount: 100, categoryId: 'food'),
        _entry(date: '2026-01-03', type: 'expense', amount: 50, categoryId: 'food'),
        _entry(date: '2026-01-03', type: 'expense', amount: 50),
        _entry(date: '2026-01-04', type: 'expense', amount: 1, categoryId: 'fun'),
        _entry(date: '2026-01-04', type: 'transfer', amount: 999, toAccountId: 'a2'),
        _entry(date: '2026-01-01', type: 'opening_balance', amount: 8000),
        _entry(date: '2026-01-05', type: 'income', amount: 400, categoryId: 'pay'),
        _entry(date: '2025-12-31', type: 'expense', amount: 80, categoryId: 'food'),
      ],
      categoryNames: {'food': '餐飲', 'fun': '娛樂', 'pay': '薪資'},
      from: '2026-01-01',
      to: '2026-01-31',
    );
    expect(slices.map((s) => s.name).toList(), ['餐飲', '未分類', '娛樂']);
    expect(slices.map((s) => s.amount).toList(), [150, 50, 1]);
    expect(slices.map((s) => s.categoryId).toList(), [
      'food',
      uncategorizedCategoryId,
      'fun',
    ]);
    expect(slices.fold<int>(0, (sum, s) => sum + s.percent), 100);
    expect(slices.first.percent, greaterThan(slices.last.percent));
  });

  test('largest remainder percents always total 100', () {
    expect(percentagesTotaling100(const []), isEmpty);
    expect(percentagesTotaling100(const [0, 0]), [0, 0]);
    expect(percentagesTotaling100(const [100]), [100]);
    expect(percentagesTotaling100(const [1, 1, 1]).fold<int>(0, (a, b) => a + b), 100);
    expect(percentagesTotaling100(const [2, 1]).fold<int>(0, (a, b) => a + b), 100);
    expect(percentagesTotaling100(const [1, 1, 1, 1]).fold(0, (a, b) => a + b), 100);
  });

  group('SQLite statsDaily / statsByCategory', () {
    late Harness h;
    setUp(() async {
      h = Harness();
      await h.setUp();
    });
    tearDown(() async => h.tearDown());

    test('statsDaily expense and income ignore transfer and opening', () async {
      final book = await h.book('生活');
      final cash = await h.cash(book.id);
      final bank = await h.api.createAccount(
        bookId: book.id,
        name: '銀行',
        type: 'bank',
      );
      await h.api.putOpening(
        bookId: book.id,
        body: {
          'opening_date': '2026-01-01',
          'accounts': [
            {'account_id': cash.id, 'amount': 10000},
          ],
        },
      );
      final cat = await h.expenseCat(book.id);
      await h.api.createEntry(
        body: {
          'book_id': book.id,
          'type': 'expense',
          'amount': 300,
          'account_id': cash.id,
          'date': '2026-01-15',
          'category_id': cat,
        },
        idempotencyKey: newIdempotencyKey(),
      );
      await h.api.createEntry(
        body: {
          'book_id': book.id,
          'type': 'transfer',
          'amount': 500,
          'account_id': cash.id,
          'to_account_id': bank.id,
          'date': '2026-01-15',
        },
        idempotencyKey: newIdempotencyKey(),
      );
      final daily = await h.api.statsDaily(
        bookId: book.id,
        from: '2026-01-01',
        to: '2026-01-15',
      );
      final openingDay = daily.firstWhere((p) => p.date == '2026-01-01');
      expect(openingDay.expense, 0);
      expect(openingDay.income, 0);
      final spendDay = daily.firstWhere((p) => p.date == '2026-01-15');
      expect(spendDay.expense, 300);
      expect(spendDay.income, 0);

      final monthly = rollUpDailyPointsByMonth(daily);
      final jan = monthly.firstWhere((p) => p.date.startsWith('2026-01'));
      expect(jan.expense, 300);
      expect(jan.income, 0);
    });

    test('statsByCategory groups 未分類 and skips transfers', () async {
      final book = await h.book('分類帳');
      final cash = await h.cash(book.id);
      final bank = await h.api.createAccount(
        bookId: book.id,
        name: '銀行',
        type: 'bank',
      );
      await h.api.putOpening(
        bookId: book.id,
        body: {
          'opening_date': '2026-01-01',
          'accounts': [
            {'account_id': cash.id, 'amount': 5000},
          ],
        },
      );
      final cat = await h.expenseCat(book.id);
      await h.api.createEntry(
        body: {
          'book_id': book.id,
          'type': 'expense',
          'amount': 80,
          'account_id': cash.id,
          'date': '2026-03-02',
          'category_id': cat,
        },
        idempotencyKey: newIdempotencyKey(),
      );
      await h.api.createEntry(
        body: {
          'book_id': book.id,
          'type': 'transfer',
          'amount': 40,
          'account_id': cash.id,
          'to_account_id': bank.id,
          'date': '2026-03-02',
        },
        idempotencyKey: newIdempotencyKey(),
      );
      final ts = nowIso();
      await h.db.into(h.db.entries).insert(
        EntriesCompanion.insert(
          id: newId(),
          bookId: book.id,
          date: '2026-03-03',
          type: 'expense',
          amount: 20,
          accountId: cash.id,
          note: const Value('無分類'),
          createdAt: ts,
          updatedAt: ts,
        ),
      );
      final slices = await h.api.statsByCategory(
        bookId: book.id,
        month: '2026-03',
      );
      expect(slices.map((s) => s.amount).toList(), [80, 20]);
      expect(slices.last.name, uncategorizedCategoryName);
      expect(slices.last.categoryId, uncategorizedCategoryId);
      final percents = percentagesTotaling100(
        [for (final slice in slices) slice.amount],
      );
      expect(percents.fold<int>(0, (a, b) => a + b), 100);

      final yearSlices = await h.api.statsByCategory(
        bookId: book.id,
        from: '2026-01-01',
        to: '2026-12-31',
      );
      expect(yearSlices.fold<int>(0, (a, s) => a + s.amount), 100);
    });
  });
}
