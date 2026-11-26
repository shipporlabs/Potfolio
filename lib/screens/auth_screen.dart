import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signUp = true;
  bool _busy = false;
  bool _hide = true;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _form = GlobalKey<FormState>();

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('email-already-in-use')) return 'That email already has an account. Try logging in.';
    if (s.contains('invalid-credential') || s.contains('wrong-password') || s.contains('user-not-found')) return 'Email or password is incorrect.';
    if (s.contains('weak-password')) return 'Use at least 6 characters for your password.';
    if (s.contains('network')) return 'No connection. Check your internet and try again.';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Scaffold(
      backgroundColor: PColors.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Align(alignment: Alignment.centerLeft, child: Lockup(markSize: 34, background: PColors.cream)),
                  const SizedBox(height: 32),
                  Text(_signUp ? 'Create your account' : 'Welcome back', style: display(32)),
                  const SizedBox(height: 8),
                  Text(_signUp ? 'It takes a minute. No investing experience needed.' : 'Log in to see your pots.',
                      style: const TextStyle(fontSize: 16, color: PColors.slate)),
                  if (s.auth.isDemo) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: PColors.blueTint, borderRadius: BorderRadius.circular(12)),
                      child: const Text('Demo mode: Firebase isn’t connected yet, so your account stays on this device.',
                          style: TextStyle(fontSize: 13, color: PColors.navy)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(s.auth.signInWithGoogle),
                    icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: PColors.blue)),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  const Row(children: [
                    Expanded(child: Divider(color: PColors.line)),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: PColors.slate))),
                    Expanded(child: Divider(color: PColors.line)),
                  ]),
                  const SizedBox(height: 18),
                  if (_signUp) ...[
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pw,
                    obscureText: _hide,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: _hide ? 'Show password' : 'Hide password',
                        icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                  if (!_signUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          if (!_email.text.contains('@')) return;
                          await s.auth.resetPassword(_email.text.trim());
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
                        },
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            if (!_form.currentState!.validate()) return;
                            _run(() => _signUp
                                ? s.auth.signUp(_name.text.trim(), _email.text.trim(), _pw.text)
                                : s.auth.signIn(_email.text.trim(), _pw.text));
                          },
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(_signUp ? 'Create account' : 'Log in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _signUp = !_signUp),
                    child: Text(_signUp ? 'I already have an account' : 'New here? Create an account'),
                  ),
                  const SizedBox(height: 12),
                  const Text('By continuing you agree that Potfolio is an educational tool, not financial advice.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: PColors.slate)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
