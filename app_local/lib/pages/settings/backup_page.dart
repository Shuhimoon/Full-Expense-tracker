import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/services/backup_preview.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/soft_card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Export and replace for the current book only.
///
/// Export writes the JSON from `ApiClient.exportBook`, which matches
/// `api/internal/app/backup.go` `exportBook` (same keys as a Go backup).
/// Import parses that JSON, shows [BackupPreview] (name, opening date, and
/// counts), and does not write until the user taps 取代. 取代 calls
/// `importBook`, which deletes the book's rows and inserts the file inside
/// one transaction, remapping ids and transfer `pair_id`. Cancel drops the
/// preview. The JSON file is a backup, not the live database.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  String? _error;
  String? _message;
  bool _busy = false;
  BackupPreview? _preview;
  Map<String, dynamic>? _pending;

  /// Shares a pretty-printed JSON file for the current book.
  Future<void> _exportBook() async {
    final book = BookScope.of(context).current;
    if (book == null) {
      setState(() => _error = '請先建立帳本');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final payload = await BookScope.of(context).api.exportBook(book.id);
      final encoded = const JsonEncoder.withIndent('  ').convert(payload);
      final dir = await getTemporaryDirectory();
      final name = 'fulljizhang-${book.name}-${book.openingDate ?? 'book'}.json';
      final file = File('${dir.path}/$name');
      await file.writeAsString(encoded);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      if (!mounted) return;
      setState(() => _message = '已匯出這本帳');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '匯出失敗');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reads a `.json` file into memory and shows a preview. No database write.
  ///
  /// A non-object or invalid JSON is 「JSON 格式不對」. The payload is kept in
  /// [_pending] until [_replace] or cancel.
  Future<void> _pickImport() async {
    final book = BookScope.of(context).current;
    if (book == null) {
      setState(() => _error = '請先建立帳本');
      return;
    }
    setState(() {
      _error = null;
      _message = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    String raw;
    try {
      if (file.bytes != null) {
        raw = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        raw = await File(file.path!).readAsString();
      } else {
        setState(() => _error = 'JSON 格式不對');
        return;
      }
    } catch (_) {
      setState(() => _error = 'JSON 格式不對');
      return;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      setState(() => _error = 'JSON 格式不對');
      return;
    }
    if (decoded is! Map) {
      setState(() => _error = 'JSON 格式不對');
      return;
    }
    final payload = Map<String, dynamic>.from(decoded);
    setState(() {
      _pending = payload;
      _preview = BackupPreview.parse(payload);
    });
  }

  /// Replaces the current book's contents with [_pending].
  ///
  /// `importBook` is transactional: a failure leaves the old book in place
  /// and shows the error. On success the book list is reloaded.
  Future<void> _replace() async {
    final book = BookScope.of(context).current;
    final payload = _pending;
    if (book == null || payload == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await BookScope.of(context).api.importBook(id: book.id, payload: payload);
      if (!mounted) return;
      await BookScope.of(context).reload();
      if (!mounted) return;
      setState(() {
        _message = '已還原';
        _preview = null;
        _pending = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '還原失敗');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancelPreview() {
    setState(() {
      _preview = null;
      _pending = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return PageScroll(
      children: [
        const SubpageHeader(title: '備份與還原'),
        const SizedBox(height: 8),
        const Text(
          '匯出與還原都只針對目前這本帳。JSON 是備份檔，不是帳本正本。',
          style: TextStyle(fontSize: 12, color: AppColors.secondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('backup-export'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.sage,
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: _busy ? null : _exportBook,
          child: const Text('匯出'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('backup-import'),
          onPressed: _busy ? null : _pickImport,
          child: const Text('匯入'),
        ),
        if (preview != null) ...[
          const SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.bookName.isEmpty ? '這本帳' : preview.bookName,
                  key: const Key('backup-preview-name'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '開帳日：${preview.openingDate ?? '—'}',
                  key: const Key('backup-preview-opening'),
                ),
                Text('帳戶 ${preview.accounts}'),
                Text('分類 ${preview.categories}'),
                Text('分錄 ${preview.entries}'),
                Text('成交 ${preview.trades}'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        key: const Key('backup-replace'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.expense,
                        ),
                        onPressed: _busy ? null : _replace,
                        child: const Text('取代'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('backup-cancel'),
                        onPressed: _busy ? null : _cancelPreview,
                        child: const Text('取消'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _message!,
              key: const Key('backup-message'),
              style: const TextStyle(color: AppColors.sageDark),
            ),
          ),
        ErrorLine(_error, lineKey: const Key('backup-error')),
      ],
    );
  }
}
