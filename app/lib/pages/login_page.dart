import 'package:flutter/material.dart';
import 'package:full_jizhang/api.dart';
import 'package:full_jizhang/auth.dart';
import 'package:full_jizhang/theme.dart';
import 'package:full_jizhang/widgets/brand_mark.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(bool register) {
    if (_register == register) return;
    setState(() {
      _register = register;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = '請填 email');
      return;
    }
    if (_register && password.length < 8) {
      setState(() => _error = '密碼至少 8 碼');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = AuthScope.of(context);
    try {
      if (_register) {
        await auth.register(email: email, password: password);
      } else {
        await auth.login(email: email, password: password);
      }
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
    final text = Theme.of(context).textTheme;
    return GlassBackground(
      child: AppFrame(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 42,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const BrandMark(),
                      const SizedBox(height: 22),
                      Text(
                        'Full 記帳',
                        style: text.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '個人帳簿 · 淨資產一目了然',
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      _Segmented(
                        register: _register,
                        onChanged: _busy ? null : _setMode,
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                        child: Column(
                          children: [
                            _Field(
                              label: 'Email',
                              controller: _email,
                              hint: 'you@example.com',
                              fieldKey: const Key('email-field'),
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
                            ),
                            const Divider(height: 22, color: AppColors.line),
                            _Field(
                              label: '密碼',
                              controller: _password,
                              hint: '至少 8 碼',
                              fieldKey: const Key('password-field'),
                              obscure: true,
                              autofillHints: [
                                _register
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                            ),
                          ],
                        ),
                      ),
                      if (!_register)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              setState(() => _error = '這個版本還沒有重設密碼');
                            },
                            child: Text(
                              '忘記密碼？',
                              style: text.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 12),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _error!,
                            key: const Key('auth-error'),
                            style: text.bodySmall?.copyWith(
                              color: AppColors.expense,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      _SubmitButton(
                        label: _busy ? '請稍候…' : (_register ? '註冊' : '登入'),
                        onPressed: _busy ? null : _submit,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _register ? '已有帳號？' : '還沒帳號？',
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          TextButton(
                            key: const Key('auth-switch'),
                            onPressed: _busy
                                ? null
                                : () => _setMode(!_register),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.sageDark,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _register ? '立即登入' : '立即註冊',
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.sageDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '資料只屬於你 · Email＋密碼登入',
                        style: text.bodySmall?.copyWith(
                          color: AppColors.faint,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.register, required this.onChanged});

  final bool register;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.track,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _Segment(
              key: const Key('auth-tab-login'),
              label: '登入',
              selected: !register,
              onTap: onChanged == null ? null : () => onChanged!(false),
            ),
            _Segment(
              key: const Key('auth-tab-register'),
              label: '註冊',
              selected: register,
              onTap: onChanged == null ? null : () => onChanged!(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        elevation: selected ? 1 : 0,
        shadowColor: const Color(0x22000000),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                color: selected ? AppColors.ink : AppColors.muted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.fieldKey,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final Key fieldKey;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodySmall),
        TextField(
          key: fieldKey,
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: !obscure,
          cursorColor: AppColors.sageDark,
          style: text.bodyLarge,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: text.bodyLarge?.copyWith(
              color: AppColors.faint,
              fontWeight: FontWeight.w400,
            ),
            contentPadding: const EdgeInsets.only(top: 6, bottom: 2),
          ),
        ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFA7C7B6), AppColors.sage, Color(0xFF7EA592)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x338FB09F),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('auth-submit'),
          borderRadius: BorderRadius.circular(28),
          onTap: onPressed,
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(
                    alpha: onPressed == null ? 0.7 : 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
