import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_providers.dart';

/// 登入 / 註冊頁：
/// • AnimatedSwitcher 切換「登入 ⇆ 註冊」表單（淡入 + 位移）
/// • AnimatedContainer 做背景漸層切換
/// • 按鈕在執行期間顯示 CircularProgressIndicator
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pwd = TextEditingController();

  bool _isRegister = false;
  bool _loading = false;

  /// 依登入 / 註冊模式決定背景漸層顏色
  (Color, Color) _bgColors(ColorScheme scheme) =>
      _isRegister
          ? (scheme.secondaryContainer, scheme.tertiaryContainer)
          : (scheme.primaryContainer, scheme.surfaceVariant);

  @override
  void dispose() {
    _email.dispose();
    _pwd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final scheme = Theme.of(context).colorScheme;

    return authState.when(
      // 已登入時自動導回首頁
      data: (user) {
        if (user != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 背景漸層容器
        final (c1, c2) = _bgColors(scheme);

        return Scaffold(
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c1, c2],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 4,
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: _buildForm(context, scheme),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Auth error: $e'))),
    );
  }

  /// 表單本體 + AnimatedSwitcher
  Widget _buildForm(BuildContext context, ColorScheme scheme) {
    final authRepo = ref.read(authRepoProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder:
          (child, anim) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: FadeTransition(opacity: anim, child: child),
          ),
      child:
          _isRegister
              ? _RegisterView(
                key: const ValueKey('register'),
                isLoading: _loading,
                emailCtrl: _email,
                pwdCtrl: _pwd,
                onSubmit: () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _loading = true);
                  try {
                    await authRepo.registerWithEmail(
                      email: _email.text.trim(),
                      pwd: _pwd.text.trim(),
                    );
                  } catch (e) {
                    if (mounted) _showError(context, e.toString());
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                onSwitchMode: () => setState(() => _isRegister = false),
              )
              : _LoginView(
                key: const ValueKey('login'),
                isLoading: _loading,
                emailCtrl: _email,
                pwdCtrl: _pwd,
                onSubmit: () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _loading = true);
                  try {
                    await authRepo.signInWithEmail(
                      email: _email.text.trim(),
                      pwd: _pwd.text.trim(),
                    );
                  } catch (e) {
                    if (mounted) _showError(context, e.toString());
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                onGoogle: () async {
                  setState(() => _loading = true);
                  try {
                    await authRepo.signInWithGoogle();
                  } catch (e) {
                    if (mounted) _showError(context, e.toString());
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                onSwitchMode: () => setState(() => _isRegister = true),
              ),
    );
  }

  void _showError(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(SnackBar(content: Text('登入失敗：$msg')));
  }
}

/* ─────────────── 子元件：登入 View ─────────────── */

class _LoginView extends StatelessWidget {
  const _LoginView({
    super.key,
    required this.isLoading,
    required this.emailCtrl,
    required this.pwdCtrl,
    required this.onSubmit,
    required this.onGoogle,
    required this.onSwitchMode,
  });

  final bool isLoading;
  final TextEditingController emailCtrl, pwdCtrl;
  final VoidCallback onSubmit, onGoogle, onSwitchMode;

  @override
  Widget build(BuildContext context) {
    return _AuthFormLayout(
      title: 'Sign in',
      formKey: GlobalKey<FormState>(),
      emailCtrl: emailCtrl,
      pwdCtrl: pwdCtrl,
      buttonLabel: 'Sign in',
      isLoading: isLoading,
      onSubmit: onSubmit,
      footer: Column(
        children: [
          TextButton(
            onPressed: isLoading ? null : onSwitchMode,
            child: const Text('No account? Register'),
          ),
          const SizedBox(height: 8),
          SignInButton(Buttons.Google, onPressed: isLoading ? () {} : onGoogle),
        ],
      ),
    );
  }
}

/* ─────────────── 子元件：註冊 View ─────────────── */

class _RegisterView extends StatelessWidget {
  const _RegisterView({
    super.key,
    required this.isLoading,
    required this.emailCtrl,
    required this.pwdCtrl,
    required this.onSubmit,
    required this.onSwitchMode,
  });

  final bool isLoading;
  final TextEditingController emailCtrl, pwdCtrl;
  final VoidCallback onSubmit, onSwitchMode;

  @override
  Widget build(BuildContext context) {
    return _AuthFormLayout(
      title: 'Register',
      formKey: GlobalKey<FormState>(),
      emailCtrl: emailCtrl,
      pwdCtrl: pwdCtrl,
      buttonLabel: 'Register',
      isLoading: isLoading,
      onSubmit: onSubmit,
      footer: TextButton(
        onPressed: isLoading ? null : onSwitchMode,
        child: const Text('Already have account? Sign in'),
      ),
    );
  }
}

/* ─────────────── 通用表單骨架 ─────────────── */

class _AuthFormLayout extends StatelessWidget {
  const _AuthFormLayout({
    required this.title,
    required this.formKey,
    required this.emailCtrl,
    required this.pwdCtrl,
    required this.buttonLabel,
    required this.isLoading,
    required this.onSubmit,
    required this.footer,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, pwdCtrl;
  final String buttonLabel;
  final bool isLoading;
  final VoidCallback onSubmit;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      key: ValueKey(title),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.notoSans(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                validator:
                    (v) =>
                        (v != null && v.contains('@')) ? null : 'Invalid email',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pwdCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator:
                    (v) => (v != null && v.length >= 6) ? null : '至少 6 字元',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSubmit,
                  child:
                      isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        footer,
      ],
    );
  }
}
