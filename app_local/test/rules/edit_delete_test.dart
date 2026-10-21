import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';

import 'harness.dart';

// Edit and delete replay opening lots and live trades in date order with
// moving-average cost. A holding that would go negative at any point throws
// 「修改後持倉會變負數」 and the transaction leaves rows and positions as they
// were. Dates before the opening date are rejected. Transfer edits and
// deletes touch both legs, and a matching 搬倉手續費 expense moves with them.

void numEq(dynamic got, String want) {
  expect(Decimal.parse('$got'), Decimal.parse(want));
}

void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.setUp();
  });
  tearDown(() async => h.tearDown());

  test('edit and delete an expense, and reject a date before opening', () async {
    final book = await h.book();
    final account = await h.cash(book.id);
    final category = await h.expenseCat(book.id);
    final created = await h.api.createEntry(
      body: {
        'book_id': book.id,
        'type': 'expense',
        'amount': 100,
        'account_id': account.id,
        'category_id': category,
        'date': todayTaipei(),
        'note': '午餐',
      },
      idempotencyKey: newIdempotencyKey(),
    );
    expect(await _cash(h, book.id, account.id), -100);

    final patched = await h.api.patchEntry(
      id: created.id,
      body: {'version': created.version, 'amount': 40},
    );
    expect(patched.amount, 40);
    expect(patched.note, '午餐');
    expect(patched.version, created.version + 1);
    expect(await _cash(h, book.id, account.id), -40);

    try {
      await h.api.patchEntry(
        id: created.id,
        body: {'version': patched.version, 'date': '2000-01-01'},
      );
      fail('expected opening-date rejection');
    } on ApiException catch (error) {
      expect(error.message, '不能記開帳日之前的帳');
      expect(error.status, 400);
    }
    final still = await h.api.listEntries(bookId: book.id);
    expect(still.single.amount, 40);
    expect(still.single.date, todayTaipei());

    try {
      await h.api.patchEntry(
        id: created.id,
        body: {'version': created.version, 'amount': 1},
      );
      fail('expected version conflict');
    } on ApiException catch (error) {
      expect(error.status, 409);
      expect(error.message, '資料已被更新，請重抓再送');
    }
    expect((await h.api.listEntries(bookId: book.id)).single.amount, 40);

    await h.api.deleteEntry(id: created.id, version: patched.version);
    expect(await h.api.listEntries(bookId: book.id), isEmpty);
    expect(await _cash(h, book.id, account.id), 0);
  });

  test('opening balance and opening lots cannot be edited or deleted', () async {
    final book = await h.book();
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
            'cost_twd': '200',
          },
        ],
      },
    );
    final openingEntry = (await h.api.listEntries(bookId: book.id))
        .singleWhere((entry) => entry.type == 'opening_balance');
    for (final call in [
      () => h.api.patchEntry(
        id: openingEntry.id,
        body: {'version': openingEntry.version, 'amount': 5},
      ),
      () => h.api.deleteEntry(id: openingEntry.id, version: openingEntry.version),
    ]) {
      try {
        await call();
        fail('expected opening entry rejection');
      } on ApiException catch (error) {
        expect(error.status, 409);
        expect(error.message, contains('開帳分錄不能'));
      }
    }
    expect(await _cash(h, book.id, cash.id), 1000);

    final lot = (await h.api.listTrades(book.id))
        .singleWhere((trade) => trade['side'] == 'opening');
    try {
      await h.api.patchTrade(
        id: '${lot['id']}',
        body: {'version': lot['version'], 'qty': '1'},
      );
      fail('expected opening trade rejection');
    } on ApiException catch (error) {
      expect(error.message, '開帳成交不能改');
      expect(error.status, 409);
    }
    try {
      await h.api.deleteTrade(
        id: '${lot['id']}',
        version: lot['version'] as int,
      );
      fail('expected opening trade rejection');
    } on ApiException catch (error) {
      expect(error.message, '開帳成交不能刪');
    }
    final poss = await h.api.listPositions(book.id);
    expect(poss, hasLength(1));
    numEq(poss.single.qty, '2');
  });

  test('edit and delete a buy, and an entry edit leaves the holding', () async {
    final book = await h.book();
    final account = await h.broker(book.id);
    final category = await h.expenseCat(book.id);
    final buy = await _buy(h, book.id, account.id, qty: '10', price: '100');
    expect(buy['proceeds_or_cost_twd'], 1000);
    expect(await _cash(h, book.id, account.id), -1000);

    final edited = await h.api.patchTrade(
      id: '${buy['id']}',
      body: {'version': buy['version'], 'qty': '8'},
    );
    expect(edited['qty'], '8');
    expect(edited['price'], '100');
    expect(edited['proceeds_or_cost_twd'], 800);
    var poss = await h.api.listPositions(book.id);
    numEq(poss.single.qty, '8');
    numEq(poss.single.costTwd, '800');
    expect(await _cash(h, book.id, account.id), -800);

    final expense = await h.api.createEntry(
      body: {
        'book_id': book.id,
        'type': 'expense',
        'amount': 50,
        'account_id': account.id,
        'category_id': category,
        'date': todayTaipei(),
      },
      idempotencyKey: newIdempotencyKey(),
    );
    await h.api.patchEntry(
      id: expense.id,
      body: {'version': expense.version, 'amount': 20},
    );
    poss = await h.api.listPositions(book.id);
    numEq(poss.single.qty, '8');
    numEq(poss.single.costTwd, '800');
    expect(await _cash(h, book.id, account.id), -820);

    await h.api.deleteTrade(id: '${buy['id']}', version: edited['version'] as int);
    poss = await h.api.listPositions(book.id);
    expect(poss, isEmpty);
    expect(await _cash(h, book.id, account.id), -20);
  });

  test('shrinking a buy under a later sell is rejected and unchanged', () async {
    final book = await h.book();
    final account = await h.broker(book.id);
    final day = todayTaipei();
    final buy = await _buy(
      h,
      book.id,
      account.id,
      qty: '10',
      price: '100',
      date: day,
    );
    await _sell(
      h,
      book.id,
      account.id,
      qty: '6',
      price: '100',
      date: _plus(day, 1),
    );
    try {
      await h.api.patchTrade(
        id: '${buy['id']}',
        body: {'version': buy['version'], 'qty': '4'},
      );
      fail('expected negative holding');
    } on ApiException catch (error) {
      expect(error.message, '修改後持倉會變負數');
      expect(error.status, 422);
    }
    final trades = await h.api.listTrades(book.id);
    final still = trades.singleWhere((trade) => trade['side'] == 'buy');
    numEq(still['qty'], '10');
    expect(still['version'], buy['version']);
    final poss = await h.api.listPositions(book.id);
    numEq(poss.single.qty, '4');
    numEq(poss.single.costTwd, '400');
  });

  test('transfer edit and delete move both legs and the fee', () async {
    final book = await h.book();
    final from = await h.broker(book.id, name: '甲券商');
    final to = await h.broker(book.id, name: '乙券商');
    final day = todayTaipei();
    await _buy(h, book.id, from.id, qty: '10', price: '100', date: day);
    final moved = await h.api.createTrade(
      body: {
        'book_id': book.id,
        'date': _plus(day, 1),
        'account_id': from.id,
        'to_account_id': to.id,
        'symbol': '2330',
        'asset_class': 'tw_stock',
        'quote_currency': 'TWD',
        'side': 'transfer',
        'qty': '4',
        'fee_twd': 15,
      },
      idempotencyKey: newIdempotencyKey(),
    );
    final outId = '${moved['out']}';
    var trades = await h.api.listTrades(book.id);
    final out = trades.singleWhere((trade) => trade['id'] == outId);
    final inn = trades.singleWhere((trade) => trade['side'] == 'transfer_in');
    expect(inn['pair_id'], outId);
    expect(out['pair_id'], inn['id']);
    var poss = await h.api.listPositions(book.id);
    _expectPos(poss, from.id, '6', '600');
    _expectPos(poss, to.id, '4', '400');
    var fee = (await h.api.listEntries(bookId: book.id))
        .singleWhere((entry) => entry.note == '搬倉手續費');
    expect(fee.amount, 15);
    expect(fee.accountId, from.id);
    expect(await _cash(h, book.id, from.id), -1015);

    final patched = await h.api.patchTrade(
      id: outId,
      body: {'version': out['version'], 'qty': '3', 'fee_twd': 20},
    );
    expect(patched['version'], (out['version'] as int) + 1);
    trades = await h.api.listTrades(book.id);
    numEq(trades.singleWhere((t) => t['id'] == outId)['qty'], '3');
    numEq(trades.singleWhere((t) => t['side'] == 'transfer_in')['qty'], '3');
    expect(
      trades.singleWhere((t) => t['side'] == 'transfer_in')['version'],
      (inn['version'] as int) + 1,
    );
    poss = await h.api.listPositions(book.id);
    _expectPos(poss, from.id, '7', '700');
    _expectPos(poss, to.id, '3', '300');
    fee = (await h.api.listEntries(bookId: book.id))
        .singleWhere((entry) => entry.note == '搬倉手續費');
    expect(fee.amount, 20);
    expect(await _cash(h, book.id, from.id), -1020);

    await h.api.deleteTrade(id: outId, version: patched['version'] as int);
    trades = await h.api.listTrades(book.id);
    expect(trades.where((t) => t['side'] == 'transfer_out'), isEmpty);
    expect(trades.where((t) => t['side'] == 'transfer_in'), isEmpty);
    poss = await h.api.listPositions(book.id);
    expect(poss, hasLength(1));
    _expectPos(poss, from.id, '10', '1000');
    expect(
      (await h.api.listEntries(bookId: book.id))
          .where((entry) => entry.note == '搬倉手續費'),
      isEmpty,
    );
    expect(await _cash(h, book.id, from.id), -1000);
  });

  test('deleting a transfer that a later sell needs is rejected', () async {
    final book = await h.book();
    final from = await h.broker(book.id, name: '甲');
    final to = await h.broker(book.id, name: '乙');
    final day = todayTaipei();
    await _buy(h, book.id, from.id, qty: '10', price: '100', date: day);
    final moved = await h.api.createTrade(
      body: {
        'book_id': book.id,
        'date': _plus(day, 1),
        'account_id': from.id,
        'to_account_id': to.id,
        'symbol': '2330',
        'asset_class': 'tw_stock',
        'quote_currency': 'TWD',
        'side': 'transfer',
        'qty': '6',
      },
      idempotencyKey: newIdempotencyKey(),
    );
    final outId = '${moved['out']}';
    await _sell(
      h,
      book.id,
      to.id,
      qty: '6',
      price: '100',
      date: _plus(day, 2),
    );
    final beforeTrades = await h.api.listTrades(book.id);
    final beforePos = await h.api.listPositions(book.id);
    final out = beforeTrades.singleWhere((trade) => trade['id'] == outId);
    try {
      await h.api.deleteTrade(id: outId, version: out['version'] as int);
      fail('expected negative holding');
    } on ApiException catch (error) {
      expect(error.message, '修改後持倉會變負數');
      expect(error.status, 422);
    }
    try {
      await h.api.patchTrade(
        id: outId,
        body: {'version': out['version'], 'qty': '5'},
      );
      fail('expected negative holding');
    } on ApiException catch (error) {
      expect(error.message, '修改後持倉會變負數');
    }
    final afterTrades = await h.api.listTrades(book.id);
    expect(afterTrades.length, beforeTrades.length);
    final still = afterTrades.singleWhere((trade) => trade['id'] == outId);
    numEq(still['qty'], '6');
    expect(still['version'], out['version']);
    final afterPos = await h.api.listPositions(book.id);
    _expectPos(afterPos, from.id, _qtyOf(beforePos, from.id), _costOf(beforePos, from.id));
    _expectPos(afterPos, to.id, _qtyOf(beforePos, to.id), _costOf(beforePos, to.id));
  });
}

