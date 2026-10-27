import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/session/book_create_nav.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/field_dialog.dart';
import 'package:full_jizhang/widgets/soft_card.dart';

/// 帳本管理. Rename, archive, and 新增 share this page.
///
/// Purpose: 新增 must finish on the page [routeAfterBookCreate] chooses,
/// not by staying here or opening 開帳.
///
/// Rules: [origin] comes from the `from` query. [_create] passes the
/// real pre-create row count. No books yet → `/` (帳本), even when
/// [origin] is 設定. A settings origin with an existing book returns
/// to `/settings`. A home origin stays here when a book already
/// existed. The new book stays current because [BookController.create]
/// selects it; this page does not clear that.
class BooksManagePage extends StatefulWidget {
  const BooksManagePage({
    super.key,
    this.origin = BookCreateOrigin.settings,
  });

  /// Who pushed `/settings/books`. Defaults to 設定 for a direct open.
  final BookCreateOrigin origin;

  @override
  State<BooksManagePage> createState() => _BooksManagePageState();
}

class _BooksManagePageState extends State<BooksManagePage> {
  final _name = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) await BookScope.of(context).reload();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '請求失敗');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '請填帳本名稱');
      return;
    }
    if (_busy) return;
    final books = BookScope.of(context);
    // Purpose: decide the landing page from facts known before the insert.
    // Rule: [hadBooks] is the real row count now, including archived
    // rows, not the count after create() appends. False (no books yet)
    // wins over [origin] and goes to 帳本. A settings origin returns
    // to 設定 only when this count is true.
    // Key logic: read [widget.origin] and the list, then await. No timer.
    final hadBooks = books.books.isNotEmpty;
    final origin = widget.origin;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await books.create(name);
      if (!mounted) return;
      // Rule: reload restores last_book_id. create() already selected
      // this book, so 設定's 目前 line shows the new name, not the old one.
      await books.reload();
      if (!mounted) return;
      _name.clear();
      goBookCreateRoute(
        context,
        routeAfterBookCreate(origin: origin, hadBooks: hadBooks),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '請求失敗');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(Book book) async {
    final next = await FieldDialog.show(
      context,
      title: '帳本新名稱',
      initial: book.name,
      fieldKey: const Key('rename-book-field'),
      okKey: const Key('rename-book-ok'),
    );
    if (next == null || !mounted) return;
    if (next.isEmpty) {
      setState(() => _error = '名稱不能空');
      return;
    }
    await _run(() async {
      await BookScope.of(context).api.patchBook(
        id: book.id,
        name: next,
        version: book.version,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final books = BookScope.of(context);
    return PageScroll(
      // Purpose: tests tell 帳本管理 from the 設定 page. Rule: this key is
      // only on the manage page, so a return to 設定 must not find it.
      key: const Key('page-books'),
      children: [
        const SubpageHeader(title: '帳本管理'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('new-book-field'),
                controller: _name,
                decoration: const InputDecoration(
                  hintText: '新帳本名稱',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('new-book-create'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.sage),
              onPressed: _busy ? null : _create,
              child: const Text('新增'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final book in books.books) ...[
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.name,
                  key: Key('managed-${book.id}'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  book.archived
                      ? '已封存'
                      : (book.id == books.current?.id ? '使用中' : '未封存'),
                  style: const TextStyle(fontSize: 12, color: AppColors.secondary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: [
                    if (!book.archived && book.id != books.current?.id)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => books.select(book.id)),
                        child: const Text('切換'),
                      ),
                    TextButton(
                      key: Key('rename-${book.id}'),
                      onPressed: _busy || book.archived ? null : () => _rename(book),
                      child: const Text('改名'),
                    ),
                    TextButton(
                      key: Key('archive-${book.id}'),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => book.archived
                                  ? books.api.unarchiveBook(book.id)
                                  : books.api.archiveBook(book.id),
                            ),
                      child: Text(book.archived ? '取消封存' : '封存'),
                    ),
                    TextButton(
                      key: Key('delete-${book.id}'),
                      onPressed: _busy
                          ? null
                          : () => _run(() => books.api.deleteBook(book.id)),
                      child: const Text('刪除'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        ErrorLine(_error, lineKey: const Key('books-error')),
      ],
    );
  }
}
