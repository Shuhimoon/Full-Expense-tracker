import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/models/ledger.dart';

import 'support/fake_api.dart';
import 'support/pump_app.dart';

Future<FakeApi> _openHome(
  WidgetTester tester, {
  String? openingDate = '2020-01-01',
  String createdAt = '2026-01-01T00:00:00Z',
  List<Account>? accounts,
  bool withOpeningEntry = false,
}) async {
  final api = FakeApi()
    ..current = sampleUser(lastBookId: 'b1')
    ..books = [
      sampleBook(openingDate: openingDate, createdAt: createdAt),
    ]
    ..accounts =
        accounts ??
        [
          sampleAccount(),
          sampleAccount(id: 'a2', name: '富邦證券', type: 'broker', cashBalance: 0),
          sampleAccount(id: 'a3', name: '卡', type: 'credit_card', cashBalance: 0),
        ];
  if (withOpeningEntry) {
    api.entries = [
      sampleEntry(
        type: 'opening_balance',
        date: '2020-01-01',
        amount: 10,
        categoryId: null,
        note: '開帳',
      ),
    ];
  }
  await pumpApp(tester, api);
  return api;
}

Future<void> _toPreview(WidgetTester tester) async {
  for (var step = 0; step < 3; step++) {
    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(configureTestFonts);

  testWidgets('a new book offers opening from the ledger, then hides it', (
    tester,
  ) async {
    final api = await _openHome(tester);
    expect(find.byKey(const Key('home-opening')), findsOneWidget);
    expect(find.text('開帳為選填，可帶入現有餘額與持倉。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-opening')));
    await tester.pumpAndSettle();
    expect(find.text('選開帳日'), findsOneWidget);
    expect(find.text('2020-01-01'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('opening-day-2020-01-15')));
    await tester.tap(find.byKey(const Key('opening-day-2020-01-15')));
    await tester.pumpAndSettle();
    expect(find.text('2020-01-15'), findsOneWidget);

    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();
    expect(find.text('帳戶餘額'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('opening-amount-a1')), '1000');
    await tester.enterText(find.byKey(const Key('opening-amount-a2')), '50');
    await tester.enterText(find.byKey(const Key('opening-amount-a3')), '20');
    await tester.pump();

    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();
    expect(find.text('現倉'), findsOneWidget);

    await tester.tap(find.byKey(const Key('opening-add-position')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('opening-symbol-0')), 'btc');
    await tester.enterText(find.byKey(const Key('opening-qty-0')), '1.5');
    await tester.enterText(find.byKey(const Key('opening-cost-0')), '30');
    await tester.ensureVisible(find.byKey(const Key('opening-asset-0')));
    await tester.tap(find.byKey(const Key('opening-asset-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pick-tw_stock')), findsOneWidget);
    expect(find.byKey(const Key('pick-us_stock')), findsOneWidget);
    expect(find.byKey(const Key('pick-crypto')), findsOneWidget);
    expect(find.byKey(const Key('pick-fx')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pick-crypto')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();
    expect(find.text('預覽開帳'), findsOneWidget);
    expect(find.textContaining('鎖定'), findsNothing);
    expect(find.text('2 戶 · NT\$1,050'), findsOneWidget);
    expect(find.text('1 戶 · 欠 NT\$20'), findsOneWidget);
    expect(find.text('1 檔 · 成本 NT\$30'), findsOneWidget);
    expect(find.text('NT\$1,060'), findsOneWidget);

    await tester.tap(find.byKey(const Key('opening-revise')));
    await tester.pumpAndSettle();
    expect(find.text('選開帳日'), findsOneWidget);
    expect(api.putOpeningCalls, 0);

    await _toPreview(tester);
    await tester.tap(find.byKey(const Key('opening-save')));
    await tester.pumpAndSettle();

    expect(api.putOpeningCalls, 1);
    expect(api.lastOpeningBody?['opening_date'], '2020-01-15');
    final accounts = api.lastOpeningBody?['accounts'] as List;
    expect(accounts, hasLength(3));
    expect(accounts[0], {'account_id': 'a1', 'amount': 1000});
    expect(accounts[2], {'account_id': 'a3', 'amount': 20});
    final positions = api.lastOpeningBody?['positions'] as List;
    expect(positions, hasLength(1));
    expect(positions.single['symbol'], 'BTC');
    expect(positions.single['asset_class'], 'crypto');
    expect(positions.single['quote_currency'], 'USD');
    expect(positions.single['qty'], '1.5');
    expect(positions.single['cost_twd'], '30');
    expect(positions.single['cost_unknown'], isFalse);
    expect(find.byKey(const Key('book-switcher')), findsOneWidget);
    expect(find.byKey(const Key('home-opening')), findsNothing);
  });

  testWidgets('the date defaults to the book creation day', (tester) async {
    await _openHome(
      tester,
      openingDate: null,
      createdAt: '2026-03-15T18:00:00Z',
      accounts: [sampleAccount()],
    );
    await tester.tap(find.byKey(const Key('home-opening')));
    await tester.pumpAndSettle();

    expect(find.text('2026-03-16'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('opening-month'))).data,
      '2026 年 3 月',
    );
  });

  testWidgets('an earlier-entry rejection is shown on the date step', (
    tester,
  ) async {
    final api = await _openHome(tester, accounts: [sampleAccount()]);
    api.openingError = '已有早於新開帳日的紀錄（2020-01-01），不能把開帳日往後改';
    api.openingStatus = 400;
    await tester.tap(find.byKey(const Key('home-opening')));
    await tester.pumpAndSettle();
    await _toPreview(tester);
    await tester.tap(find.byKey(const Key('opening-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('opening-error')), findsOneWidget);
    expect(
      find.text('已有早於新開帳日的紀錄（2020-01-01），不能把開帳日往後改'),
      findsOneWidget,
    );
    expect(find.text('選開帳日'), findsOneWidget);
    expect(api.putOpeningCalls, 1);
    expect(find.text('預覽開帳'), findsNothing);
  });

  testWidgets('a 422 holding error stays on the preview', (tester) async {
    final api = await _openHome(tester, accounts: [sampleAccount()]);
    api.openingError = '修改後持倉會變負數';
    api.openingStatus = 422;
    await tester.tap(find.byKey(const Key('home-opening')));
    await tester.pumpAndSettle();
    await _toPreview(tester);
    await tester.tap(find.byKey(const Key('opening-save')));
    await tester.pumpAndSettle();

    expect(find.text('修改後持倉會變負數'), findsOneWidget);
    expect(find.text('預覽開帳'), findsOneWidget);
    expect(api.openingStatus, 422);
  });

  testWidgets('unknown cost is flagged and confirmed before save', (
    tester,
  ) async {
    final api = await _openHome(
      tester,
      accounts: [
        sampleAccount(id: 'a2', name: '富邦證券', type: 'broker'),
      ],
    );
    await tester.tap(find.byKey(const Key('home-opening')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opening-add-position')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('opening-symbol-0')), '2330');
    await tester.enterText(find.byKey(const Key('opening-qty-0')), '10');
    await tester.tap(find.byKey(const Key('opening-unknown-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opening-next')));
    await tester.pumpAndSettle();

    expect(find.text('有持倉成本未填'), findsOneWidget);
    await tester.tap(find.byKey(const Key('opening-save')));
    await tester.pumpAndSettle();
    expect(find.text('有持倉成本未填，未實現會偏大。仍要儲存？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('opening-unknown-cancel')));
    await tester.pumpAndSettle();
    expect(api.putOpeningCalls, 0);

    await tester.tap(find.byKey(const Key('opening-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('opening-unknown-confirm')));
    await tester.pumpAndSettle();

    final positions = api.lastOpeningBody?['positions'] as List;
    expect(positions.single['cost_unknown'], isTrue);
    expect(positions.single['cost_twd'], '0');
    expect(positions.single['asset_class'], 'tw_stock');
    expect(positions.single['quote_currency'], 'TWD');
    expect(api.putOpeningCalls, 1);
  });

  testWidgets('the ledger hides the offer after an opening balance exists', (
    tester,
  ) async {
    await _openHome(tester, withOpeningEntry: true);
    expect(find.byKey(const Key('home-opening')), findsNothing);
  });
}
