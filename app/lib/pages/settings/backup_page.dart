import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/session/books.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/soft_card.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _import = TextEditingController();
  String? _export;
  String? _error;
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _import.dispose();
    super.dispose();
  }

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
      if (!mounted) return;
      setState(() {
        _export = const JsonEncoder.withIndent('  ').convert(payload);
        _message = '已匯出這本帳';
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '請求失敗');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBook() async {
    final book = BookScope.of(context).current;
    if (book == null) {
      setState(() => _error = '請先建立帳本');
      return;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(_import.text);
    } on FormatException {
      setState(() => _error = 'JSON 格式不對');
      return;
    }
    if (decoded is! Map) {
      setState(() => _error = 'JSON 格式不對');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await BookScope.of(context).api.importBook(
        id: book.id,
        payload: Map<String, dynamic>.from(decoded),
      );
      if (!mounted) return;
      await BookScope.of(context).reload();
      if (!mounted) return;
      setState(() => _message = '已還原');
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
          child: const Text('匯出 JSON'),
        ),
        if (_export != null) ...[
          const SizedBox(height: 8),
          SoftCard(
            child: SelectableText(
              _export!,
              key: const Key('backup-json'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const Key('backup-import-field'),
          controller: _import,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: '貼上備份 JSON',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('backup-import'),
          onPressed: _busy ? null : _importBook,
          child: const Text('還原這本帳'),
        ),
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
