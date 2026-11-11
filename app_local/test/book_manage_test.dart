import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/app.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/services/local_api.dart';
import 'package:full_jizhang/services/secure_store.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rules/harness.dart';

// 帳本管理 list, settings entry, confirm dialog, and cascade delete.
//
// Purpose: cover frames 14, 15, and the 設定 row on frame 6.
// Rules: deleting a book removes its records in one transaction; the
// current book is rejected; 取消 leaves the book; 切換帳本 is gone.

void main() {
  late Harness h;

  setUpAll(openTestSqlite);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    h = Harness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  group('deleteBook cascade', () {
    test('removes a non-current book and all of its rows', () async {
      final keep = await h.book('生活');
      final gone = await h.book('旅行');
      await h.api.selectBook(keep.id);
      final cash = await h.cash(gone.id);
      await h.api.createEntry(
        body: {
          'book_id': gone.id,
          'type': 'expense',
          'amount': 120,
          'account_id': cash.id,
          'date': todayTaipei(),
          'category_id': await h.expenseCat(gone.id),
        },
        idempotencyKey: newIdempotencyKey(),
      );

      await h.api.deleteBook(gone.id);

      final books = await h.api.listBooks();
      expect(books.map((book) => book.id), [keep.id]);
      final leftoverAccounts = await h.db.select(h.db.accounts).get();
      expect(leftoverAccounts.where((row) => row.bookId == gone.id), isEmpty);
      final leftoverEntries = await h.db.select(h.db.entries).get();
      expect(leftoverEntries.where((row) => row.bookId == gone.id), isEmpty);
    });

    test('rejects the current book and leaves its data', () async {
      final current = await h.book('生活');
      final other = await h.book('旅行');
      await h.api.selectBook(current.id);
      final cash = await h.cash(current.id);
      await h.api.createEntry(
        body: {
          'book_id': current.id,
          'type': 'expense',
          'amount': 50,
          'account_id': cash.id,
          'date': todayTaipei(),
          'category_id': await h.expenseCat(current.id),
        },
        idempotencyKey: newIdempotencyKey(),
      );

      expect(
        () => h.api.deleteBook(current.id),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('目前使用中的帳本無法刪除'),
          ),
        ),
      );
      final books = await h.api.listBooks();
      expect(books.map((book) => book.id).toSet(), {current.id, other.id});
      expect(await h.api.listEntries(bookId: current.id), isNotEmpty);
    });
  });

  group('帳本管理 UI', () {
    setUpAll(() {
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    testWidgets('list shows date, net worth, and 目前使用; settings row is the entry',
        (tester) async {
      final env = await _env(h, names: ['生活', '旅行']);
      addTearDown(env.disposeLock);
      await _pump(tester, env);

      expect(find.byKey(const Key('settings-switch')), findsNothing);
      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      expect(find.text('2 個帳本 · 新增／刪除'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-books')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('page-books')), findsOneWidget);
      expect(find.text('設定 · 2 個帳本'), findsOneWidget);
      expect(find.text('目前使用'), findsOneWidget);
      expect(find.byKey(const Key('books-current-badge')), findsOneWidget);
      expect(find.textContaining('開帳日'), findsWidgets);
      expect(find.textContaining('淨資產'), findsWidgets);
      expect(find.byKey(const Key('books-add')), findsOneWidget);
      expect(find.byKey(const Key('books-add-appbar')), findsOneWidget);

      await tester.tap(find.byKey(const Key('books-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('opening-title')), findsOneWidget);
      expect(find.text('選開帳日'), findsOneWidget);
      expect(find.byKey(const Key('opening-book-name')), findsOneWidget);
    });

    testWidgets('confirm dialog: 取消 keeps the book, 刪除 removes it',
        (tester) async {
      final env = await _env(h, names: ['生活', '旅行']);
      addTearDown(env.disposeLock);
      // 生活 is current (first create sets last_book_id).
      final books = await h.api.listBooks();
      final travel = books.firstWhere((book) => book.name == '旅行');

      await _pump(tester, env);
      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-books')));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(Key('managed-${travel.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('books-confirm-title')), findsOneWidget);
      expect(find.text('刪除「旅行」？'), findsOneWidget);
      expect(find.text('帳本內的記錄會一併刪除。'), findsOneWidget);

      await tester.tap(find.byKey(const Key('books-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('旅行'), findsOneWidget);
      expect(await h.api.listBooks(), hasLength(2));

      await tester.longPress(find.byKey(Key('managed-${travel.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('books-confirm-delete')));
      await tester.pumpAndSettle();
      expect(find.text('旅行'), findsNothing);
      expect(find.byKey(const Key('page-books')), findsOneWidget);
      final left = await h.api.listBooks();
      expect(left.map((book) => book.name), ['生活']);
    });

    testWidgets('current book cannot be deleted from the UI', (tester) async {
      final env = await _env(h, names: ['生活', '旅行']);
      addTearDown(env.disposeLock);
      final books = await h.api.listBooks();
      final current = books.firstWhere((book) => book.name == '生活');

      await _pump(tester, env);
      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-books')));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(Key('managed-${current.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('books-confirm-title')), findsNothing);
      expect(find.byKey(Key('books-swipe-${current.id}')), findsNothing);
      expect(await h.api.listBooks(), hasLength(2));
    });
  });
}

class _Env {
  _Env({required this.api, required this.lock});

  final LocalApi api;
  final LockController lock;

  void disposeLock() => lock.dispose();
}

Future<_Env> _env(Harness h, {required List<String> names}) async {
  for (final name in names) {
    await h.api.createBook(name: name);
  }
  final lock = LockController(
    auth: AlwaysAllowAuth(),
    store: MemorySecureStore(),
    observeLifecycle: false,
  );
  return _Env(api: h.api, lock: lock);
}

Future<void> _pump(WidgetTester tester, _Env env) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(FullJizhangApp(api: env.api, lock: env.lock));
  await tester.pumpAndSettle();
}
