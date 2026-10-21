import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/services/backup_preview.dart';

import 'harness.dart';

/// Port of `api/internal/app/backup_pair_test.go` plus a Go-file round trip.
///
/// Export uses the `backup.go` `exportBook` shape. Import replaces the book
/// in one transaction and remaps transfer `pair_id` so each leg still points
/// at its sibling (`importBook`). The preview counts name, opening date,
/// accounts, and entries without writing. `test/fixtures/go_export.json` is
/// a Go-shaped payload; importing it must restore the paired transfer.
void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.setUp();
  });
  tearDown(() async => h.tearDown());

  test('TestImportRestoresTradePairID', () async {
    final book = await h.book('pair-smoke');
    await h.api.putOpening(
      bookId: book.id,
      body: {'opening_date': '2026-01-01'},
    );
    final accA = await h.api.createAccount(
      bookId: book.id,
      name: '交易所A',
      type: 'exchange',
    );
    final accB = await h.api.createAccount(
      bookId: book.id,
      name: '交易所B',
      type: 'exchange',
    );
    await h.api.putOpening(
      bookId: book.id,
      body: {
        'opening_date': '2026-01-01',
        'positions': [
          {
            'account_id': accA.id,
            'symbol': 'BTC',
            'name': 'Bitcoin',
            'asset_class': 'crypto',
            'quote_currency': 'USD',
            'qty': '10',
            'cost_twd': '100000',
          },
        ],
      },
    );
    final created = await h.api.createTrade(
      body: {
        'book_id': book.id,
        'date': '2026-08-30',
        'account_id': accA.id,
        'to_account_id': accB.id,
        'symbol': 'BTC',
        'asset_class': 'crypto',
        'quote_currency': 'USD',
        'side': 'transfer',
        'qty': '3',
        'fee_twd': 0,
        'note': 'smoke pair',
      },
      idempotencyKey: newIdempotencyKey(),
    );
    expect(created['out'], isNotNull);
    expect(created['in'], isNotNull);

    var trades = await h.api.listTrades(book.id);
    final paired = trades
        .where(
          (t) => t['side'] == 'transfer_out' || t['side'] == 'transfer_in',
        )
        .toList();
    expect(paired.length, 2);
    for (final t in paired) {
      expect(t['pair_id'], isNotNull);
    }

    final payload = await h.api.exportBook(book.id);
    await h.api.importBook(id: book.id, payload: payload);

    trades = await h.api.listTrades(book.id);
    final got = trades
        .where(
          (t) => t['side'] == 'transfer_out' || t['side'] == 'transfer_in',
        )
        .toList();
    expect(got.length, 2);
    final byId = {for (final t in got) t['id'] as String: t};
    for (final t in got) {
      final pair = t['pair_id'] as String?;
      expect(pair, isNotNull);
      final sib = byId[pair];
      expect(sib, isNotNull, reason: 'pair_id must point at sibling');
      final want = t['side'] == 'transfer_in' ? 'transfer_out' : 'transfer_in';
      expect(sib!['side'], want);
      expect(sib['pair_id'], t['id']);
    }
  });

  test('round-trip export/import preserves accounts entries and opening date', () async {
    final book = await h.book('生活');
    final acc = await h.cash(book.id);
    await h.api.putOpening(
      bookId: book.id,
      body: {
        'opening_date': '2026-01-01',
        'accounts': [
          {'account_id': acc.id, 'amount': 5000},
        ],
      },
    );
    await h.api.createEntry(
      body: {
        'book_id': book.id,
        'type': 'expense',
        'amount': 80,
        'account_id': acc.id,
        'date': '2026-02-02',
        'category_id': await h.expenseCat(book.id),
        'note': '咖啡',
      },
      idempotencyKey: newIdempotencyKey(),
    );
    final payload = await h.api.exportBook(book.id);
    final preview = BackupPreview.parse(payload);
    expect(preview.bookName, '生活');
    expect(preview.openingDate, '2026-01-01');
    expect(preview.accounts, 1);
    expect(preview.entries, greaterThanOrEqualTo(2));

    await h.api.importBook(id: book.id, payload: payload);
    final imported = (await h.api.listBooks()).firstWhere((b) => b.id == book.id);
    expect(imported.name, '生活');
    expect(imported.openingDate, '2026-01-01');
    final accs = await h.api.listAccounts(book.id);
    expect(accs.length, 1);
    expect(accs.first.cashBalance, 4920);
    final entries = await h.api.listEntries(bookId: book.id);
    expect(entries.where((e) => e.note == '咖啡').length, 1);
  });

  test('import Go-format fixture', () async {
    final raw = jsonDecode(
      File('test/fixtures/go_export.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final preview = BackupPreview.parse(raw);
    expect(preview.bookName, '生活');
    expect(preview.accounts, 2);
    expect(preview.categories, greaterThan(0));
    expect(preview.entries, greaterThan(0));
    expect(preview.trades, 2);
    expect(preview.openingDate, '2026-01-01');

    final book = await h.book('target');
    await h.api.importBook(id: book.id, payload: raw);
    final accs = await h.api.listAccounts(book.id);
    expect(accs.length, 2);
    final trades = await h.api.listTrades(book.id);
    final paired = trades
        .where(
          (t) => t['side'] == 'transfer_out' || t['side'] == 'transfer_in',
        )
        .toList();
    expect(paired.length, 2);
    final byId = {for (final t in paired) t['id'] as String: t};
    for (final t in paired) {
      final sib = byId[t['pair_id']];
      expect(sib, isNotNull);
      expect(sib!['pair_id'], t['id']);
    }
  });
}
