import 'package:flutter/material.dart';

// Password prompts for 設定.
//
// Purpose: collect the strings [LockController] needs. This dialog does
// not hash, does not store, and does not decide the rules.
//
// Rules (enforced again by the controller, not here):
// - Enable: new password + confirmation, at least 4 characters, must match.
// - Disable: current password only.
// - Change: current password, then the new pair. The controller checks the
//   current password before the new pair so a too-short new password cannot
//   skip the failure counter.
// - Nothing is trimmed. A space is part of the password, on this dialog
//   and on the lock screen.

enum PasswordFormMode { enable, disable, change }

/// Raw fields from the dialog. Empty strings are possible; the controller
/// rejects them. Null from [showPasswordForm] means the user cancelled.
class PasswordForm {
  const PasswordForm({
    this.current = '',
    this.next = '',
    this.confirmation = '',
  });

  final String current;
  final String next;
  final String confirmation;
}

Future<PasswordForm?> showPasswordForm(
  BuildContext context, {
  required PasswordFormMode mode,
}) {
  return showDialog<PasswordForm>(
    context: context,
    builder: (context) => _PasswordFormDialog(mode: mode),
  );
}

class _PasswordFormDialog extends StatefulWidget {
  const _PasswordFormDialog({required this.mode});

  final PasswordFormMode mode;

  @override
  State<_PasswordFormDialog> createState() => _PasswordFormDialogState();
}

class _PasswordFormDialogState extends State<_PasswordFormDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(
      context,
      PasswordForm(
        current: _current.text,
        next: _next.text,
        confirmation: _confirm.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final title = switch (mode) {
      PasswordFormMode.enable => '設定密碼鎖',
      PasswordFormMode.disable => '關閉密碼鎖',
      PasswordFormMode.change => '變更密碼',
    };
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mode != PasswordFormMode.enable)
            _field(
              controller: _current,
              fieldKey: const Key('settings-password-current'),
              label: '目前密碼',
              autofocus: true,
              onSubmitted: mode == PasswordFormMode.disable ? _submit : null,
            ),
          if (mode != PasswordFormMode.disable) ...[
            if (mode == PasswordFormMode.change) const SizedBox(height: 8),
            _field(
              controller: _next,
              fieldKey: const Key('settings-password-next'),
              label: '新密碼',
              autofocus: mode == PasswordFormMode.enable,
            ),
            const SizedBox(height: 8),
            _field(
              controller: _confirm,
              fieldKey: const Key('settings-password-confirm'),
              label: '再輸入一次',
              onSubmitted: _submit,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('settings-password-cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          key: const Key('settings-password-ok'),
          onPressed: _submit,
          child: Text(mode == PasswordFormMode.disable ? '關閉' : '儲存'),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required Key fieldKey,
    required String label,
    bool autofocus = false,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      enableIMEPersonalizedLearning: false,
      autofocus: autofocus,
      decoration: InputDecoration(labelText: label),
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
    );
  }
}
