import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';

import 'support/fake_api.dart';
import 'support/pump_app.dart';

FakeApi _booked() {
  return FakeApi()
    ..current = sampleUser(lastBookId: 'b1')
    ..books = [sampleBook()];
}

void main() {
  setUpAll(configureTestFonts);

  testWidgets('analytics draws daily and category charts', (tester) async {
    final today = taipeiToday();
    final api = _booked()
      ..daily = [
        DailyPoint(date: '${today.substring(0, 8)}01', expense: 100, income: 0, cashNet: 1000),
        DailyPoint(date: today, expense: 240, income: 50, cashNet: 800),
      ]
      ..slices = [
        const CategoryAmount(categoryId: 'c1', name: '餐飲', amount: 240),
        const CategoryAmount(categoryId: 'c2', name: '交通', amount: 100),
      ]
      ..entries = [
        sampleEntry(date: today, amount: 240, note: '午餐', categoryId: 'c1'),
      ];
    await pumpApp(tester, api);
    await tester.tap(find.byKey(const Key('nav-analytics')));
    await tester.pumpAndSettle();

    expect(find.text('分析'), findsOneWidget);
    expect(find.text('本月'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.byKey(const Key('pie-total')), findsOneWidget);
    expect(find.text('餐飲'), findsOneWidget);

    await tester.tap(find.byKey(const Key('slice-c1')));
    await tester.pumpAndSettle();
    expect(find.text('這個分類'), findsOneWidget);
    expect(find.textContaining('午餐'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trend-cash')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('trend-subtitle'))).data,
      contains('不含持倉'),
    );

    await tester.tap(find.byKey(const Key('month-next')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('analytics-month'))).data,
      '本月',
    );

    await tester.tap(find.byKey(const Key('month-prev')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('analytics-month'))).data,
      isNot('本月'),
    );
  });

  testWidgets('a month with no spending shows the empty chart state', (
    tester,
  ) async {
    final api = _booked();
    await pumpApp(tester, api);
    await tester.tap(find.byKey(const Key('nav-analytics')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('analytics-empty')), findsOneWidget);
    expect(find.text('這個月還沒有支出'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(PieChart), findsNothing);
  });
}
