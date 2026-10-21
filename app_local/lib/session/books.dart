import 'package:flutter/widgets.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/services/local_api.dart';

/// Current-book session for the UI.
///
/// Ports the "last selected book" idea from `api/internal/app/books.go`
/// `handleBooksSelect` (Go stores `users.last_book_id`; locally that is the
/// `last_book_id` row in `app_prefs`). Archived books are skipped. There is
/// no user account.
class BookController extends ChangeNotifier {
  BookController({required this.api});

  final ApiClient api;

  List<Book> books = [];
  Book? current;
  bool ready = false;
  String? error;
  int generation = 0;
  int _ticket = 0;
  bool _disposed = false;

  List<Book> get activeBooks => books.where((book) => !book.archived).toList();

  /// Reloads books and restores the last selection.
  ///
  /// [_ticket] drops a stale response when a newer reload is in flight.
  Future<void> reload() async {
    final ticket = ++_ticket;
    try {
      final list = await api.listBooks();
      if (ticket != _ticket || _disposed) return;
      books = list;
      String? last;
      if (api is LocalApi) {
        last = await (api as LocalApi).lastBookId();
      }
      current = _match(last);
      error = null;
    } on ApiException catch (exception) {
      if (ticket != _ticket || _disposed) return;
      error = exception.message;
    } catch (_) {
      if (ticket != _ticket || _disposed) return;
      error = '請求失敗';
    }
    ready = true;
    _notify();
  }

  /// Prefer [id] when it is still an active book; otherwise the first active book.
  Book? _match(String? id) {
    if (id != null) {
      for (final book in books) {
        if (book.id == id && !book.archived) return book;
      }
    }
    for (final book in books) {
      if (!book.archived) return book;
    }
    return null;
  }

  /// Creates a book (default name 「生活」) and selects it.
  ///
  /// Opening date is the creation day in Asia/Taipei, set inside
  /// [LocalApi.createBook], which ports `books.go` `handleBooksCreate`.
  Future<Book> create(String name) async {
    final trimmed = name.trim();
    final book = await api.createBook(name: trimmed.isEmpty ? '生活' : trimmed);
    await select(book.id);
    return book;
  }

  Future<void> select(String id) async {
    final book = await api.selectBook(id);
    final next = [...books];
    final index = next.indexWhere((item) => item.id == book.id);
    if (index >= 0) {
      next[index] = book;
    } else {
      next.add(book);
    }
    books = next;
    current = book.archived ? _match(null) : book;
    error = null;
    _notify();
  }

  /// Bumps [generation] so pages that listen reload derived data.
  void touch() {
    generation += 1;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Provides [BookController] to the tree. Pages read it with [BookScope.of].
class BookScope extends InheritedNotifier<BookController> {
  const BookScope({
    super.key,
    required BookController books,
    required super.child,
  }) : super(notifier: books);

  static BookController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BookScope>();
    assert(scope != null, 'BookScope is missing above this context');
    return scope!.notifier!;
  }
}
