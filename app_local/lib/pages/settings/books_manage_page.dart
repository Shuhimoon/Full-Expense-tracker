import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/field_dialog.dart';
import 'package:full_jizhang/widgets/soft_card.dart';

class BooksManagePage extends StatefulWidget {
  const BooksManagePage({super.key});

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
    await _run(() async {
      await BookScope.of(context).create(name);
      _name.clear();
    });
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
