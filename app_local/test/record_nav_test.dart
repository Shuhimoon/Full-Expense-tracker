import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/app.dart';
import 'package:full_jizhang/data/database.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/pages/analytics/analytics_page.dart';
import 'package:full_jizhang/pages/home/home_page.dart';
import 'package:full_jizhang/services/incoming_links.dart';
import 'package:full_jizhang/services/local_api.dart';
import 'package:full_jizhang/services/secure_store.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rules/harness.dart';

// After 記一筆 save / edit / delete, the originating tab stays selected
// and reloads. FAB uses push('/record'); 存檔 pops. A deep-link confirm
// pops the import sheet. None of these paths go('/') onto 帳本.

class _ScriptedLinks implements LinkSource {
  final StreamController<Uri> live = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => null;

  @override
  Stream<Uri> get uriLinkStream => live.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    openTestSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FAB from 帳本 saves and returns to 帳本', (tester) async {
    final env = await _env();
    addTearDown(env.dispose);
    await _pump(tester, env);

    expect(find.byKey(const Key('page-home')), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);

    await tester.tap(find.byKey(const Key('fab-record')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-amount')), findsOneWidget);

    await _saveAmount(tester, '120');

    expect(find.byKey(const Key('record-amount')), findsNothing);
    expect(find.byKey(const Key('page-home')), findsOneWidget);
    expect(find.byType(AnalyticsPage), findsNothing);
    expect(find.text('−120'), findsWidgets);
  });

  testWidgets('FAB from 分析 saves and returns to 分析', (tester) async {
    final env = await _env();
    addTearDown(env.dispose);
    await _pump(tester, env);

    await tester.tap(find.byKey(const Key('nav-analytics')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page-analytics')), findsOneWidget);
    expect(find.byType(AnalyticsPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('fab-record')));
    await tester.pumpAndSettle();
    await _saveAmount(tester, '80');

    expect(find.byKey(const Key('record-amount')), findsNothing);
    expect(find.byKey(const Key('page-analytics')), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    expect(find.text('分析'), findsOneWidget);
  });

  testWidgets('deep-link confirm returns to the originating 分析 page', (
    tester,
  ) async {
    final source = _ScriptedLinks();
    addTearDown(source.live.close);
    final links = IncomingLinks(source: source);
    final env = await _env(links: links);
    addTearDown(env.dispose);
    await _pump(tester, env);

    await tester.tap(find.byKey(const Key('nav-analytics')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page-analytics')), findsOneWidget);

    source.live.add(
      Uri.parse(
        'fulljizhang://add?amount=185&merchant=${Uri.encodeQueryComponent('星巴克')}'
        '&category=${Uri.encodeQueryComponent('餐飲')}'
        '&time=2099-01-01T08:00:00%2B08:00&id=nav-import-1',
      ),
    );
    await tester.idle();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('匯入預覽'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-account-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('import-pick-${env.accountId}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('匯入預覽'), findsNothing);
    expect(find.byKey(const Key('page-analytics')), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('edit and delete stay on 帳本 and refresh the list', (tester) async {
    final env = await _env();
    addTearDown(env.dispose);
    final created = await env.api.createEntry(
      body: {
        'book_id': env.bookId,
        'type': 'expense',
        'amount': 50,
        'account_id': env.accountId,
        'date': taipeiToday(),
        'category_id': env.categoryId,
        'note': '原筆',
      },
      idempotencyKey: newIdempotencyKey(),
    );
    await _pump(tester, env);
    expect(find.text('原筆'), findsOneWidget);

    await tester.tap(find.byKey(Key('entry-row-${created.id}')));
    await tester.pumpAndSettle();
    await _saveAmount(tester, '60');

    expect(find.byKey(const Key('page-home')), findsOneWidget);
    expect(find.text('−60'), findsWidgets);
    expect(find.text('−50'), findsNothing);

    await tester.ensureVisible(find.byKey(Key('delete-entry-${created.id}')));
    await tester.tap(find.byKey(Key('delete-entry-${created.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('page-home')), findsOneWidget);
    expect(find.text('原筆'), findsNothing);
  });
}

class _Env {
  _Env({
    required this.db,
    required this.api,
    required this.lock,
    required this.bookId,
    required this.accountId,
    required this.categoryId,
    this.links,
  });

  final AppDatabase db;
  final LocalApi api;
  final LockController lock;
  final String bookId;
  final String accountId;
  final String categoryId;
  final IncomingLinks? links;

  Future<void> dispose() async {
    lock.dispose();
    await db.close();
  }

  // IncomingLinks is disposed by FullJizhangApp.
}

Future<_Env> _env({IncomingLinks? links}) async {
  final db = AppDatabase.memory();
  final api = LocalApi(db);
  final book = await api.createBook(name: '生活');
  final account = await api.createAccount(
    bookId: book.id,
    name: '現金',
    type: 'cash',
  );
  final cats = await api.listCategories(book.id);
  final category = cats.firstWhere((c) => c.kind == 'expense');
  final lock = LockController(
    auth: AlwaysAllowAuth(),
    store: MemorySecureStore(),
    observeLifecycle: false,
  );
  return _Env(
    db: db,
    api: api,
    lock: lock,
    bookId: book.id,
    accountId: account.id,
    categoryId: category.id,
    links: links,
  );
}

Future<void> _pump(WidgetTester tester, _Env env) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    FullJizhangApp(api: env.api, lock: env.lock, links: env.links),
  );
  await tester.pumpAndSettle();
}

Future<void> _saveAmount(WidgetTester tester, String amount) async {
  final field = find.byKey(const Key('record-amount'));
  expect(field, findsOneWidget);
  // Wait for accounts/categories; pumpAndSettle can return while _load
  // is still awaiting SQLite.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
  final tf = tester.widget<TextField>(field);
  tf.controller!.text = amount;
  tf.controller!.selection = TextSelection.collapsed(offset: amount.length);
  await tester.pump();
  expect(tf.controller!.text, amount);
  // 完成 sits in the top bar, above the scrim, so the tap hits _save.
  await tester.tap(find.byKey(const Key('record-done')));
  await tester.pumpAndSettle();
  final err = find.byKey(const Key('record-error'));
  if (err.evaluate().isNotEmpty) {
    fail(tester.widget<Text>(err).data ?? 'record-error');
  }
}
