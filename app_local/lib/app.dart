import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/pages/record/import_link_host.dart';
import 'package:full_jizhang/router.dart';
import 'package:full_jizhang/services/incoming_links.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/brand_mark.dart';
import 'package:go_router/go_router.dart';

/// Root widget. Owns the book session, the app lock, and the router.
///
/// Production passes a LocalApi built in `main.dart`. Tests inject [api]
/// and, when they need a deterministic gate, [lock]. [LockGate] covers every
/// route while the lock is enabled and still locked (launch and resume).
class FullJizhangApp extends StatefulWidget {
  const FullJizhangApp({
    super.key,
    required this.api,
    this.lock,
  });

  /// Injected in tests. Production builds a [LocalApi].
  final ApiClient api;

  /// Injected in tests. Production uses device biometrics.
  final LockController? lock;

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
    // Device biometrics plus passcode. Tests pass their own controller.
    _lock = widget.lock ?? LockController(auth: LocalDeviceAuth());
    // Apple Pay shortcuts open fulljizhang://add. Listening does not save.
    // The preview sheet writes only after the user confirms.
    _links = IncomingLinks();
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
            // The host queues the link until a book is ready and the lock
            // is not covering the app. LockGate stays outside so the sheet
            // cannot be tapped while locked.
            return LockGate(
              child: ImportLinkHost(
                links: _links,
                navigatorKey: _navigatorKey,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Full-screen lock drawn over the router while [LockController.locked].
///
/// The child stays mounted so resume can re-lock without losing navigation,
/// but [LockScreen] eats the hits until unlock succeeds.
class LockGate extends StatelessWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lock = LockScope.of(context);
    return Stack(
      children: [
        child,
        // Fail closed: enabled and not yet unlocked covers the whole app.
        if (lock.enabled && lock.locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

/// Unlock prompt. The button calls [LockController.unlock], which accepts
/// Face ID, fingerprint, or the device passcode and stays up on failure.
class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.background,
      child: GlassBackground(
        child: AppFrame(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(),
                  const SizedBox(height: 18),
                  Text('Full 記帳已鎖定', style: text.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '使用 Face ID、指紋或裝置密碼解鎖',
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    key: const Key('lock-unlock'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sage,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => LockScope.of(context).unlock(),
                    child: const Text('解鎖'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
