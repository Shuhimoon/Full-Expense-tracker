import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';

import 'support/fake_api.dart';
import 'support/pump_app.dart';

String _shift(String iso, int days) {
  final parts = iso.split('-');
  final date = DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  ).add(Duration(days: days));
  return '${date.year}-${pad2(date.month)}-${pad2(date.day)}';
}

void main() {
  setUpAll(configureTestFonts);

  testWidgets('no book shows a create-book call to POST /api/books', (
    tester,
  ) async {
    final api = FakeApi()..current = sampleUser();
    await pumpApp(tester, api);

    expect(find.text('還沒有帳本'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    await tester.tap(find.byKey(const Key('home-create-book')));
    await tester.pumpAndSettle();

    expect(api.books.single.name, '生活');
    expect(find.byKey(const Key('book-switcher')), findsOneWidget);
    expect(find.byKey(const Key('home-today')), findsOneWidget);
    expect(find.byKey(const Key('home-empty')), findsOneWidget);
  });

  testWidgets('home shows spend, net worth, and a day-grouped ledger', (
    tester,
  ) async {
    final today = taipeiToday();
    final yesterday = _shift(today, -1);
    final api = FakeApi()
      ..current = sampleUser(lastBookId: 'b1')
      ..books = [sampleBook()]
      ..accounts = [sampleAccount(), sampleAccount(id: 'a2', name: '銀行', type: 'bank')]
      ..categories = [sampleCategory(), sampleCategory(id: 'c2', name: '薪資', kind: 'income')]
      ..entries = [
        sampleEntry(date: today, amount: 85, note: '午餐'),
        sampleEntry(
          id: 'e2',
          date: yesterday,
          type: 'income',
          amount: 50000,
          categoryId: 'c2',
          note: '薪水',
          createdAt: '2026-10-19T01:00:00Z',
        ),
      ]
      ..summary = StatsSummary(
        todayExpense: 120,
        monthExpense: 3400,
        monthIncome: 50000,
        netWorth: 1250000,
        netWorthChangeVsOpening: 5000,
        cashNet: 350000,
        positionMv: 900000,
        unrealized: 12000,
        quoteAsOf: '2026-10-20T01:05:00Z',
        somePositionsUnquoted: false,
        today: today,
        month: today.substring(0, 7),
      );

    await pumpApp(tester, api);

    expect(find.text('生活'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('quote-time'))).data,
      '報價 09:05',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('home-today'))).data,
      'NT\$120',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('home-month'))).data,
      'NT\$3,400',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('home-net'))).data,
      'NT\$1,250,000',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('home-delta'))).data,
      '↑ NT\$5,000 · 自開帳日',
    );
    expect(find.byKey(Key('day-$today')), findsOneWidget);
    expect(find.byKey(Key('day-$yesterday')), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('entry-e1'))).data, '−85');
    expect(tester.widget<Text>(find.byKey(const Key('entry-e2'))).data, '+50,000');
    expect(find.text('午餐'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(PieChart), findsNothing);
  });

  testWidgets('book switcher selects another book', (tester) async {
    final api = FakeApi()
      ..current = sampleUser(lastBookId: 'b1')
      ..books = [sampleBook(), sampleBook(id: 'b2', name: '投資')];
    await pumpApp(tester, api);

    await tester.tap(find.byKey(const Key('book-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-b2')));
    await tester.pumpAndSettle();

    expect(find.text('投資'), findsOneWidget);
    expect(find.text('生活'), findsNothing);
    expect(api.current?.lastBookId, 'b2');
  });
}
