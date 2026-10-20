import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/app.dart';
import 'package:google_fonts/google_fonts.dart';

class FakeApi implements ApiClient {
  AppUser? current;
  String? loginError;
  String? registerError;
  String? logoutError;
  int logins = 0;
  int registers = 0;
  int logouts = 0;

  @override
  Future<AppUser> me() async {
    final user = current;
    if (user == null) throw ApiException('請先登入', status: 401);
    return user;
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    logins++;
    final error = loginError;
    if (error != null) throw ApiException(error, status: 401);
    current = AppUser(
      id: 'u1',
      email: email,
      lastBookId: null,
      createdAt: '2026-01-01T00:00:00Z',
    );
    return current!;
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
  }) async {
    registers++;
    final error = registerError;
    if (error != null) throw ApiException(error, status: 400);
    current = AppUser(
      id: 'u2',
      email: email,
      lastBookId: null,
      createdAt: '2026-01-01T00:00:00Z',
    );
    return current!;
  }

  @override
  void close() {}

  @override
  Future<void> logout() async {
    logouts++;
    final error = logoutError;
    if (error != null) throw ApiException(error, status: 500);
    current = null;
  }
}

Future<void> pumpApp(WidgetTester tester, ApiClient api) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(FullJizhangApp(api: api));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password1',
    );
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

    await tester.enterText(
      find.byKey(const Key('email-field')),
      'shuhi@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password-field')),
      'password1',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('帳本'), findsOneWidget);
    expect(find.byKey(const Key('nav-ledger')), findsOneWidget);
    expect(api.logins, 1);

    await tester.tap(find.byKey(const Key('nav-analytics')));
    await tester.pumpAndSettle();
    expect(find.text('分析圖'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-assets')));
    await tester.pumpAndSettle();
    expect(find.text('資產'), findsOneWidget);

    await tester.tap(find.byKey(const Key('fab-record')));
    await tester.pumpAndSettle();
    expect(find.text('記一筆'), findsOneWidget);
    expect(find.byKey(const Key('nav-ledger')), findsNothing);

    await tester.tap(find.byKey(const Key('record-close')));
    await tester.pumpAndSettle();
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
