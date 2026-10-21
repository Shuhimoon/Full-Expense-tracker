import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/app.dart';
import 'package:full_jizhang/data/database.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/services/local_api.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rules/harness.dart';

/// Local shell smoke test. The app opens on the ledger with no login screen.
/// The lock controller is injected so the test does not touch device auth.
void main() {
  setUpAll(() {
    openTestSqlite();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('launch shows ledger shell without login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final api = LocalApi(db);
    final lock = LockController(
      auth: AlwaysAllowAuth(),
      observeLifecycle: false,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FullJizhangApp(api: api, lock: lock));
    await tester.pumpAndSettle();

    expect(find.text('建立帳本'), findsOneWidget);
    expect(find.byKey(const Key('nav-ledger')), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('登出'), findsNothing);
  });
}
