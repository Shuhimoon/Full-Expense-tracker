import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/auth.dart';
import 'package:full_jizhang/router.dart';
import 'package:full_jizhang/theme.dart';
import 'package:go_router/go_router.dart';

class FullJizhangApp extends StatefulWidget {
  const FullJizhangApp({super.key, this.api});

  /// Injected in tests. Production builds a [DioApiClient].
  final ApiClient? api;

  @override
  State<FullJizhangApp> createState() => _FullJizhangAppState();
}

class _FullJizhangAppState extends State<FullJizhangApp> {
  late final AuthController _auth;
  late final GoRouter _router;
  late final ThemeData _theme;

  @override
  void initState() {
    super.initState();
    _theme = buildAppTheme();
    _auth = AuthController(api: widget.api ?? DioApiClient());
    _router = createRouter(_auth);
    _auth.bootstrap();
  }

  @override
  void dispose() {
    _router.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: _auth,
      child: MaterialApp.router(
        title: 'Full 記帳',
        theme: _theme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
