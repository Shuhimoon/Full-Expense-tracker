import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';

import 'harness.dart';

/// Port of `api/internal/app/opening_nolock_test.go`.
///
/// A new book is usable immediately (no lock step). Its opening date is the
/// creation day in Asia/Taipei (`books.go` `handleBooksCreate`). An entry
/// before that day is 「不能記開帳日之前的帳」 (`entries.go`). Putting cash drafts
/// replaces the single `opening_balance` row. Moving the opening date past
/// an existing entry is 「不能把開帳日往後改」 (`opening.go` `handleOpeningPut`).
/// Moving it earlier is allowed. Each book gets its own creation-day default.
void main() {
  late Harness h;

  setUp(() async {
    h = Harness();
    await h.setUp();
  });
  tearDown(() async => h.tearDown());

  test('TestBookCreatedCanRecordWithoutLock', () async {
    final book = await h.book('生活');
    expect(book.openingDate, todayTaipei());

    final acc = await h.cash(book.id);
    final catId = await h.expenseCat(book.id);
    final entry = await h.api.createEntry(
      body: {
        'book_id': book.id,
        'type': 'expense',
        'amount': 120,
        'account_id': acc.id,
        'date': todayTaipei(),
        'category_id': catId,
      },
      idempotencyKey: newIdempotencyKey(),
    );
    expect(entry.amount, 120);

    await expectLater(
      h.api.createEntry(
        body: {
          'book_id': book.id,
          'type': 'expense',
          'amount': 50,
          'account_id': acc.id,
          'date': '2000-01-01',
          'category_id': catId,
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

    await h.api.putOpening(
      bookId: book.id,
      body: {
        'accounts': [
          {'account_id': acc.id, 'amount': 1000},
        ],
      },
    );
    var entries = await h.api.listEntries(bookId: book.id);
    var opens = entries.where((e) => e.type == 'opening_balance').toList();
    expect(opens.length, 1);
    expect(opens.single.amount, 1000);

    await h.api.putOpening(
      bookId: book.id,
      body: {
        'accounts': [
          {'account_id': acc.id, 'amount': 2000},
        ],
      },
    );
    entries = await h.api.listEntries(bookId: book.id);
    opens = entries.where((e) => e.type == 'opening_balance').toList();
    expect(opens.length, 1);
    expect(opens.single.amount, 2000);

    final later = DateTime.parse(
      '${todayTaipei()}T00:00:00',
    ).add(const Duration(days: 3));
    final laterStr =
        '${later.year}-${later.month.toString().padLeft(2, '0')}-${later.day.toString().padLeft(2, '0')}';
    await expectLater(
      h.api.putOpening(bookId: book.id, body: {'opening_date': laterStr}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('不能把開帳日往後改'),
        ),
      ),
    );

    final moved = await h.api.putOpening(
      bookId: book.id,
      body: {'opening_date': '2026-01-01'},
    );
    expect(moved.openingDate, '2026-01-01');
  });

  test('each book defaults opening date to its creation day in Asia/Taipei', () async {
    final a = await h.book('生活');
    final b = await h.book('投資');
    expect(a.openingDate, todayTaipei());
    expect(b.openingDate, todayTaipei());
    expect(a.id, isNot(b.id));
  });
}
