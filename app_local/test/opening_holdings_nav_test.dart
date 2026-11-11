import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/app.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/services/local_api.dart';
import 'package:full_jizhang/services/secure_store.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rules/harness.dart';

// 現倉 略過 / 下一步 both go to the preview (frame 9).

void main() {
  setUpAll(() {
    openTestSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('略過 on 現倉 goes to preview with no holdings', (tester) async {
    final env = await _env();
    addTearDown(env.dispose);
    await _pump(tester, env);
    await _openOpening(tester);

    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();
    expect(find.text('現倉'), findsWidgets);
    expect(find.byKey(const Key('opening-skip')), findsOneWidget);
    expect(find.text('沒有現倉可略過，直接進入預覽'), findsOneWidget);

    await tester.tap(find.byKey(const Key('opening-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('opening-title')), findsOneWidget);
    expect(find.text('預覽開帳'), findsOneWidget);
    expect(find.byKey(const Key('opening-save')), findsOneWidget);
    expect(find.textContaining('現倉'), findsWidgets);
    expect(find.textContaining('0 檔'), findsOneWidget);
  });

  testWidgets('下一步 on 現倉 with no holdings also goes to preview', (tester) async {
    final env = await _env();
    addTearDown(env.dispose);
    await _pump(tester, env);
    await _openOpening(tester);

    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();
    expect(find.text('預覽開帳'), findsOneWidget);
    expect(find.byKey(const Key('opening-save')), findsOneWidget);
  });
}

class _Env {
  _Env({required this.api, required this.lock, required this.close});

  final LocalApi api;
  final LockController lock;
  final Future<void> Function() close;

  Future<void> dispose() async {
    lock.dispose();
    await close();
  }
}

Future<_Env> _env() async {
  final h = Harness();
  await h.setUp();
  await h.book('生活');
  final lock = LockController(
    auth: AlwaysAllowAuth(),
    store: MemorySecureStore(),
    observeLifecycle: false,
  );
  return _Env(api: h.api, lock: lock, close: h.tearDown);
}

Future<void> _pump(WidgetTester tester, _Env env) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(FullJizhangApp(api: env.api, lock: env.lock));
  await tester.pumpAndSettle();
}

Future<void> _openOpening(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('settings-opening')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('opening-title')), findsOneWidget);
}
