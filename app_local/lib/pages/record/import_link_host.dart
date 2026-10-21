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

  Future<void> _open(Uri uri) async {
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final books = BookScope.of(ctx);
    if (!books.ready || books.current == null) return;
    final lock = LockScope.of(ctx);
    if (lock.enabled && lock.locked) return;
    if (_showing) return;
    _queued = null;
    _showing = true;
    try {
      final saved = await showApplePayImport(ctx, uri);
      if (saved && ctx.mounted) BookScope.of(ctx).touch();
    } finally {
      _showing = false;
      if (_queued != null && mounted) _schedule();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
