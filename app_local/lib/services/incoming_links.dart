import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:full_jizhang/services/apple_pay_link.dart';

// Delivers fulljizhang://add links into the import preview.
//
// Purpose: Shortcuts opens the app with the initial link, and also when a
// payment arrives while Full 記帳 is already running. Both paths call the
// same listener. The link is not saved here. The preview sheet is the only
// writer, and only after the user confirms.
//
// A burst of the same URI (the initial link echoed again on the stream)
// is dropped for one second so the sheet does not open twice. A later
// payment with the same URL still opens, and the stored import key is what
// marks it 重複.

/// Source of incoming URIs. Tests pass a fake; production uses [AppLinks].
abstract class LinkSource {
  Future<Uri?> getInitialLink();
  Stream<Uri> get uriLinkStream;
}

/// [app_links] backed source. Missing plugin (widget tests, desktop without
/// the channel) yields no links instead of crashing launch.
class AppLinksSource implements LinkSource {
  AppLinks? _links;

  AppLinks? get _safe {
    if (_links != null) return _links;
    try {
      _links = AppLinks();
      return _links;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uri?> getInitialLink() async {
    final links = _safe;
    if (links == null) return null;
    try {
      return await links.getInitialLink();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Uri> get uriLinkStream {
    final links = _safe;
    if (links == null) return const Stream<Uri>.empty();
    return links.uriLinkStream.handleError((Object _) {});
  }
}

/// Subscribes to [source] and emits only `fulljizhang://add` URIs.
class IncomingLinks {
  IncomingLinks({LinkSource? source}) : _source = source ?? AppLinksSource();

  final LinkSource _source;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  StreamSubscription<Uri>? _sub;
  String? _last;
  DateTime? _lastAt;
  bool _started = false;

  Stream<Uri> get uris => _controller.stream;

  /// Reads the link that launched the process, then listens for the next ones.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    // Widget tests and desktops without the plugin throw when the channel
    // is read. Swallow that so launch still reaches the ledger. A missing
    // link is the same as no payment: nothing is previewed or saved.
    try {
      final initial = await _source.getInitialLink();
      if (initial != null) _offer(initial);
    } catch (_) {}
    try {
      _sub = _source.uriLinkStream.listen(
        _offer,
        onError: (Object _) {},
      );
    } catch (_) {}
  }

  void _offer(Uri uri) {
    if (!isApplePayAddLink(uri)) return;
    final text = uri.toString();
    final now = DateTime.now();
    if (text == _last &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 1)) {
      return;
    }
    _last = text;
    _lastAt = now;
    if (!_controller.isClosed) _controller.add(uri);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
