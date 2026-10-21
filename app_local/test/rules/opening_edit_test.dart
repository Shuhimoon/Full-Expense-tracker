import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';

import 'harness.dart';

void numEq(dynamic got, String want) {
  final g = Decimal.parse('$got');
  final w = Decimal.parse(want);
  expect(g, w);
}

/// Port of `api/internal/app/opening_edit_test.go`.
///
/// `putOpening` replays the opening lot and later trades in date order with
/// moving-average cost (`opening.go` `rebuildPositions`). Changing the
/// opening cost recomputes the remaining cost and the sell's realized P&L.
/// Shrinking the opening quantity so a later sell would go negative returns
/// 422 「修改後持倉會變負數」 and leaves positions and drafts unchanged,
/// because the replay runs inside the PUT transaction. Editing opening cash
/// after an expense recomputes the account balance (`applyOpening` replaces
/// `opening_balance` entries).
void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.setUp();
  });
  tearDown(() async => h.tearDown());

  test('TestOpeningEditAfterTradesRecomputesAvgCost', () async {
    final book = await h.book('投資');
    final acc = await h.broker(book.id);
    final opening = <String, dynamic>{
      'opening_date': '2026-01-01',
      'positions': [
        {
          'account_id': acc.id,
          'symbol': '2330',
          'name': '台積電',
          'asset_class': 'tw_stock',
          'quote_currency': 'TWD',
          'qty': '10',
          'cost_twd': '10000',
        },
      ],
    };
    await h.api.putOpening(bookId: book.id, body: opening);
    await h.api.createTrade(
      body: {
        'book_id': book.id,
        'date': '2026-02-01',
        'account_id': acc.id,
        'symbol': '2330',
        'asset_class': 'tw_stock',
        'quote_currency': 'TWD',
        'side': 'buy',
        'qty': '10',
        'price': '2000',
        'price_ccy': 'TWD',
        'fee_twd': 0,
      },
      idempotencyKey: newIdempotencyKey(),
    );
    await h.api.createTrade(
      body: {
        'book_id': book.id,
        'date': '2026-03-01',
        'account_id': acc.id,
        'symbol': '2330',
        'asset_class': 'tw_stock',
        'quote_currency': 'TWD',
        'side': 'sell',
        'qty': '4',
        'price': '1800',
        'price_ccy': 'TWD',
        'fee_twd': 0,
      },
      idempotencyKey: newIdempotencyKey(),
    );
    (opening['positions'] as List)[0]['cost_twd'] = '20000';
    await h.api.putOpening(bookId: book.id, body: opening);
    final poss = await h.api.listPositions(book.id);
    expect(poss.length, 1);
    numEq(poss[0].qty, '16');
    numEq(poss[0].costTwd, '32000');
    final avg = Decimal.parse(poss[0].costTwd) / Decimal.parse(poss[0].qty);
    numEq(avg.toString(), '2000');

    final trades = await h.api.listTrades(book.id);
    final sell = trades.firstWhere((t) => t['side'] == 'sell');
    numEq(sell['realized_twd'], '-800');
  });

  test('TestOpeningEditNegativeMidTimeline422', () async {
    final book = await h.book('負持倉');
    final acc = await h.broker(book.id);
    final opening = <String, dynamic>{
      'opening_date': '2026-01-01',
      'positions': [
        {
          'account_id': acc.id,
          'symbol': '2330',
          'name': '台積電',
          'asset_class': 'tw_stock',
          'quote_currency': 'TWD',
          'qty': '10',
          'cost_twd': '1000',
        },
      ],
    };
    await h.api.putOpening(bookId: book.id, body: opening);
    await h.api.createTrade(
      body: {
        'book_id': book.id,
        'date': '2026-02-01',
        'account_id': acc.id,
        'symbol': '2330',
        'asset_class': 'tw_stock',
        'quote_currency': 'TWD',
        'side': 'sell',
        'qty': '6',
        'price': '100',
        'price_ccy': 'TWD',
      },
      idempotencyKey: newIdempotencyKey(),
    );
    await h.api.createTrade(
      body: {
        'book_id': book.id,
        'date': '2026-03-01',
        'account_id': acc.id,
        'symbol': '2330',
        'asset_class': 'tw_stock',
        'quote_currency': 'TWD',
        'side': 'buy',
        'qty': '10',
        'price': '100',
        'price_ccy': 'TWD',
      },
      idempotencyKey: newIdempotencyKey(),
    );
    (opening['positions'] as List)[0]['qty'] = '4';
    try {
      await h.api.putOpening(bookId: book.id, body: opening);
      fail('expected 422');
    } on ApiException catch (e) {
      expect(e.status, 422);
      expect(e.message, '修改後持倉會變負數');
    }
    final poss = await h.api.listPositions(book.id);
    expect(poss.length, 1);
    numEq(poss[0].qty, '14');
    final drafts = await h.api.getOpening(book.id);
    expect(drafts.positionDrafts.length, 1);
    numEq(drafts.positionDrafts[0].qty, '10');
  });

  test('TestOpeningBalanceEditAfterEntriesRecomputesBalance', () async {
    final book = await h.book('現金帳');
    final acc = await h.cash(book.id);
    await h.api.putOpening(
      bookId: book.id,
      body: {
        'accounts': [
          {'account_id': acc.id, 'amount': 1000},
        ],
      },
    );
    await h.api.createEntry(
      body: {
        'book_id': book.id,
        'type': 'expense',
        'amount': 200,
        'account_id': acc.id,
        'date': todayTaipei(),
        'category_id': await h.expenseCat(book.id),
      },
      idempotencyKey: newIdempotencyKey(),
    );
    expect(await _cash(h, book.id, acc.id), 800);
    await h.api.putOpening(
      bookId: book.id,
      body: {
        'accounts': [
          {'account_id': acc.id, 'amount': 5000},
        ],
      },
    );
    expect(await _cash(h, book.id, acc.id), 4800);
  });
}

Future<int> _cash(Harness h, String bid, String aid) async {
  final accs = await h.api.listAccounts(bid);
  return accs.firstWhere((a) => a.id == aid).cashBalance;
}
