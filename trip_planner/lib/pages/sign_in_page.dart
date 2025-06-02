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
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _isRegister = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 監聽使用者登入狀態
    final authStateAsyncValue = ref.watch(authStateProvider);

    return authStateAsyncValue.when(
      data: (user) {
        // 如果已登入，立刻導向首頁
        if (user != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            GoRouter.of(context).go('/');
          });
          // 等待轉跳期間先顯示 Loading
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 尚未登入，顯示登入/註冊表單
        final authRepo = ref.read(authRepoProvider);

        return Scaffold(
          appBar: AppBar(
            title: Text(_isRegister ? 'Register' : 'Sign in'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email 欄位
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return '請輸入 Email';
                            }
                            final email = v.trim();
                            if (!email.contains('@') || !email.contains('.')) {
                              return '請輸入有效的 Email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Password 欄位
                        TextFormField(
                          controller: _pwdCtrl,
                          decoration: const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return '請輸入密碼';
                            }
                            if (v.trim().length < 6) {
                              return '密碼至少 6 個字元';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        // 登入 / 註冊 按鈕
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    // 先觸發表單驗證
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setState(() {
                                      _isLoading = true;
                                    });
                                    final email = _emailCtrl.text.trim();
                                    final pwd = _pwdCtrl.text.trim();

                                    try {
                                      if (_isRegister) {
                                        // 註冊
                                        await authRepo.registerWithEmail(
                                          email: email,
                                          pwd: pwd,
                                        );
                                      } else {
                                        // 登入
                                        await authRepo.signInWithEmail(
                                          email: email,
                                          pwd: pwd,
                                        );
                                      }
                                      // 成功後，FirebaseAuth 的 authStateChanges 會觸發
                                    } on Exception catch (e) {
                                      // 顯示錯誤訊息
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          _isLoading = false;
                                        });
                                      }
                                    }
                                  },
                            child: Text(_isRegister ? 'Register' : 'Sign in'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 切換登入 / 註冊
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() => _isRegister = !_isRegister);
                                },
                          child: Text(_isRegister
                              ? 'Already have account? Sign in'
                              : 'No account? Register'),
                        ),
                        const SizedBox(height: 24),
                        // Google 登入 按鈕：改為永遠傳入非空同步 function
                        SignInButton(
                          Buttons.Google,
                          onPressed: () {
                            // 如果正在 loading，就不做任何事
                            if (_isLoading) return;
                            _handleGoogleSignIn(authRepo, context);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () {
        // 判斷 FirebaseAuth.authStateChanges() 還在載入中
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (e, _) {
        // 探測 authState 時發生錯誤
        return Scaffold(
          body: Center(child: Text('Error: $e')),
        );
      },
    );
  }

  /// 處理 Google 登入的邏輯
  Future<void> _handleGoogleSignIn(
      AuthRepository authRepo, BuildContext context) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await authRepo.signInWithGoogle();
      // 成功後，authStateChanges 會觸發頁面轉跳
    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google 登入失敗：${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