Future<int> _cash(Harness h, String bookId, String accountId) async {
  final accounts = await h.api.listAccounts(bookId);
  return accounts.firstWhere((account) => account.id == accountId).cashBalance;
}

Future<Map<String, dynamic>> _buy(
  Harness h,
  String bookId,
  String accountId, {
  required String qty,
  required String price,
  String? date,
}) {
  return h.api.createTrade(
    body: {
      'book_id': bookId,
      'date': date ?? todayTaipei(),
      'account_id': accountId,
      'symbol': '2330',
      'asset_class': 'tw_stock',
      'quote_currency': 'TWD',
      'side': 'buy',
      'qty': qty,
      'price': price,
      'price_ccy': 'TWD',
      'fee_twd': 0,
    },
    idempotencyKey: newIdempotencyKey(),
  );
}

Future<Map<String, dynamic>> _sell(
  Harness h,
  String bookId,
  String accountId, {
  required String qty,
  required String price,
  required String date,
}) {
  return h.api.createTrade(
    body: {
      'book_id': bookId,
      'date': date,
      'account_id': accountId,
      'symbol': '2330',
      'asset_class': 'tw_stock',
      'quote_currency': 'TWD',
      'side': 'sell',
      'qty': qty,
      'price': price,
      'price_ccy': 'TWD',
      'fee_twd': 0,
    },
    idempotencyKey: newIdempotencyKey(),
  );
}

String _plus(String iso, int days) {
  final parts = iso.split('-');
  final next = DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  ).add(Duration(days: days));
  return '${next.year}-${pad2(next.month)}-${pad2(next.day)}';
}

void _expectPos(List<Position> poss, String accountId, String qty, String cost) {
  final row = poss.singleWhere((position) => position.accountId == accountId);
  numEq(row.qty, qty);
  numEq(row.costTwd, cost);
}

String _qtyOf(List<Position> poss, String accountId) {
  return poss.singleWhere((position) => position.accountId == accountId).qty;
}

String _costOf(List<Position> poss, String accountId) {
  return poss.singleWhere((position) => position.accountId == accountId).costTwd;
}

