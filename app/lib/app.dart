import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/auth.dart';
import 'package:full_jizhang/router.dart';
import 'package:full_jizhang/session/books.dart';
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
  late final BookController _books;
  late final GoRouter _router;
  late final ThemeData _theme;
  String? _userId;
  bool _authReady = false;

  @override
  void initState() {
    super.initState();
    _theme = buildAppTheme();
    _auth = AuthController(api: widget.api ?? DioApiClient());
    _books = BookController(api: _auth.api, auth: _auth);
    _auth.addListener(_onAuth);
    _router = createRouter(_auth);
    _auth.bootstrap();
  }

  void _onAuth() {
    if (!_auth.ready) return;
    final id = _auth.user?.id;
    if (_authReady && id == _userId) return;
    _authReady = true;
    _userId = id;
    _books.reload();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    _router.dispose();
    _books.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: _auth,
      child: BookScope(
        books: _books,
        child: MaterialApp.router(
          title: 'Full 記帳',
          theme: _theme,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
