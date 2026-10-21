import 'dart:async';

import 'package:flutter/material.dart';
import 'package:full_jizhang/lock.dart';
import 'package:full_jizhang/pages/record/import_preview_sheet.dart';
import 'package:full_jizhang/services/incoming_links.dart';
import 'package:full_jizhang/session/books.dart';

// Shows the import preview when a fulljizhang://add link arrives.
//
// Handles the link that launched the app and links that arrive while it
// is running. The sheet is not shown over the lock, and not before a book
// is selected; the URI waits. Confirm is the only save. Cancel drops it.
//
// Purpose: launch, resume, and a link that arrives while locked all share
// one queue. The preview is built only after [LockController.ready] and
// [LockController.locked] is false.
//
// Rules:
// - Before bootstrap finishes the controller starts locked, so a link
//   that wins the race against the keystore read stays queued.
// - Resume sets locked true synchronously. A link delivered after that
//   cannot open the sheet until the next unlock.
// - If resume lands while the database preview is in flight, the sheet
//   is not built and the URI is put back on the queue.

class ImportLinkHost extends StatefulWidget {
  const ImportLinkHost({
    super.key,
    required this.links,
    required this.navigatorKey,
    required this.child,
  });

  final IncomingLinks links;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<ImportLinkHost> createState() => _ImportLinkHostState();
}

class _ImportLinkHostState extends State<ImportLinkHost> {
  StreamSubscription<Uri>? _sub;
  Uri? _queued;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    widget.links.start();
    _sub = widget.links.uris.listen(_queue);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depend on the book list and the lock so a queued link opens when
    // either becomes usable. The sheet itself still requires a confirm.
    BookScope.of(context);
    LockScope.of(context);
    if (_queued != null && !_showing) _schedule();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _queue(Uri uri) {
    _queued = uri;
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _queued == null || _showing) return;
      _open(_queued!);
    });
  }

  /// True when a book is selected and the lock gate is open.
  ///
  /// Looks the scopes up without [dependOnInheritedWidgetOfExactType].
  /// This runs from a post-frame callback, not from build.
  /// [didChangeDependencies] is what listens for unlock and for a book.
  bool _canShow(BuildContext ctx) {
    final booksElement = ctx.getElementForInheritedWidgetOfExactType<BookScope>();
    if (booksElement == null) return false;
    final books = (booksElement.widget as BookScope).notifier!;
    if (!books.ready || books.current == null) return false;
    final lock = LockScope.read(ctx);
    return lock.ready && !lock.locked;
  }

  Future<void> _open(Uri uri) async {
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    // Keep [_queued]. Unlock and book load both notify, which schedules
    // this again. Do not drop the link just because the gate is still up.
    if (!_canShow(ctx) || _showing) return;
    _queued = null;
    _showing = true;
    var putBack = false;
    try {
      final saved = await showApplePayImport(
        ctx,
        uri,
        // Re-checked after the database read inside the preview helper.
        // A resume during that await must not build the sheet.
        ifLocked: () {
          putBack = true;
        },
      );
      if (putBack) {
        _queued = uri;
        return;
      }
      if (saved && ctx.mounted) BookScope.of(ctx).touch();
    } finally {
      _showing = false;
      if (_queued != null && mounted) _schedule();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
