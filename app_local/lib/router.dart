import 'package:flutter/material.dart';
import 'package:full_jizhang/pages/analytics/analytics_page.dart';
import 'package:full_jizhang/pages/assets/assets_page.dart';
import 'package:full_jizhang/pages/boot_page.dart';
import 'package:full_jizhang/pages/home/home_page.dart';
import 'package:full_jizhang/pages/opening/opening_page.dart';
import 'package:full_jizhang/pages/record/record_sheet.dart';
import 'package:full_jizhang/pages/settings/auto_record_page.dart';
import 'package:full_jizhang/pages/settings/backup_page.dart';
import 'package:full_jizhang/pages/settings/books_manage_page.dart';
import 'package:full_jizhang/pages/settings/categories_page.dart';
import 'package:full_jizhang/pages/settings/settings_page.dart';
import 'package:full_jizhang/session/book_create_nav.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/shell.dart';
import 'package:go_router/go_router.dart';

/// App routes for the local ledger.
///
/// `/boot` stays up until [BookController.ready]. After that the shell is
/// home, analytics, assets, and settings. There is no login route: the
/// device is the only user. Settings nests books, categories, and backup.
/// Opening and the record sheet sit outside the shell. `/record` uses
/// [navigatorKey] as [GoRoute.parentNavigatorKey] so 記一筆 is a root
/// overlay: 存檔 pops back to the tab that opened it. 自動記帳 is a
/// settings subpage. [navigatorKey] is also the root navigator the Apple
/// Pay import sheet uses. [RecordEdit] arrives as `/record` extra; a
/// missing extra is a new entry.
GoRouter createRouter(
  BookController books, {
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  // Shell tabs live on this navigator. `/record` uses the root key so
  // 記一筆 is an overlay and 存檔 pops back to the tab that opened it.
  final shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
  final rootKey = navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/boot',
    refreshListenable: books,
    redirect: (context, state) {
      final path = state.uri.path;
      // Hold every route on the splash until the book list has loaded.
      if (!books.ready) return path == '/boot' ? null : '/boot';
      if (path == '/boot') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/boot', builder: (context, state) => const BootPage()),
      GoRoute(
        path: '/record',
        parentNavigatorKey: rootKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            opaque: false,
            barrierDismissible: false,
            transitionDuration: const Duration(milliseconds: 220),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            // extra is the row being edited. Null means 記一筆.
            child: RecordSheet(
              edit: state.extra is RecordEdit ? state.extra as RecordEdit : null,
            ),
          );
        },
      ),
      GoRoute(
        path: '/opening',
        builder: (context, state) => const OpeningPage(),
      ),
      ShellRoute(
        navigatorKey: shellKey,
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
                builder: (context, state) {
                  // Purpose: pass the opener into 帳本管理. Rule: the manage
                  // page passes the real pre-create count. No books yet
                  // goes to `/` for every origin. When books already exist,
                  // `from=home` stays on this page and anything else
                  // returns to 設定. Key logic: the query is read once
                  // here, before the user types a name.
                  return BooksManagePage(
                    origin: originFromBooksQuery(
                      state.uri.queryParameters['from'],
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'categories',
                builder: (context, state) => const CategoriesPage(),
              ),
              GoRoute(
                path: 'backup',
                builder: (context, state) => const BackupPage(),
              ),
              // Apple Pay shortcut setup. Android shows the unsupported page.
              GoRoute(
                path: 'auto-record',
                builder: (context, state) => const AutoRecordPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
