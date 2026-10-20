import 'package:flutter/material.dart';

/// Single-field prompt. The controller lives on this state so the closing
/// route can finish before it is disposed.
class FieldDialog extends StatefulWidget {
  const FieldDialog({
    super.key,
    required this.title,
    required this.fieldKey,
    required this.okKey,
    this.initial = '',
    this.okLabel = '儲存',
    this.labelText,
    this.hintText,
  });

  final String title;
  final String initial;
  final Key fieldKey;
  final Key okKey;
  final String okLabel;
  final String? labelText;
  final String? hintText;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required Key fieldKey,
    required Key okKey,
    String initial = '',
    String okLabel = '確定',
    String? labelText,
    String? hintText,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => FieldDialog(
        title: title,
        initial: initial,
        fieldKey: fieldKey,
        okKey: okKey,
        okLabel: okLabel,
        labelText: labelText,
        hintText: hintText,
      ),
    );
  }

  @override
  State<FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<FieldDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          key: widget.okKey,
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.okLabel),
        ),
      ],
    );
  }
}
