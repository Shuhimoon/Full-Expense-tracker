import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';

import 'support/fake_api.dart';
import 'support/pump_app.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Future<FakeApi> _openSheet(
  WidgetTester tester, {
  String openingDate = '2020-01-01',
  List<Account>? accounts,
  List<Category>? categories,
}) async {
  final api = FakeApi()
    ..current = sampleUser(lastBookId: 'b1')
    ..books = [sampleBook(openingDate: openingDate)]
    ..accounts = accounts ?? [sampleAccount()]
    ..categories =
        categories ??
        [
          sampleCategory(),
          sampleCategory(id: 'c2', name: '薪資', kind: 'income', isSystem: true),
        ];
  await pumpApp(tester, api);
  await tester.tap(find.byKey(const Key('fab-record')));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(configureTestFonts);

  testWidgets('saving an expense posts the body and an idempotency key', (
    tester,
  ) async {
    final api = await _openSheet(tester);
    await tester.enterText(find.byKey(const Key('record-amount')), '120');
    await tester.enterText(find.byKey(const Key('record-note')), '咖啡');
    await tester.tap(find.byKey(const Key('record-save')));
    await tester.pumpAndSettle();

    expect(api.createEntryCalls, 1);
    expect(api.lastEntryBody?['type'], 'expense');
    expect(api.lastEntryBody?['amount'], 120);
    expect(api.lastEntryBody?['account_id'], 'a1');
    expect(api.lastEntryBody?['category_id'], 'c1');
    expect(api.lastEntryBody?['date'], taipeiToday());
    expect(api.lastEntryBody?['note'], '咖啡');
    expect(api.lastIdempotencyKey, matches(_uuid));
    expect(find.text('記一筆'), findsNothing);
    expect(find.text('咖啡'), findsOneWidget);
  });

  testWidgets('income and transfer use the matching fields', (tester) async {
    final api = await _openSheet(
      tester,
      accounts: [
        sampleAccount(),
        sampleAccount(id: 'a2', name: '銀行', type: 'bank'),
      ],
    );

    await tester.tap(find.byKey(const Key('record-tab-income')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('record-amount')), '500');
    await tester.tap(find.byKey(const Key('record-save')));
    await tester.pumpAndSettle();

    expect(api.lastEntryBody?['type'], 'income');
    expect(api.lastEntryBody?['category_id'], 'c2');
    expect(api.lastEntryBody?['amount'], 500);

    await tester.tap(find.byKey(const Key('fab-record')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-tab-transfer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-to')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-a2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('record-amount')), '30');
    await tester.tap(find.byKey(const Key('record-done')));
    await tester.pumpAndSettle();

    expect(api.lastEntryBody?['type'], 'transfer');
    expect(api.lastEntryBody?['to_account_id'], 'a2');
    expect(api.lastEntryBody?.containsKey('category_id'), isFalse);
    expect(api.lastIdempotencyKey, matches(_uuid));
  });

  testWidgets('dates before the opening date are rejected before POST', (
    tester,
  ) async {
    final api = await _openSheet(tester, openingDate: '2099-01-01');
    await tester.enterText(find.byKey(const Key('record-amount')), '50');
    await tester.tap(find.byKey(const Key('record-save')));
    await tester.pumpAndSettle();

    expect(find.text('不能記開帳日之前的帳'), findsOneWidget);
    expect(api.createEntryCalls, 0);
    expect(find.text('記一筆'), findsOneWidget);
  });

  testWidgets('the date dialog blocks a day before opening', (tester) async {
    final api = await _openSheet(tester, openingDate: taipeiToday());
    await tester.tap(find.byKey(const Key('record-date')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('record-date-field')), '1999-01-01');
    await tester.tap(find.byKey(const Key('record-date-ok')));
    await tester.pumpAndSettle();

    expect(find.text('不能記開帳日之前的帳'), findsOneWidget);
    expect(find.byKey(const Key('record-date-field')), findsOneWidget);
    expect(api.createEntryCalls, 0);
  });

  testWidgets('a 422 error message from the API is shown', (tester) async {
    final api = await _openSheet(tester)
      ..createEntryError = '修改後持倉會變負數'
      ..createEntryStatus = 422;
    await tester.enterText(find.byKey(const Key('record-amount')), '10');
    await tester.tap(find.byKey(const Key('record-save')));
    await tester.pumpAndSettle();

    expect(find.text('修改後持倉會變負數'), findsOneWidget);
    expect(api.createEntryCalls, 1);
    expect(api.createEntryStatus, 422);
    expect(find.text('記一筆'), findsOneWidget);
  });

  testWidgets('a trade sends the asset class and price currency', (
    tester,
  ) async {
    final api = await _openSheet(
      tester,
      accounts: [sampleAccount(id: 'a9', name: '幣安', type: 'exchange')],
    );
    await tester.tap(find.byKey(const Key('record-tab-trade')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('record-asset')));
    await tester.tap(find.byKey(const Key('record-asset')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick-tw_stock')), findsOneWidget);
    expect(find.byKey(const Key('pick-us_stock')), findsOneWidget);
    expect(find.byKey(const Key('pick-crypto')), findsOneWidget);
    expect(find.byKey(const Key('pick-fx')), findsOneWidget);
    expect(find.text('USDT'), findsNothing);
    await tester.tap(find.byKey(const Key('pick-crypto')));
    await tester.pumpAndSettle();
    expect(find.text('加密貨幣'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('record-price-ccy')));
    await tester.tap(find.byKey(const Key('record-price-ccy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick-TWD')), findsOneWidget);
    expect(find.byKey(const Key('pick-USD')), findsOneWidget);
    expect(find.text('EUR'), findsNothing);
    await tester.tap(find.byKey(const Key('pick-TWD')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('record-symbol')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('record-symbol-field')), 'btc');
    await tester.tap(find.byKey(const Key('record-text-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-qty')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('record-qty-field')), '0.25');
    await tester.tap(find.byKey(const Key('record-text-ok')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('record-price')));
    await tester.tap(find.byKey(const Key('record-price')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('record-price-field')), '100');
    await tester.tap(find.byKey(const Key('record-text-ok')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('record-save')));
    await tester.tap(find.byKey(const Key('record-save')));
    await tester.pumpAndSettle();

    expect(api.createTradeCalls, 1);
    expect(api.lastTradeBody?['asset_class'], 'crypto');
    expect(api.lastTradeBody?['price_ccy'], 'TWD');
    expect(api.lastTradeBody?['quote_currency'], 'TWD');
    expect(api.lastTradeBody?['symbol'], 'BTC');
    expect(api.lastTradeBody?['side'], 'buy');
    expect(api.lastTradeBody?['qty'], '0.25');
    expect(api.lastTradeBody?['price'], '100');
    expect(api.lastTradeBody?['account_id'], 'a9');
    expect(api.lastTradeKey, matches(_uuid));
  });
}
