import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/services/apple_pay_link.dart';

import 'harness.dart';

// Dedup, opening-date, and mapping rules for Apple Pay confirm.
//
// Preview never inserts. Confirm is the only write. A stored import key
// makes the next preview 重複 and unticked. The user may still confirm it,
// which inserts another expense and leaves the key. A Taipei day strictly
// before the book's opening date cannot be saved (不能記開帳日之前的帳). The
// opening day itself is allowed. Merchant and card_last4 mappings are
// written on confirm and prefilled on the next preview.

void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.setUp();
  });
  tearDown(() async => h.tearDown());

  test('preview does not save, id and hash dedup, repeat confirm stays 重複', () async {
    final book = await h.book();
    final account = await h.cash(book.id, name: '現金');
    final category = await h.expenseCat(book.id);
    final day = todayTaipei();

    final byId = Uri.parse(
      'fulljizhang://add?amount=185&merchant=星巴克&time=$day'
      '&card_last4=1234&id=pay-1',
    );
    final first = await h.api.previewApplePay(bookId: book.id, uri: byId);
    expect(first.duplicate, isFalse);
    expect(first.initiallyTicked, isTrue);
    expect(first.beforeOpening, isFalse);
    expect(first.amount, 185);
    expect(await h.api.listEntries(bookId: book.id), isEmpty);

    await h.api.confirmApplePay(
      bookId: book.id,
      rows: [
        _commit(first, accountId: account.id, categoryId: category),
      ],
    );
    expect((await h.api.listEntries(bookId: book.id)).length, 1);
    expect((await h.db.select(h.db.importKeys).get()).length, 1);

    final again = await h.api.previewApplePay(bookId: book.id, uri: byId);
    expect(again.duplicate, isTrue);
    expect(again.initiallyTicked, isFalse);
    expect(again.canTick, isTrue);

    // Same charge without an id is a different key.
    final noId = Uri.parse(
      'fulljizhang://add?amount=185&merchant=星巴克&time=$day&card_last4=1234',
    );
    final hashed = await h.api.previewApplePay(bookId: book.id, uri: noId);
    expect(hashed.duplicate, isFalse);
    expect(hashed.importKey, isNot(again.importKey));
    await h.api.confirmApplePay(
      bookId: book.id,
      rows: [
        _commit(hashed, accountId: account.id, categoryId: category),
      ],
    );

    final hashedAgain = await h.api.previewApplePay(bookId: book.id, uri: noId);
    expect(hashedAgain.duplicate, isTrue);
    expect(hashedAgain.initiallyTicked, isFalse);

    // An explicit tick of a duplicate still inserts, and the key stays one
    // so the following preview is still 重複.
    await h.api.confirmApplePay(
      bookId: book.id,
      rows: [
        _commit(again, accountId: account.id, categoryId: category),
      ],
    );
    expect((await h.api.listEntries(bookId: book.id)).length, 3);
    final keys = await h.db.select(h.db.importKeys).get();
    expect(keys.length, 2);
    final third = await h.api.previewApplePay(bookId: book.id, uri: byId);
    expect(third.duplicate, isTrue);
  });

  test('before the opening date cannot be ticked or confirmed', () async {
    final book = await h.book();
    final account = await h.cash(book.id);
    final category = await h.expenseCat(book.id);
    final early = Uri.parse(
      'fulljizhang://add?amount=50&merchant=舊帳&time=2000-01-01&id=old',
    );
    final line = await h.api.previewApplePay(bookId: book.id, uri: early);
    expect(line.beforeOpening, isTrue);
    expect(line.canTick, isFalse);
    expect(line.initiallyTicked, isFalse);
    expect(line.date, '2000-01-01');

    try {
      await h.api.confirmApplePay(
        bookId: book.id,
        rows: [
          _commit(line, accountId: account.id, categoryId: category),
        ],
      );
      fail('expected opening-date rejection');
    } on ApiException catch (error) {
      expect(error.message, '不能記開帳日之前的帳');
      expect(error.status, 400);
    }
    expect(await h.api.listEntries(bookId: book.id), isEmpty);
    expect(await h.db.select(h.db.importKeys).get(), isEmpty);

    // The opening day itself is allowed.
    final day = todayTaipei();
    final onDay = await h.api.previewApplePay(
      bookId: book.id,
      uri: Uri.parse(
        'fulljizhang://add?amount=20&merchant=當天&time=$day&id=today',
      ),
    );
    expect(onDay.beforeOpening, isFalse);
    expect(onDay.canTick, isTrue);
  });

  test('confirm remembers merchant and card and the next preview prefills', () async {
    final book = await h.book();
    final card = await h.cash(book.id, name: '玉山 4321');
    final other = await h.cash(book.id, name: '現金');
    final category = await h.api.createCategory(
      bookId: book.id,
      name: '咖啡',
      kind: 'expense',
    );
    final day = todayTaipei();
    final firstUri = Uri.parse(
      'fulljizhang://add?amount=120&merchant=星巴克&time=$day'
      '&card=玉山&card_last4=****4321&id=map-1',
    );
    final first = await h.api.previewApplePay(bookId: book.id, uri: firstUri);
    // No mapping yet. The account name contains the last four digits.
    expect(first.accountId, card.id);
    expect(first.categoryId, isNull);
    expect(first.cardLast4, '4321');

    await h.api.confirmApplePay(
      bookId: book.id,
      rows: [
        _commit(first, accountId: other.id, categoryId: category.id),
      ],
    );

    final next = await h.api.previewApplePay(
      bookId: book.id,
      uri: Uri.parse(
        'fulljizhang://add?amount=80&merchant=星巴克&time=$day'
        '&card_last4=4321&category=別的名字&id=map-2',
      ),
    );
    // The confirmed mapping wins over the name match and the URL category.
    expect(next.duplicate, isFalse);
    expect(next.accountId, other.id);
    expect(next.categoryId, category.id);

    final byName = await h.api.previewApplePay(
      bookId: book.id,
      uri: Uri.parse(
        'fulljizhang://add?amount=30&merchant=新商家&time=$day&category=咖啡&id=map-3',
      ),
    );
    expect(byName.categoryId, category.id);
    expect(byName.accountId, isNull);
  });

  test('an empty confirm writes nothing', () async {
    final book = await h.book();
    expect(await h.api.confirmApplePay(bookId: book.id, rows: const []), 0);
    expect(await h.api.listEntries(bookId: book.id), isEmpty);
  });
}

ImportCommit _commit(
  ImportLine line, {
  required String accountId,
  required String categoryId,
}) {
  return ImportCommit(
    importKey: line.importKey,
    amount: line.amount ?? 0,
    date: line.date,
    accountId: accountId,
    categoryId: categoryId,
    note: line.note,
    merchant: line.merchant,
    cardLast4: line.cardLast4,
  );
}
