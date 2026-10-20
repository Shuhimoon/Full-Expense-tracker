import 'package:flutter/widgets.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/auth.dart';
import 'package:full_jizhang/models/ledger.dart';

class BookController extends ChangeNotifier {
  BookController({required this.api, required this.auth});

  final ApiClient api;
  final AuthController auth;

  List<Book> books = [];
  Book? current;
  bool ready = false;
  String? error;
  int generation = 0;
  int _ticket = 0;
  bool _disposed = false;

  List<Book> get activeBooks => books.where((book) => !book.archived).toList();

  Future<void> reload() async {
    final ticket = ++_ticket;
    if (!auth.isLoggedIn) {
      books = [];
      current = null;
      error = null;
      ready = true;
      _notify();
      return;
    }
    try {
      final list = await api.listBooks();
      if (ticket != _ticket || _disposed) return;
      books = list;
      current = _match(auth.user?.lastBookId);
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
    auth.rememberBook(book.id);
    _notify();
  }

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
