// lib/pages/sign_in_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // 已登入，直接跳到首頁
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/');
          });
          // 仍顯示 Loading
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final authRepo = ref.read(authRepoProvider);

        return Scaffold(
          appBar: AppBar(title: Text(_isRegister ? 'Register' : 'Sign in')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) =>
                        v != null && v.contains('@') ? null : 'Invalid email',
                  ),
                  TextFormField(
                    controller: _pwd,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) =>
                        v != null && v.length >= 6 ? null : '至少 6 字元',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      try {
                        if (_isRegister) {
                          await authRepo.registerWithEmail(
                            email: _email.text.trim(),
                            pwd: _pwd.text.trim(),
                          );
                        } else {
                          await authRepo.signInWithEmail(
                            email: _email.text.trim(),
                            pwd: _pwd.text.trim(),
                          );
                        }
                      } catch (e) {
                        // 將錯誤訊息以 SnackBar 顯示
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('登入失敗：${e.toString()}')),
                        );
                      }
                    },
                    child: Text(_isRegister ? 'Register' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isRegister = !_isRegister),
                    child: Text(
                      _isRegister
                          ? 'Already have account? Sign in'
                          : 'No account? Register',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SignInButton(
                    Buttons.Google,
                    onPressed: () async {
                      try {
                        await authRepo.signInWithGoogle();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Google 登入失敗：${e.toString()}')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}
