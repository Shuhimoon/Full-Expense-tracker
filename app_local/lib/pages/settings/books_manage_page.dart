import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/session/book_create_nav.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/soft_card.dart';
import 'package:go_router/go_router.dart';

/// 帳本管理, matching Doop frame 14 (t0TnSvkJdV).
///
/// Purpose: list every active book with its opening date and net worth,
/// switch the current book, start the opening wizard for a new book, and
/// delete a non-current book (after the frame-15 confirm dialog).
///
/// Rules:
/// - The current book cannot be swiped, long-pressed away, or deleted.
/// - ＋ 新增帳本 and the top-right + both open `/opening?create=1`.
/// - After a create, [routeAfterBookCreate] still decides the landing
///   page (first book → 帳本; settings origin → 設定). This page does
///   not jump to 開帳 after save; the wizard does that navigation.
/// - 改名 and 封存 are not shown here (frame 14 has neither). Archive
///   remains in the API.
/// - Tapping a non-current book calls [BookController.select]. That is
///   the switcher now that 設定 no longer has a 切換帳本 row.
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
  final Map<String, int> _nets = {};
  String? _error;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Purpose: net worth is not on the Book row. Rule: refresh whenever
    // the inherited book list changes (select, create, delete).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNets();
    });
  }

  Future<void> _loadNets() async {
    final books = BookScope.of(context);
    final next = <String, int>{};
    for (final book in books.activeBooks) {
      try {
        final summary = await books.api.statsSummary(bookId: book.id);
        next[book.id] = summary.netWorth;
      } catch (_) {
        next[book.id] = 0;
      }
    }
    if (mounted) {
      setState(() => _nets
        ..clear()
        ..addAll(next));
    }
  }

  /// Opens create-mode opening at screen 7 (選開帳日).
  ///
  /// Purpose: a new book is not inserted until preview save.
  /// Rule: [from] carries the same origin this page was opened with,
  /// so the 10/27 landing rules still apply after save.
  void _startCreate() {
    final from = switch (widget.origin) {
      BookCreateOrigin.homeManage => 'home',
      BookCreateOrigin.firstRun => 'first',
      BookCreateOrigin.settings => 'settings',
    };
    context.push('/opening?create=1&from=$from');
  }

  Future<void> _select(Book book) async {
    final books = BookScope.of(context);
    if (_busy || book.id == books.current?.id) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await books.select(book.id);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '請求失敗');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Frame 15 confirm, then cascade-delete. Stays on this page.
  Future<void> _confirmDelete(Book book) async {
    final books = BookScope.of(context);
    if (book.id == books.current?.id) return;
    final agreed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DeleteBookSheet(
        bookName: book.name,
        currentName: books.current?.name ?? '',
      ),
    );
    if (agreed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await books.api.deleteBook(book.id);
      if (!mounted) return;
      await books.reload();
      if (mounted) await _loadNets();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '請求失敗');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = BookScope.of(context);
    final active = books.activeBooks;
    final currentId = books.current?.id;
    return PageScroll(
      // Purpose: tests tell 帳本管理 from the 設定 page. Rule: this key is
      // only on the manage page, so a return to 設定 must not find it.
      key: const Key('page-books'),
      children: [
        _header(active.length),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '我的帳本',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ),
        for (final book in active) ...[
          _BookRow(
            book: book,
            current: book.id == currentId,
            net: _nets[book.id],
            enabled: !_busy,
            onTap: () => _select(book),
            onDelete: () => _confirmDelete(book),
          ),
          const SizedBox(height: 10),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 2, 4, 14),
          child: Text(
            '向左滑或長按可刪除帳本；目前使用中的帳本無法刪除',
            key: Key('books-delete-hint'),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.secondary,
              height: 1.4,
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('books-add'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sageDark,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _busy ? null : _startCreate,
            child: const Text(
              '＋  新增帳本',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '進入開帳流程：選開帳日 → 填帳戶餘額 → 現倉 → 預覽儲存',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.secondary, height: 1.4),
        ),
        ErrorLine(_error, lineKey: const Key('books-error')),
      ],
    );
  }

  Widget _header(int count) {
    return Row(
      children: [
        IconButton(
          key: const Key('subpage-back'),
          tooltip: '返回',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.sageDark,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '帳本管理',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              Text(
                '設定 · $count 個帳本',
                key: const Key('books-count'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: AppColors.sageDark,
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('books-add-appbar'),
            customBorder: const CircleBorder(),
            onTap: _busy ? null : _startCreate,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

/// One book row. Current books have a check and 「目前使用」; others swipe
/// or long-press to the delete confirm, and tap to become current.
class _BookRow extends StatelessWidget {
  const _BookRow({
    required this.book,
    required this.current,
    required this.net,
    required this.enabled,
    required this.onTap,
    required this.onDelete,
  });

  final Book book;
  final bool current;
  final int? net;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final opening = book.openingDate != null && book.openingDate!.isNotEmpty
        ? book.openingDate!
        : '—';
    final card = Material(
      color: current ? const Color(0xFFF7FFFB) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('managed-${book.id}'),
        borderRadius: BorderRadius.circular(18),
        // Purpose: long-press deletes only a non-current book.
        // Rule: the current book ignores long-press so it cannot be
        // removed by accident. Tap on a non-current book switches.
        onTap: enabled ? onTap : null,
        onLongPress: (!current && enabled) ? onDelete : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: current ? const Color(0x665F8574) : const Color(0x14000000),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x248FB09F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.sageDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          book.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (current)
                          Container(
                            key: const Key('books-current-badge'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x338FB09F),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '目前使用',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.sageDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '開帳日 $opening',
                      key: Key('books-date-${book.id}'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      '淨資產 ${formatNtd(net ?? 0)}',
                      key: Key('books-net-${book.id}'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                current ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: current ? AppColors.sageDark : AppColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
    if (current) return card;
    return _SwipeToDelete(
      enabled: enabled,
      deleteKey: Key('books-swipe-${book.id}'),
      onDelete: onDelete,
      child: card,
    );
  }
}

/// Swipe left to reveal a red 刪除 action that opens the confirm dialog.
///
/// Purpose: frame 14 shows a revealed delete button, not an immediate
/// dismiss. Rule: tapping 刪除 calls [onDelete] (the confirm sheet); it
/// does not delete on its own. The current book never wraps in this
/// widget, so it cannot be swiped away.
class _SwipeToDelete extends StatefulWidget {
  const _SwipeToDelete({
    required this.enabled,
    required this.deleteKey,
    required this.onDelete,
    required this.child,
  });

  final bool enabled;
  final Key deleteKey;
  final VoidCallback onDelete;
  final Widget child;

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete> {
  static const _extent = 88.0;
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: const Color(0xFFE24B4A),
                child: InkWell(
                  key: widget.deleteKey,
                  onTap: widget.enabled ? widget.onDelete : null,
                  child: const SizedBox(
                    width: _extent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline, color: Colors.white, size: 22),
                        SizedBox(height: 2),
                        Text(
                          '刪除',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: widget.enabled
                ? (details) {
                    setState(() {
                      _dx = (_dx + details.delta.dx).clamp(-_extent, 0);
                    });
                  }
                : null,
            onHorizontalDragEnd: widget.enabled
                ? (_) {
                    setState(() {
                      _dx = _dx < -_extent / 2 ? -_extent : 0;
                    });
                  }
                : null,
            child: Transform.translate(
              offset: Offset(_dx, 0),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Frame 15 confirm sheet. 取消 pops false; 刪除 pops true.
class _DeleteBookSheet extends StatelessWidget {
  const _DeleteBookSheet({
    required this.bookName,
    required this.currentName,
  });

  final String bookName;
  final String currentName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Material(
        color: AppColors.sheet,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x14E24B4A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFE24B4A),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '刪除「$bookName」？',
                key: const Key('books-confirm-title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '帳本內的記錄會一併刪除。',
                key: Key('books-confirm-body'),
                style: TextStyle(fontSize: 14, color: AppColors.secondary),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x1A8FB09F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '目前使用中的帳本（$currentName）無法刪除，需先切換到其他帳本。',
                  key: const Key('books-confirm-info'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.sageDark,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('books-confirm-cancel'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0x248FB09F),
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('books-confirm-delete'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE24B4A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('刪除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
