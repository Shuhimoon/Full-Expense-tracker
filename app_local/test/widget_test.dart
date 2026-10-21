import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/app.dart';
import 'package:full_jizhang/data/database.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/services/local_api.dart';
import 'package:full_jizhang/services/secure_store.dart';
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
    // Memory store: this test must not touch the platform keystore.
    // Empty store and no legacy flag means the lock is off, so bootstrap
    // clears the fail-closed cover and the ledger shows with no login.
    final lock = LockController(
      auth: AlwaysAllowAuth(),
      store: MemorySecureStore(),
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
