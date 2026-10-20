import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/models/ledger.dart';

import 'support/fake_api.dart';
import 'support/pump_app.dart';

void main() {
  setUpAll(configureTestFonts);

  testWidgets('assets lists accounts, holdings, and a liability hint', (
    tester,
  ) async {
    final api = FakeApi()
      ..current = sampleUser(lastBookId: 'b1')
      ..books = [sampleBook()]
      ..accounts = [
        sampleAccount(cashBalance: 8000),
        sampleAccount(
          id: 'a2',
          name: '台新',
          type: 'broker',
          cashBalance: 20000,
          positionMv: 900000,
        ),
      ]
      ..positions = [
        samplePosition(),
        samplePosition(
          id: 'p2',
          symbol: 'BTC',
          name: 'Bitcoin',
          assetClass: 'crypto',
          qty: '0.5',
          accountName: '交易所',
          marketValue: 1500000,
          unrealizedPct: '-3.5',
        ),
      ]
      ..summary = StatsSummary(
        todayExpense: 0,
        monthExpense: 0,
        monthIncome: 0,
        netWorth: 2428000,
        netWorthChangeVsOpening: -1000,
        cashNet: 28000,
        positionMv: 2400000,
        unrealized: 12000,
        quoteAsOf: null,
        somePositionsUnquoted: false,
        today: '2026-10-20',
        month: '2026-10',
      );
    await pumpApp(tester, api);
    await tester.tap(find.byKey(const Key('nav-assets')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assets-net')), findsOneWidget);
    expect(find.text('NT\$2,428,000'), findsOneWidget);
    expect(find.byKey(const Key('account-a1')), findsOneWidget);
    expect(find.text('NT\$8,000'), findsOneWidget);
    expect(find.text('台積電 2330'), findsOneWidget);
    expect(find.textContaining('100 股'), findsOneWidget);
    expect(find.textContaining('0.5 ·'), findsWidgets);
    expect(find.textContaining('0.5 股'), findsNothing);
    expect(find.byKey(const Key('assets-no-debt')), findsOneWidget);
    expect(find.byKey(const Key('assets-no-positions')), findsNothing);

    api.quoteRefresh = const QuoteRefresh(
      updated: 0,
      failed: ['2330'],
      message: '部分報價失敗',
      quoteFailed: true,
    );
    await tester.tap(find.byKey(const Key('assets-refresh')));
    await tester.pumpAndSettle();
    expect(api.quoteRefreshes, 1);
    expect(find.text('部分報價失敗'), findsOneWidget);
  });

  testWidgets('a credit card is shown as debt and hides the empty hint', (
    tester,
  ) async {
    final api = FakeApi()
      ..current = sampleUser(lastBookId: 'b1')
      ..books = [sampleBook()]
      ..accounts = [
        sampleAccount(
          id: 'card',
          name: '玉山卡',
          type: 'credit_card',
          cashBalance: 3200,
        ),
      ];
    await pumpApp(tester, api);
    await tester.tap(find.byKey(const Key('nav-assets')));
    await tester.pumpAndSettle();

    expect(find.text('欠 NT\$3,200'), findsOneWidget);
    expect(find.byKey(const Key('assets-no-debt')), findsNothing);
    expect(find.byKey(const Key('assets-no-positions')), findsOneWidget);
  });

  testWidgets('adding an account posts the name and type', (tester) async {
    final api = FakeApi()
      ..current = sampleUser(lastBookId: 'b1')
      ..books = [sampleBook()];
    await pumpApp(tester, api);
    await tester.tap(find.byKey(const Key('nav-assets')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assets-add-account')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('account-name-field')), '薪資戶');
    await tester.tap(find.byKey(const Key('account-create')));
    await tester.pumpAndSettle();

    expect(api.accounts.single.name, '薪資戶');
    expect(api.accounts.single.type, 'cash');
    expect(find.text('薪資戶'), findsOneWidget);
  });
}
