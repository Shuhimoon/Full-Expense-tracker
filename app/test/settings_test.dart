import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_api.dart';
import 'support/pump_app.dart';

Future<FakeApi> _openSettings(WidgetTester tester) async {
  final api = FakeApi()
    ..current = sampleUser(lastBookId: 'b1', email: 'shuhi@example.com')
    ..books = [sampleBook(), sampleBook(id: 'b2', name: '投資')]
    ..categories = [sampleCategory()];
  await pumpApp(tester, api);
  await tester.tap(find.byKey(const Key('nav-settings')));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(configureTestFonts);

  testWidgets('settings shows the account and disables unsupported rows', (
    tester,
  ) async {
    await _openSettings(tester);

    expect(find.byKey(const Key('settings-email')), findsOneWidget);
    expect(find.text('shuhi@example.com'), findsOneWidget);
    expect(find.text('帳本管理'), findsOneWidget);
    expect(find.text('分類管理'), findsOneWidget);
    expect(find.text('開始開帳'), findsOneWidget);
    expect(find.text('銀行自動同步'), findsOneWidget);
    expect(find.text('這個版本沒有'), findsOneWidget);
    expect(
      find.text('新帳本可直接記帳，開帳為選填。多本帳本各自獨立開帳日。'),
      findsOneWidget,
    );
    expect(
      tester.widget<InkWell>(find.byKey(const Key('settings-disabled'))).onTap,
      isNull,
    );
  });

  testWidgets('opening wizard opens from settings and is not a gate', (
    tester,
  ) async {
    await _openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-opening')));
    await tester.pumpAndSettle();

    expect(find.text('選開帳日'), findsOneWidget);
    expect(find.text('步驟 1／4 · 開帳'), findsOneWidget);
    expect(find.textContaining('鎖定'), findsNothing);

    await tester.tap(find.byKey(const Key('opening-back')));
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsOneWidget);
    expect(find.byKey(const Key('fab-record')), findsOneWidget);
  });

  testWidgets('categories can be added, and system ones cannot be deleted', (
    tester,
  ) async {
    final api = await _openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-categories')));
    await tester.pumpAndSettle();

    expect(find.text('餐飲'), findsOneWidget);
    await tester.tap(find.byKey(const Key('category-delete-c1')));
    await tester.pumpAndSettle();
    expect(find.text('系統分類不能刪，請改封存'), findsOneWidget);
    expect(api.categories.map((item) => item.id), contains('c1'));

    await tester.enterText(find.byKey(const Key('new-category-field')), '零食');
    await tester.tap(find.byKey(const Key('new-category-create')));
    await tester.pumpAndSettle();
    expect(find.text('零食'), findsOneWidget);
  });

  testWidgets('books can be renamed', (tester) async {
    await _openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-books')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('managed-b1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rename-b1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rename-book-field')), '家庭');
    await tester.tap(find.byKey(const Key('rename-book-ok')));
    await tester.pumpAndSettle();

    expect(find.text('家庭'), findsOneWidget);
  });

  testWidgets('backup exports JSON and rejects a bad import', (tester) async {
    final api = await _openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-backup')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('backup-export')));
    await tester.pumpAndSettle();
    expect(find.text('已匯出這本帳'), findsOneWidget);
    expect(find.byKey(const Key('backup-json')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('backup-import-field')), '{');
    await tester.tap(find.byKey(const Key('backup-import')));
    await tester.pumpAndSettle();
    expect(find.text('JSON 格式不對'), findsOneWidget);
    expect(api.imports, 0);
  });

  testWidgets('a short new password is rejected on the client', (tester) async {
    final api = await _openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-password')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('password-old')), 'password1');
    await tester.enterText(find.byKey(const Key('password-new')), 'short');
    await tester.tap(find.byKey(const Key('password-save')));
    await tester.pumpAndSettle();

    expect(find.text('密碼至少 8 碼'), findsOneWidget);
    expect(api.passwordCalls, 0);
  });
}
