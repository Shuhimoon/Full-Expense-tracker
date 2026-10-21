import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';

import 'harness.dart';

/// Books, the opening-date guard, and net worth.
///
/// Trades before the opening day are rejected (`trades.go`, same message as
/// entries). Duplicate active book names are 409 (`books.go`). `statsSummary`
/// / `statsDaily` / `statsByCategory` follow `stats.go`: month expense and
/// income, cash net with the opening balance included, and net worth equal
/// to cash plus position market value. A position with no quote is marked
/// at cost and `somePositionsUnquoted` is set (`positionMark`).
void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.setUp();
  });
  tearDown(() async => h.tearDown());

  test('trades dated before opening date are rejected', () async {
    final book = await h.book('投資');
    final acc = await h.broker(book.id);
    await expectLater(
      h.api.createTrade(
        body: {
          'book_id': book.id,
          'date': '2000-01-01',
          'account_id': acc.id,
          'symbol': '2330',
          'asset_class': 'tw_stock',
          'side': 'buy',
          'qty': '1',
          'price': '100',
          'price_ccy': 'TWD',
        },
        idempotencyKey: newIdempotencyKey(),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          '不能記開帳日之前的帳',
        ),
      ),
    );
  });

  test('stats summary daily and expense-by-category', () async {
    final book = await h.book('生活');
    final acc = await h.cash(book.id);
    await h.api.putOpening(
      bookId: book.id,
      body: {
        'opening_date': '2026-01-01',
        'accounts': [
          {'account_id': acc.id, 'amount': 10000},
        ],
      },
    );
    final cat = await h.expenseCat(book.id);
    await h.api.createEntry(
      body: {
        'book_id': book.id,
        'type': 'expense',
        'amount': 300,
        'account_id': acc.id,
        'date': '2026-01-15',
        'category_id': cat,
      },
      idempotencyKey: newIdempotencyKey(),
    );
    await h.api.createEntry(
      body: {
        'book_id': book.id,
        'type': 'income',
        'amount': 1000,
        'account_id': acc.id,
        'date': '2026-01-20',
        'category_id': (await h.api.listCategories(book.id))
            .firstWhere((c) => c.kind == 'income')
            .id,
      },
      idempotencyKey: newIdempotencyKey(),
    );
    final summary = await h.api.statsSummary(bookId: book.id, month: '2026-01');
    expect(summary.monthExpense, 300);
    expect(summary.monthIncome, 1000);
    expect(summary.cashNet, 10700);
    expect(summary.netWorth, 10700);

    final daily = await h.api.statsDaily(
      bookId: book.id,
      from: '2026-01-15',
      to: '2026-01-20',
    );
    expect(daily.length, 6);
    expect(daily.first.expense, 300);
    expect(daily.last.income, 1000);

    final slices = await h.api.statsByCategory(
      bookId: book.id,
      month: '2026-01',
    );
    expect(slices.length, 1);
    expect(slices.first.amount, 300);
  });

  test('duplicate active book name is rejected', () async {
    await h.book('生活');
    await expectLater(
      h.book('生活'),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', '已有同名帳本'),
      ),
    );
  });

  test('net worth for 資產 includes cash and unquoted positions at cost', () async {
    final book = await h.book('資產帳');
    final cash = await h.cash(book.id);
    final broker = await h.broker(book.id);
    await h.api.putOpening(
      bookId: book.id,
      body: {
        'opening_date': '2026-01-01',
        'accounts': [
          {'account_id': cash.id, 'amount': 1000},
        ],
        'positions': [
          {
            'account_id': broker.id,
            'symbol': '2330',
            'name': '台積電',
            'asset_class': 'tw_stock',
            'quote_currency': 'TWD',
            'qty': '2',
            'cost_twd': '400',
          },
        ],
      },
    );
    final summary = await h.api.statsSummary(bookId: book.id, month: '2026-01');
    expect(summary.cashNet, 1000);
    expect(summary.positionMv, 400);
    expect(summary.netWorth, 1400);
    expect(summary.somePositionsUnquoted, isTrue);
    final accs = await h.api.listAccounts(book.id);
    final br = accs.firstWhere((a) => a.id == broker.id);
    expect(br.positionMv, 400);
  });
}
