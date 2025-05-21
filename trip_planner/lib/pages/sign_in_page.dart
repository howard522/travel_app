import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import '../providers/auth_providers.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});
  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  bool _isRegister = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.read(authRepoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? 'Register' : 'Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_err != null)
                Text(_err!, style: const TextStyle(color: Colors.red)),
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
                    v != null && v.length >= 6 ? null : '≥ 6 chars',
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  try {
                    if (_isRegister) {
                      await authRepo.registerWithEmail(
                          email: _email.text, pwd: _pwd.text);
                    } else {
                      await authRepo.signInWithEmail(
                          email: _email.text, pwd: _pwd.text);
                    }
                  } catch (e) {
                    setState(() => _err = e.toString());
                  }
                },
                child: Text(_isRegister ? 'Register' : 'Sign in'),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _isRegister = !_isRegister),
                child: Text(_isRegister
                    ? 'Already have account? Sign in'
                    : 'No account? Register'),
              ),
              const SizedBox(height: 16),
              SignInButton(
                Buttons.Google,
                onPressed: () async {
                  try {
                    await authRepo.signInWithGoogle();
                  } catch (e) {
                    setState(() => _err = e.toString());
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
