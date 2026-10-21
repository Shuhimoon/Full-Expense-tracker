import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/data/database.dart';
import 'package:full_jizhang/services/local_api.dart';
import 'package:full_jizhang/services/quotes.dart';

import 'harness.dart';

/// Always-failing sources, so refresh takes the manual FX fallback.
class FailingQuotes extends QuoteClient {
  FailingQuotes() : super();

  @override
  Future<Decimal> fetchUsdTwd() async => throw StateError('fx down');

  @override
  Future<(Decimal, String)> fetchQuote(String symbol, String assetClass) async {
    throw StateError('quote down');
  }
}

/// Fixed prices, so tests do not call the network.
class OkQuotes extends QuoteClient {
  OkQuotes() : super();

  @override
  Future<Decimal> fetchUsdTwd() async => Decimal.parse('32.1');

  @override
  Future<(Decimal, String)> fetchQuote(String symbol, String assetClass) async {
    return (Decimal.parse('900'), 'TWD');
  }
}

/// Quote refresh. Ports `quotes.go` `handleQuotesRefresh`.
///
/// When every source throws, FX is recorded as 「匯率」 and, with no prior
/// rate, stored as manual 32. The symbol is listed as failed and the
/// position stays marked at cost (`stats.go` `positionMark`). A locked
/// manual quote is not overwritten. An unlocked symbol takes the auto price.
void main() {
  setUpAll(openTestSqlite);

  test('quote failures fall back to manual default fx and leave positions unquoted', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final api = LocalApi(db, quotes: FailingQuotes());
    final book = await api.createBook(name: '報價');
    final broker = await api.createAccount(
      bookId: book.id,
      name: '券商',
      type: 'broker',
    );
    await api.putOpening(
      bookId: book.id,
      body: {
        'opening_date': '2026-01-01',
        'positions': [
          {
            'account_id': broker.id,
            'symbol': '2330',
            'name': '台積電',
            'asset_class': 'tw_stock',
            'quote_currency': 'TWD',
            'qty': '1',
            'cost_twd': '100',
          },
        ],
      },
    );
    final refresh = await api.refreshQuotes(book.id);
    expect(refresh.quoteFailed, isTrue);
    expect(refresh.message, '報價失敗');
    expect(refresh.failed, contains('匯率'));
    expect(refresh.failed, contains('2330'));

    final summary = await api.statsSummary(bookId: book.id);
    expect(summary.somePositionsUnquoted, isTrue);
    expect(summary.positionMv, 100);
  });

  test('successful auto quotes update market value; locked manual is kept', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final api = LocalApi(db, quotes: OkQuotes());
    final book = await api.createBook(name: '報價2');
    final broker = await api.createAccount(
      bookId: book.id,
      name: '券商',
      type: 'broker',
    );
    await api.putOpening(
      bookId: book.id,
      body: {
        'opening_date': '2026-01-01',
        'positions': [
          {
            'account_id': broker.id,
            'symbol': '2330',
            'asset_class': 'tw_stock',
            'quote_currency': 'TWD',
            'qty': '2',
            'cost_twd': '200',
          },
        ],
      },
    );
    final insts = await db.select(db.instruments).get();
    final iid = insts.first.id;
    await api.setManualQuote(
      instrumentId: iid,
      price: '50',
      ccy: 'TWD',
      locked: true,
    );
    final refresh = await api.refreshQuotes(book.id);
    expect(refresh.failed.contains('2330'), isFalse);
    final poss = await api.listPositions(book.id);
    expect(poss.single.marketValue, 100);
  });

  test('unlocked quotes are overwritten by auto fetch', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final api = LocalApi(db, quotes: OkQuotes());
    final book = await api.createBook(name: '報價3');
    final broker = await api.createAccount(
      bookId: book.id,
      name: '券商',
      type: 'broker',
    );
    await api.putOpening(
      bookId: book.id,
      body: {
        'opening_date': '2026-01-01',
        'positions': [
          {
            'account_id': broker.id,
            'symbol': '2330',
            'asset_class': 'tw_stock',
            'quote_currency': 'TWD',
            'qty': '1',
            'cost_twd': '10',
          },
        ],
      },
    );
    final refresh = await api.refreshQuotes(book.id);
    expect(refresh.updated, 1);
    final poss = await api.listPositions(book.id);
    expect(poss.single.marketValue, 900);
  });
}
