import 'package:full_jizhang/auth.dart';
import 'package:full_jizhang/pages/boot_page.dart';
import 'package:full_jizhang/pages/login_page.dart';
import 'package:full_jizhang/pages/placeholder_page.dart';
import 'package:full_jizhang/pages/record_page.dart';
import 'package:full_jizhang/pages/settings_page.dart';
import 'package:full_jizhang/shell.dart';
import 'package:go_router/go_router.dart';

GoRouter createRouter(AuthController auth) {
  return GoRouter(
    initialLocation: '/boot',
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.uri.path;
      if (!auth.ready) return path == '/boot' ? null : '/boot';
      final loggingIn = path == '/login';
      if (!auth.isLoggedIn) return loggingIn ? null : '/login';
      if (loggingIn || path == '/boot') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/boot', builder: (context, state) => const BootPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/record', builder: (context, state) => const RecordPage()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PlaceholderPage(
              title: '帳本',
              subtitle: '今天已花、淨資產與流水會出現在這裡。',
            ),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const PlaceholderPage(
              title: '分析圖',
              subtitle: '支出、收入與分類圖會出現在這裡。',
            ),
          ),
          GoRoute(
            path: '/assets',
            builder: (context, state) =>
                const PlaceholderPage(title: '資產', subtitle: '帳戶與持倉會出現在這裡。'),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
}
