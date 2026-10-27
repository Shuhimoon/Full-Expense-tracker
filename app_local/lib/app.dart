import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/lock_screen.dart';
import 'package:full_jizhang/pages/record/import_link_host.dart';
import 'package:full_jizhang/router.dart';
import 'package:full_jizhang/services/incoming_links.dart';
import 'package:full_jizhang/services/secure_store.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:go_router/go_router.dart';

/// Root widget. Owns the book session, the app lock, and the router.
///
/// Production passes a LocalApi built in `main.dart`. Tests inject [api]
/// and, when they need a deterministic gate, [lock]. [LockGate] replaces
/// the navigator until [LockController.ready] and whenever the session is
/// locked (cold start, pause, resume). No protected route is built first.
/// A fulljizhang:// link is queued by [ImportLinkHost] and the preview is
/// built only after that gate is open.
class FullJizhangApp extends StatefulWidget {
  const FullJizhangApp({
    super.key,
    required this.api,
    this.lock,
    this.links,
  });

  /// Injected in tests. Production builds a [LocalApi].
  final ApiClient api;

  /// Injected in tests. Production uses the keystore and device biometrics.
  final LockController? lock;

  /// Injected in tests. Production listens to fulljizhang:// links.
  final IncomingLinks? links;

  @override
  State<FullJizhangApp> createState() => _FullJizhangAppState();
}

class _FullJizhangAppState extends State<FullJizhangApp> {
  late final BookController _books;
  late final LockController _lock;
  late final GoRouter _router;
  late final ThemeData _theme;
  late final bool _ownsLock;
  late final IncomingLinks _links;

  /// Root navigator. The import sheet is presented from this key because
  /// the router builder context is not under a [Navigator].
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _theme = buildAppTheme();
    _books = BookController(api: widget.api);
    _ownsLock = widget.lock == null;
    // Production defaults: PBKDF2 at [productionKdfIterations] via Isolate.run,
    // secrets in the keystore, Face ID only as a shortcut over the password.
    // Tests pass a controller with a fake store and a low iteration count.
    _lock = widget.lock ??
        LockController(
          auth: LocalDeviceAuth(),
          store: const FlutterSecureStore(),
        );
    // Apple Pay shortcuts open fulljizhang://add. Listening does not save.
    // The preview sheet writes only after the user confirms, and only after
    // the lock gate is open. A link that arrives while locked stays queued.
    _links = widget.links ?? IncomingLinks();
    _router = createRouter(_books, navigatorKey: _navigatorKey);
    _books.reload();
    // Launch prompt. If the lock is on, the gate is up before this returns.
    _lock.bootstrap();
  }

  @override
  void dispose() {
    _links.dispose();
    _router.dispose();
    _books.dispose();
    if (_ownsLock) _lock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LockScope(
      lock: _lock,
      child: BookScope(
        books: _books,
        child: MaterialApp.router(
          title: 'Full 記帳',
          theme: _theme,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            // ImportLinkHost stays mounted while locked so a fulljizhang://
            // URI that arrived on a cold start remains queued. LockGate
            // sits on the navigator child and omits it until unlock, so
            // 帳本 / 分析 / the import sheet cannot paint a frame first.
            return ImportLinkHost(
              links: _links,
              navigatorKey: _navigatorKey,
              child: LockGate(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Full-screen lock that replaces the navigator until unlock.
///
/// Purpose: no protected route (帳本, 分析, 記一筆, deep-link import) is
/// built or painted before the password / Face ID check. GoRouter keeps
/// the location, so after unlock the same tab comes back.
///
/// Rules: [LockController.locked] starts true and [ready] starts false,
/// so the first frame is [LockCover] (neutral splash, not the ledger)
/// even before the keystore read returns. After bootstrap, [LockScreen]
/// is the only child while [locked]. Lock off clears [locked], and the
/// navigator is inserted then. The navigator is omitted — not stacked
/// underneath an overlay — so widget tests cannot find HomePage while
/// the gate is up, and no frame of protected content can composite.
class LockGate extends StatelessWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lock = LockScope.of(context);
    // Fail closed until bootstrap proves there is no lock, and whenever
    // a locked session is in progress (launch, pause, resume, lockout).
    if (!lock.ready) return const LockCover();
    if (lock.locked) return const LockScreen();
    return child;
  }
}
