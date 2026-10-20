import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/app.dart';
import 'package:google_fonts/google_fonts.dart';

void configureTestFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

Future<void> pumpApp(WidgetTester tester, ApiClient api) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(FullJizhangApp(api: api));
  await tester.pumpAndSettle();
}

Future<void> login(
  WidgetTester tester, {
  String email = 'shuhi@example.com',
  String password = 'password1',
}) async {
  await tester.enterText(find.byKey(const Key('email-field')), email);
  await tester.enterText(find.byKey(const Key('password-field')), password);
  await tester.tap(find.byKey(const Key('auth-submit')));
  await tester.pumpAndSettle();
}
