import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/field_dialog.dart';
import 'package:full_jizhang/widgets/soft_card.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _name = TextEditingController();
  String _kind = 'expense';
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;
  String? _bookId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = BookScope.of(context).current?.id;
    if (_bookId == id && !_loading) return;
    _bookId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final book = BookScope.of(context).current;
    if (book == null) {
      setState(() {
        _loading = false;
        _categories = [];
      });
      return;
    }
    try {
      final list = await BookScope.of(context).api.listCategories(book.id);
      if (!mounted) return;
      setState(() {
        _categories = list;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final book = BookScope.of(context).current;
    final name = _name.text.trim();
    if (book == null) {
      setState(() => _error = '請先建立帳本');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = '請填分類名稱');
      return;
    }
    try {
      await BookScope.of(context).api.createCategory(
        bookId: book.id,
        name: name,
        kind: _kind,
      );
      _name.clear();
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _rename(Category category) async {
    final next = await FieldDialog.show(
      context,
      title: '分類新名稱',
      initial: category.name,
      fieldKey: const Key('rename-category-field'),
      okKey: const Key('rename-category-ok'),
    );
    if (next == null || next.isEmpty || !mounted) return;
    try {
      await BookScope.of(context).api.patchCategory(
        id: category.id,
        name: next,
        version: category.version,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _archive(Category category) async {
    try {
      await BookScope.of(context).api.archiveCategory(category.id);
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _delete(Category category) async {
    try {
      await BookScope.of(context).api.deleteCategory(category.id);
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = _categories.where((item) => item.kind == 'expense');
    final income = _categories.where((item) => item.kind == 'income');
    return PageScroll(
      children: [
        const SubpageHeader(title: '分類管理'),
        const SizedBox(height: 8),
        if (BookScope.of(context).current == null)
          const Text('請先建立帳本')
        else ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('new-category-field'),
                  controller: _name,
                  decoration: const InputDecoration(
                    hintText: '分類名稱',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                key: const Key('new-category-kind'),
                value: _kind,
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('支出')),
                  DropdownMenuItem(value: 'income', child: Text('收入')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _kind = value);
                },
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('new-category-create'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.sage),
                onPressed: _add,
                child: const Text('新增'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppColors.sage))
          else ...[
            _Section(title: '支出', items: expense.toList(), onRename: _rename, onArchive: _archive, onDelete: _delete),
            const SizedBox(height: 8),
            _Section(title: '收入', items: income.toList(), onRename: _rename, onArchive: _archive, onDelete: _delete),
          ],
        ],
        ErrorLine(_error, lineKey: const Key('categories-error')),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    required this.onRename,
    required this.onArchive,
    required this.onDelete,
  });

  final String title;
  final List<Category> items;
  final ValueChanged<Category> onRename;
  final ValueChanged<Category> onArchive;
  final ValueChanged<Category> onDelete;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '沒有分類',
                style: TextStyle(fontSize: 12, color: AppColors.secondary),
              ),
            ),
          for (final category in items)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.archived ? '${category.name}（已封存）' : category.name,
                      key: Key('category-${category.id}'),
                      style: TextStyle(
                        color: category.archived ? AppColors.faint : AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('category-rename-${category.id}'),
                    tooltip: '改名',
                    onPressed: category.archived ? null : () => onRename(category),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    key: Key('category-archive-${category.id}'),
                    tooltip: '封存',
                    onPressed: category.archived ? null : () => onArchive(category),
                    icon: const Icon(Icons.archive_outlined, size: 18),
                  ),
                  IconButton(
                    key: Key('category-delete-${category.id}'),
                    tooltip: '刪除',
                    onPressed: () => onDelete(category),
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
