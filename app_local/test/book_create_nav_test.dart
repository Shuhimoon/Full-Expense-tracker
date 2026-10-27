import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/app.dart';
import 'package:full_jizhang/data/database.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/services/local_api.dart';
import 'package:full_jizhang/services/secure_store.dart';
import 'package:full_jizhang/session/book_create_nav.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rules/harness.dart';

// 新增帳本 landing page.
//
// Creating the very first book, when there are no books yet, finishes
// on 帳本 `/` for every origin, including 設定. From 設定 (帳本管理, or
// 新增帳本 on the 切換帳本 sheet) with a book already present, the app
// returns to the 設定 page and keeps the new book current. The empty-state
// 建立帳本 on an empty DB also finishes on 帳本 `/`. No path opens 開帳.
// The choice is [routeAfterBookCreate], from the origin and the real
// book count taken before create, not from a delayed callback.

void main() {
  group('routeAfterBookCreate', () {
    test('設定 returns to /settings when a book already existed', () {
      expect(
        routeAfterBookCreate(
          origin: BookCreateOrigin.settings,
          hadBooks: true,
        ),
        '/settings',
      );
    });

    test('no books yet goes to 帳本 for every origin, including 設定', () {
      // Purpose: the first-book rule wins over origin.
      // Rule: hadBooks false → `/` for settings, firstRun, and homeManage.
      for (final origin in BookCreateOrigin.values) {
        expect(
          routeAfterBookCreate(origin: origin, hadBooks: false),
          '/',
          reason: origin.name,
        );
      }
    });

    test('first-run empty state goes to 帳本 home', () {
      expect(
        routeAfterBookCreate(
          origin: BookCreateOrigin.firstRun,
          hadBooks: false,
        ),
        '/',
      );
      // A first-run origin stays on 帳本 even if the caller mis-counted.
      expect(
        routeAfterBookCreate(
          origin: BookCreateOrigin.firstRun,
          hadBooks: true,
        ),
        '/',
      );
    });

    test('帳本 switcher stays on 帳本管理 when a book already existed', () {
      expect(
        routeAfterBookCreate(
          origin: BookCreateOrigin.homeManage,
          hadBooks: true,
        ),
        isNull,
      );
      expect(
        routeAfterBookCreate(
          origin: BookCreateOrigin.homeManage,
          hadBooks: false,
        ),
        '/',
      );
    });

    test('開帳 is never the destination', () {
      for (final origin in BookCreateOrigin.values) {
        for (final hadBooks in [false, true]) {
          expect(
            routeAfterBookCreate(origin: origin, hadBooks: hadBooks),
            isNot('/opening'),
          );
        }
      }
    });
  });

  group('originFromBooksQuery', () {
    test('home is the 帳本 switcher; everything else is 設定', () {
      expect(originFromBooksQuery('home'), BookCreateOrigin.homeManage);
      expect(originFromBooksQuery('settings'), BookCreateOrigin.settings);
      expect(originFromBooksQuery(null), BookCreateOrigin.settings);
      expect(originFromBooksQuery(''), BookCreateOrigin.settings);
    });
  });

  group('book create navigation', () {
    setUpAll(() {
      openTestSqlite();
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('from 設定, 新增帳本 returns to 設定 with the new book current', (
      tester,
    ) async {
      final env = await _env(seedBook: true);
      addTearDown(env.dispose);
      await _pump(tester, env);

      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('page-settings')), findsOneWidget);
      expect(find.textContaining('目前：生活'), findsOneWidget);

      // 切換帳本 on 設定 → 新增帳本 → the name form.
      await tester.tap(find.byKey(const Key('settings-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-new-book')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('page-books')), findsOneWidget);
      expect(
        GoRouterState.of(tester.element(find.byKey(const Key('page-books'))))
            .uri
            .path,
        '/settings/books',
      );

      await tester.enterText(find.byKey(const Key('new-book-field')), '旅行');
      await tester.tap(find.byKey(const Key('new-book-create')));
      await tester.pumpAndSettle();

      _expectSettingsWithBook(tester, '旅行');
      expect(find.textContaining('生活'), findsWidgets);
    });

    testWidgets('from 設定, 帳本管理 新增 also returns to 設定', (tester) async {
      final env = await _env(seedBook: true);
      addTearDown(env.dispose);
      await _pump(tester, env);

      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-books')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('page-books')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('new-book-field')), '家庭');
      await tester.tap(find.byKey(const Key('new-book-create')));
      await tester.pumpAndSettle();

      _expectSettingsWithBook(tester, '家庭');
    });

    testWidgets('empty DB first-book flow ends on 帳本 home', (tester) async {
      final env = await _env(seedBook: false);
      addTearDown(env.dispose);
      await _pump(tester, env);

      expect(find.text('還沒有帳本'), findsOneWidget);
      expect(find.byKey(const Key('home-create-book')), findsOneWidget);
      expect(
        GoRouterState.of(tester.element(find.byKey(const Key('page-home'))))
            .uri
            .path,
        '/',
      );

      await tester.tap(find.byKey(const Key('home-create-book')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('page-home')), findsOneWidget);
      expect(find.byKey(const Key('book-switcher')), findsOneWidget);
      expect(find.text('生活'), findsWidgets);
      expect(find.text('還沒有帳本'), findsNothing);
      expect(find.byKey(const Key('page-settings')), findsNothing);
      expect(find.byKey(const Key('page-books')), findsNothing);
      expect(find.byKey(const Key('opening-title')), findsNothing);
      expect(find.text('步驟 1／4 · 開帳'), findsNothing);
      expect(
        GoRouterState.of(tester.element(find.byKey(const Key('page-home'))))
            .uri
            .path,
        '/',
      );
      final ledger = tester.getSemantics(find.byKey(const Key('nav-ledger')));
      expect(ledger.flagsCollection.isSelected, Tristate.isTrue);
    });
  });
}

