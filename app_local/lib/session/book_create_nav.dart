import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Who started 新增帳本.
///
/// Purpose: the page that should be showing when create finishes is a
/// fact about the opener, captured before the insert. It is not inferred
/// from a post-frame callback or from whichever route GoRouter rebuilt
/// when [BookController] notified its listeners.
///
/// Rules:
/// - [settings] is 設定, 帳本管理 opened from 設定, and the 切換帳本
///   sheet opened on 設定 (the 新增帳本 row).
/// - [firstRun] is the 還沒有帳本 empty state on the 帳本 tab.
/// - [homeManage] is 管理帳本 opened from the 帳本 switcher, or the
///   archived-books link on that empty state.
enum BookCreateOrigin {
  settings,
  firstRun,
  homeManage,
}

/// Route to show after a book is created. Null means stay on this page.
///
/// Purpose: 設定 and the first-run empty state finish in different
/// places, except when this create is the very first book. One function
/// decides, so create cannot fall through to 開帳 because a refresh
/// happened to rebuild `/`.
///
/// Rules:
/// - [hadBooks] false → `/` for every origin, including
///   [BookCreateOrigin.settings]. Creating the very first book, when
///   there are no books yet, must go to the 帳本 home. That requirement
///   wins over origin.
/// - [hadBooks] true and [BookCreateOrigin.settings] → `/settings`.
///   Return to the settings page. Do not open `/opening`.
/// - [hadBooks] true and [BookCreateOrigin.firstRun] → `/` (帳本 home).
///   The new book is already current; [BookController.create] selects
///   it, and this helper does not change that.
/// - [hadBooks] true and [BookCreateOrigin.homeManage] → null (stay on
///   帳本管理). Do not open 設定 or 開帳 from the 帳本 switcher.
/// - `/opening` is never returned.
///
/// Key logic: [hadBooks] is the real book-row count taken before create.
/// A false count is checked first and returns `/` before the origin
/// switch. Only a settings create that started with at least one book
/// returns to `/settings`.
String? routeAfterBookCreate({
  required BookCreateOrigin origin,
  required bool hadBooks,
}) {
  // Purpose: the first book has no 帳本管理 to return to.
  // Rule: no rows before create → 帳本 `/`, for every origin.
  // Key logic: this check is before the switch, so 設定 cannot win.
  if (!hadBooks) return '/';
  switch (origin) {
    case BookCreateOrigin.settings:
      return '/settings';
    case BookCreateOrigin.firstRun:
      return '/';
    case BookCreateOrigin.homeManage:
      return null;
  }
}

/// Maps the `from` query on `/settings/books` to an origin.
///
/// Purpose: 帳本管理 is one page. 設定 and the 帳本 switcher both push
/// it, and the query says which one, so the landing page is not a guess.
///
/// Rules:
/// - `home` → [BookCreateOrigin.homeManage].
/// - `settings`, a missing value, or anything else →
///   [BookCreateOrigin.settings], because this route is nested under 設定.
///
/// Key logic: compare the raw query value, not the path and not the clock.
BookCreateOrigin originFromBooksQuery(String? from) {
  if (from == 'home') return BookCreateOrigin.homeManage;
  return BookCreateOrigin.settings;
}

/// Applies [routeAfterBookCreate] on the router.
///
/// Purpose: move to the helper's route after select() and reload() have
/// already notified GoRouter (those notifications refresh the current
/// match; they are not the navigation decision).
///
/// Rules:
/// - A null route does not navigate. 帳本管理 stays where it is.
/// - The same path does not navigate. The empty state is already `/`,
///   and a second `go('/')` would rebuild 帳本 for no reason.
/// - Any other route uses [GoRouter.go]. Pop is not used: the refresh
///   from [BookController] can drop the imperative stack, and a pop
///   would then miss 設定. `/opening` is not a destination.
///
/// Key logic: compare [GoRouterState.uri] path, which has no query.
/// `from=settings` on `/settings/books` still counts as a different
/// path from `/settings`, so go() replaces the manage page.
void goBookCreateRoute(BuildContext context, String? route) {
  if (route == null || !context.mounted) return;
  final here = GoRouterState.of(context).uri.path;
  if (here == route) return;
  context.go(route);
}
