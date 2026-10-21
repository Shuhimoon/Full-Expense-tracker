import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/pages/settings/auto_record_page.dart';
import 'package:full_jizhang/services/apple_pay_link.dart';
import 'package:go_router/go_router.dart';

// 設定 → 自動記帳. iOS shows the shortcut steps and a copyable URL. The
// 取得捷徑 action is a disabled placeholder labelled 即將提供. Android says
// 不支援 and 去記一筆 opens the record route. Nothing on this page writes
// a ledger row.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS setup copies the URL and leaves the shortcut disabled', (
    tester,
  ) async {
    // Cleared before the test returns. The binding checks this flag before
    // tearDown, and a leftover override fails the next test.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The widget test binding does not answer Clipboard.setData, so the
    // copy future would never finish. This handler stores the text.
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          copiedText = args['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': copiedText};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    try {
      await tester.pumpWidget(
        const MaterialApp(home: AutoRecordPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('iOS 17 以上（iOS 26 起觸發條件名稱為「錢包」）'), findsOneWidget);
      expect(find.text('iPhone XS/XR 以上'), findsOneWidget);
      expect(find.text('僅限實體店感應支付'), findsOneWidget);
      expect(find.text('錢包需開啟行動數據'), findsOneWidget);
      expect(find.text(applePayUrlTemplate), findsOneWidget);
      expect(find.text('即將提供'), findsOneWidget);
      expect(find.text('取得捷徑'), findsNothing);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('auto-shortcut')),
      );
      expect(button.onPressed, isNull);

      final copy = find.byKey(const Key('auto-copy-url'));
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auto-copied')), findsOneWidget);
      expect(copiedText, applePayUrlTemplate);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android says unsupported and 去記一筆 opens the record sheet', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      await _pumpAndroid(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _pumpAndroid(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/settings/auto-record',
    routes: [
      GoRoute(
        path: '/settings/auto-record',
        builder: (context, state) => const AutoRecordPage(),
      ),
      GoRoute(
        path: '/record',
        builder: (context, state) => const Scaffold(
          body: Text('記一筆開了', key: Key('record-opened')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('auto-android-title')), findsOneWidget);
  expect(find.text('目前只支援 iPhone'), findsOneWidget);
  expect(find.text('即將提供'), findsNothing);

  await tester.tap(find.byKey(const Key('auto-go-record')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('record-opened')), findsOneWidget);
}
