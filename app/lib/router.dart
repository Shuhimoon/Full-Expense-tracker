import 'package:flutter/material.dart';
import 'package:full_jizhang/auth.dart';
import 'package:full_jizhang/pages/analytics/analytics_page.dart';
import 'package:full_jizhang/pages/assets/assets_page.dart';
import 'package:full_jizhang/pages/boot_page.dart';
import 'package:full_jizhang/pages/home/home_page.dart';
import 'package:full_jizhang/pages/login_page.dart';
import 'package:full_jizhang/pages/opening/opening_page.dart';
import 'package:full_jizhang/pages/record/record_sheet.dart';
import 'package:full_jizhang/pages/settings/backup_page.dart';
import 'package:full_jizhang/pages/settings/books_manage_page.dart';
import 'package:full_jizhang/pages/settings/categories_page.dart';
import 'package:full_jizhang/pages/settings/settings_page.dart';
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
      GoRoute(
        path: '/record',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            opaque: false,
            barrierDismissible: false,
            transitionDuration: const Duration(milliseconds: 220),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: const RecordSheet(),
          );
        },
      ),
      GoRoute(
        path: '/opening',
        builder: (context, state) => const OpeningPage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsPage(),
          ),
          GoRoute(
            path: '/assets',
            builder: (context, state) => const AssetsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
            routes: [
              GoRoute(
                path: 'books',
                builder: (context, state) => const BooksManagePage(),
              ),
              GoRoute(
                path: 'categories',
                builder: (context, state) => const CategoriesPage(),
              ),
              GoRoute(
                path: 'backup',
                builder: (context, state) => const BackupPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