void _expectSettingsWithBook(WidgetTester tester, String name) {
  expect(find.byKey(const Key('page-settings')), findsOneWidget);
  expect(find.byKey(const Key('page-books')), findsNothing);
  expect(find.byKey(const Key('page-home')), findsNothing);
  expect(find.byKey(const Key('new-book-field')), findsNothing);
  expect(find.byKey(const Key('opening-title')), findsNothing);
  expect(find.text('步驟 1／4 · 開帳'), findsNothing);
  expect(find.textContaining('目前：$name'), findsOneWidget);
  expect(find.textContaining(name), findsWidgets);
  expect(
    GoRouterState.of(tester.element(find.byKey(const Key('page-settings'))))
        .uri
        .path,
    '/settings',
  );
  final settings = tester.getSemantics(find.byKey(const Key('nav-settings')));
  expect(settings.flagsCollection.isSelected, Tristate.isTrue);
}

class _Env {
  _Env({required this.db, required this.api, required this.lock});

  final AppDatabase db;
  final LocalApi api;
  final LockController lock;

  Future<void> dispose() async {
    lock.dispose();
    await db.close();
  }
}

Future<_Env> _env({required bool seedBook}) async {
  final db = AppDatabase.memory();
  final api = LocalApi(db);
  if (seedBook) {
    // Purpose: 設定 create is the "another book" case. The empty-DB
    // case is the other test. createBook selects when last_book_id
    // is unset, which is the existing first-row behaviour.
    await api.createBook(name: '生活');
  }
  final lock = LockController(
    auth: AlwaysAllowAuth(),
    store: MemorySecureStore(),
    observeLifecycle: false,
  );
  return _Env(db: db, api: api, lock: lock);
}

Future<void> _pump(WidgetTester tester, _Env env) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(FullJizhangApp(api: env.api, lock: env.lock));
  await tester.pumpAndSettle();
}
