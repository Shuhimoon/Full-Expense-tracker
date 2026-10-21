import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/format.dart';
import 'package:full_jizhang/models/ledger.dart';
import 'package:full_jizhang/services/apple_pay_link.dart';
import 'package:full_jizhang/services/local_api.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';

// Import preview. Frame: design/13-import-preview.html, using the app's
// sage palette. Nothing is written until 確認匯入. Cancel and an unticked
// list write zero rows.
//
// Rules enforced in this widget:
// - A row dated before the opening date cannot be ticked. The note is
//   exactly 不能記開帳日之前的帳.
// - A duplicate import key starts unticked and is badged 重複. The user
//   may tick it; confirm then writes another expense and keeps the key.
// - A missing or non-positive amount cannot be ticked.
// - Only ticked rows are passed to [onConfirm].

/// Bottom sheet of Apple Pay drafts. [onConfirm] is the only write path.
class ImportPreviewSheet extends StatefulWidget {
  const ImportPreviewSheet({
    super.key,
    required this.lines,
    required this.accounts,
    required this.categories,
    required this.onConfirm,
  });

  final List<ImportLine> lines;
  final List<Account> accounts;
  final List<Category> categories;
  final Future<int> Function(List<ImportCommit> rows) onConfirm;

  @override
  State<ImportPreviewSheet> createState() => _ImportPreviewSheetState();
}

