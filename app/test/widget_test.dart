import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';
import 'support/pump_app.dart';

void main() {
  setUpAll(configureTestFonts);

  testWidgets('logged-out launch shows the glass login form', (tester) async {
    await pumpApp(tester, FakeApi());

    expect(find.text('Full 記帳'), findsOneWidget);
    expect(find.text('個人帳簿 · 淨資產一目了然'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('密碼'), findsOneWidget);
    expect(find.text('忘記密碼？'), findsOneWidget);
    expect(find.text('還沒帳號？'), findsOneWidget);
    expect(find.text('資料只屬於你 · Email＋密碼登入'), findsOneWidget);
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
    expect(find.byKey(const Key('nav-ledger')), findsNothing);
  });

  testWidgets('register blocks short passwords and login shows the API error', (
    tester,
  ) async {
    final api = FakeApi()..loginError = '帳號或密碼不對';
    await pumpApp(tester, api);

    await tester.tap(find.byKey(const Key('auth-tab-register')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('email-field')),
      'shuhi@example.com',
    );
    await tester.enterText(find.byKey(const Key('password-field')), 'short');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(find.text('密碼至少 8 碼'), findsOneWidget);
    expect(api.registers, 0);

    await tester.tap(find.byKey(const Key('auth-tab-login')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('password-field')), 'password1');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('帳號或密碼不對'), findsOneWidget);
    expect(api.logins, 1);
    expect(find.byKey(const Key('nav-ledger')), findsNothing);
  });

  testWidgets('login opens the ledger shell, record sheet, and logout', (
    tester,
  ) async {
    final api = FakeApi();
    await pumpApp(tester, api);
    await login(tester);

    expect(find.text('建立帳本'), findsOneWidget);
    expect(find.byKey(const Key('nav-ledger')), findsOneWidget);
    expect(api.logins, 1);

    await tester.tap(find.byKey(const Key('nav-analytics')));
    await tester.pumpAndSettle();
    expect(find.text('分析'), findsOneWidget);
    expect(find.byKey(const Key('analytics-empty-book')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-assets')));
    await tester.pumpAndSettle();
    expect(find.text('資產'), findsOneWidget);

    await tester.tap(find.byKey(const Key('fab-record')));
    await tester.pumpAndSettle();
    expect(find.text('記一筆'), findsOneWidget);
    expect(find.text('資產'), findsOneWidget);
    expect(find.byKey(const Key('nav-ledger')), findsOneWidget);

    await tester.tap(find.byKey(const Key('record-close')));
    await tester.pumpAndSettle();
    expect(find.text('記一筆'), findsNothing);
    expect(find.text('資產'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-settings')));
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsOneWidget);
    expect(find.text('shuhi@example.com'), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();

    expect(api.logouts, 1);
    expect(find.text('Full 記帳'), findsOneWidget);
    expect(find.byKey(const Key('nav-settings')), findsNothing);
  });
}
