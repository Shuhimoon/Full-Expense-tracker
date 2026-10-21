import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/pages/record/import_preview_sheet.dart';
import 'package:full_jizhang/services/apple_pay_link.dart';

// The preview sheet is the only place a tick is decided. A duplicate starts
// unticked and is badged 重複. A row before the opening date cannot be
// ticked, and the sheet says 不能記開帳日之前的帳. Confirm sends only the
// ticked rows.

void main() {
  testWidgets('duplicate starts unticked and a pre-opening row cannot be ticked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final when = DateTime.utc(2026, 10, 21, 0, 42);
    List<ImportCommit>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImportPreviewSheet(
            lines: [
              _line(merchant: '星巴克', amount: 185, when: when),
              _line(
                merchant: '星巴克',
                amount: 185,
                when: when,
                duplicate: true,
              ),
              _line(
                merchant: '舊帳',
                amount: 50,
                when: when,
                beforeOpening: true,
                date: '2000-01-01',
              ),
            ],
            accounts: const [
              Account(
                id: 'a1',
                bookId: 'b',
                name: '現金',
                type: 'cash',
                archivedAt: null,
                version: 1,
                cashBalance: 0,
                positionMv: null,
              ),
            ],
            categories: const [
              Category(
                id: 'c1',
                bookId: 'b',
                name: '餐飲',
                kind: 'expense',
                isSystem: false,
                archivedAt: null,
                sort: 0,
                version: 1,
              ),
            ],
            onConfirm: (rows) async {
              saved = rows;
              return rows.length;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('重複'), findsOneWidget);
    expect(find.text('不能記開帳日之前的帳'), findsOneWidget);
    expect(find.text('確認匯入（1 筆）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-toggle-2')));
    await tester.pump();
    expect(find.text('確認匯入（1 筆）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-toggle-1')));
    await tester.pump();
    expect(find.text('確認匯入（2 筆）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-confirm')));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!, hasLength(2));
    expect(saved!.map((row) => row.merchant), ['星巴克', '星巴克']);
    expect(saved!.every((row) => row.date != '2000-01-01'), isTrue);
  });
}

ImportLine _line({
  required String merchant,
  required int amount,
  required DateTime when,
  bool duplicate = false,
  bool beforeOpening = false,
  String date = '2026-10-21',
}) {
  return ImportLine(
    importKey: '$merchant-$amount-$duplicate-$beforeOpening',
    amount: amount,
    merchant: merchant,
    cardLabel: '玉山',
    cardLast4: '4321',
    note: merchant,
    occurredAt: when,
    date: date,
    duplicate: duplicate,
    beforeOpening: beforeOpening,
    categoryId: 'c1',
    accountId: 'a1',
  );
}