class _ImportPreviewSheetState extends State<ImportPreviewSheet> {
  late List<bool> _ticked;
  late List<String?> _categoryIds;
  late List<String?> _accountIds;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Defaults: valid new rows ticked, duplicates and blocked rows not.
    _ticked = [for (final line in widget.lines) line.initiallyTicked];
    _categoryIds = [for (final line in widget.lines) line.categoryId];
    _accountIds = [for (final line in widget.lines) line.accountId];
  }

  int get _tickedCount => _ticked.where((on) => on).length;

  /// Opening-date and bad-amount rows ignore the tap. Others toggle.
  void _toggle(int index) {
    final line = widget.lines[index];
    if (!line.canTick || _busy) return;
    setState(() => _ticked[index] = !_ticked[index]);
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final commits = <ImportCommit>[];
    for (var i = 0; i < widget.lines.length; i++) {
      if (!_ticked[i]) continue;
      final line = widget.lines[i];
      // Belt: a blocked row never reaches the database even if state drifts.
      if (!line.canTick || line.amount == null) continue;
      final categoryId = _categoryIds[i];
      final accountId = _accountIds[i];
      if (categoryId == null || categoryId.isEmpty) {
        setState(() => _error = '請選分類');
        return;
      }
      if (accountId == null || accountId.isEmpty) {
        setState(() => _error = '請選帳戶');
        return;
      }
      commits.add(
        ImportCommit(
          importKey: line.importKey,
          amount: line.amount!,
          date: line.date,
          accountId: accountId,
          categoryId: categoryId,
          note: line.note,
          merchant: line.merchant,
          cardLast4: line.cardLast4,
        ),
      );
    }
    if (commits.isEmpty) {
      _close(false);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm(commits);
      if (!mounted) return;
      _close(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '請求失敗';
          _busy = false;
        });
      }
    }
  }

  void _close(bool saved) {
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        key: const Key('import-preview'),
        color: AppColors.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0x333C3C43),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '匯入預覽',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x298FB09F),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '來自 Apple Pay 捷徑',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sageDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '勾選的筆數才會入帳',
                      style: TextStyle(fontSize: 11, color: AppColors.secondary),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < widget.lines.length; i++)
                      _line(i),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          key: const Key('import-error'),
                          style: const TextStyle(
                            color: AppColors.expense,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(14, 4, 14, 12 + bottom),
                child: Row(
                  children: [
                    SizedBox(
                      width: 108,
                      height: 50,
                      child: TextButton(
                        key: const Key('import-cancel'),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0x248FB09F),
                          foregroundColor: AppColors.sageDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _busy ? null : () => _close(false),
                        child: const Text(
                          '取消',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton(
                          key: const Key('import-confirm'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.sageDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _busy ? null : _confirm,
                          child: Text(
                            _busy ? '請稍候…' : '確認匯入（$_tickedCount 筆）',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(int index) {
    final line = widget.lines[index];
    final ticked = _ticked[index];
    final blocked = line.beforeOpening;
    final badAmount = line.amount == null;
    final Color border;
    final Color background;
    if (blocked) {
      border = const Color(0x2E8B1A3A);
      background = const Color(0x0D8B1A3A);
    } else if (ticked) {
      border = const Color(0x8C5F8574);
      background = const Color(0xC7FFFFFF);
    } else {
      border = const Color(0x0A000000);
      background = const Color(0xB3F2EFE8);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: ticked ? 1.5 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InkWell(
                    key: Key('import-toggle-$index'),
                    onTap: line.canTick ? () => _toggle(index) : null,
                    child: _box(ticked: ticked, blocked: blocked),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                line.merchantLabel,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: blocked
                                      ? AppColors.secondary
                                      : AppColors.ink,
                                ),
                              ),
                            ),
                            if (line.duplicate) ...[
                              const SizedBox(width: 6),
                              const _Badge(
                                text: '重複',
                                color: Color(0xFFA86A00),
                                background: Color(0x29E8A317),
                              ),
                            ],
                            if (blocked) ...[
                              const SizedBox(width: 6),
                              const _Badge(
                                text: '早於開帳日',
                                color: AppColors.expense,
                                background: Color(0x1F8B1A3A),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${line.cardLabel} · ${line.stamp}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    line.amount == null ? '—' : formatNtd(line.amount!),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: blocked ? const Color(0xFFAEAEB2) : AppColors.ink,
                      decoration: blocked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ],
              ),
              if (line.canTick) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _select(
                        key: Key('import-category-$index'),
                        label: '分類',
                        value: _categoryName(_categoryIds[index]),
                        onTap: () => _pickCategory(index),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _select(
                        key: Key('import-account-$index'),
                        label: '帳戶',
                        value: _accountName(_accountIds[index]),
                        onTap: () => _pickAccount(index),
                      ),
                    ),
                  ],
                ),
              ],
              if (blocked)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '不能記開帳日之前的帳',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.expense,
                    ),
                  ),
                )
              else if (badAmount)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '金額不對',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFA86A00),
                    ),
                  ),
                )
              else if (line.duplicate && !ticked)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '相同匯入鍵已確認過',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFA86A00),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box({required bool ticked, required bool blocked}) {
    if (blocked) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0x148B1A3A),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0x408B1A3A)),
        ),
        child: const Icon(Icons.block, size: 14, color: AppColors.expense),
      );
    }
    if (ticked) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.sageDark,
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFC7C7CC), width: 1.5),
      ),
    );
  }

  Widget _select({
    required Key key,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x1A8FB09F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x4D8FB09F)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.secondary,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.sageDark,
            ),
          ],
        ),
      ),
    );
  }

  String _categoryName(String? id) {
    for (final category in widget.categories) {
      if (category.id == id) return category.name;
    }
    return '請選擇';
  }

  String _accountName(String? id) {
    for (final account in widget.accounts) {
      if (account.id == id) return account.name;
    }
    return '請選擇';
  }

  Future<void> _pickCategory(int index) async {
    final picked = await _pick(
      '分類',
      [for (final category in widget.categories) (category.id, category.name)],
    );
    if (picked == null || !mounted) return;
    setState(() => _categoryIds[index] = picked);
  }

  Future<void> _pickAccount(int index) async {
    final picked = await _pick(
      '帳戶',
      [for (final account in widget.accounts) (account.id, account.name)],
    );
    if (picked == null || !mounted) return;
    setState(() => _accountIds[index] = picked);
  }

  Future<String?> _pick(String title, List<(String, String)> options) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.sheet,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final option in options)
                ListTile(
                  key: Key('import-pick-${option.$1}'),
                  title: Text(option.$2),
                  onTap: () => Navigator.pop(context, option.$1),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Loads suggestions and shows the sheet. Returns true only after a confirm
/// that wrote at least one row. A link by itself never inserts.
Future<bool> showApplePayImport(BuildContext context, Uri uri) async {
  final books = BookScope.of(context);
  final api = books.api;
  final book = books.current;
  if (book == null || api is! LocalApi) {
    _say(context, '請先建立帳本');
    return false;
  }
  if (book.archived) {
    _say(context, '帳本已封存，不能寫入');
    return false;
  }
  try {
    final line = await api.previewApplePay(bookId: book.id, uri: uri);
    final accounts = await api.listAccounts(book.id);
    final categories = await api.listCategories(book.id);
    if (!context.mounted) return false;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ImportPreviewSheet(
          lines: [line],
          accounts: [
            for (final account in accounts)
              if (!account.archived) account,
          ],
          categories: [
            for (final category in categories)
              if (!category.archived && category.kind == 'expense') category,
          ],
          onConfirm: (rows) => api.confirmApplePay(bookId: book.id, rows: rows),
        );
      },
    );
    return saved == true;
  } on ApiException catch (error) {
    if (context.mounted) _say(context, error.message);
    return false;
  } catch (_) {
    if (context.mounted) _say(context, '無法讀取這筆付款');
    return false;
  }
}

void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
