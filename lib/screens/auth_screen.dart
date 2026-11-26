import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../targets.dart';
import '../widgets/brand.dart';
import '../widgets/motion.dart';

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
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      final form = _formCard(context, s, wide: wide);
      if (!wide) {
        return Scaffold(
          backgroundColor: PColors.cream,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: form),
              ),
            ),
          ),
        );
      }
      // Web and tablets: brand story on the left, form on the right.
      return Scaffold(
        backgroundColor: Colors.white,
        body: Row(children: [
          const Expanded(flex: 11, child: _BrandPanel()),
          Expanded(
            flex: 9,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: form),
              ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _formCard(BuildContext context, AppState s, {required bool wide}) => Form(
        key: _form,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!wide) const Align(alignment: Alignment.centerLeft, child: Lockup(markSize: 34, background: PColors.cream)),
            SizedBox(height: wide ? 0 : 28),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Log in')),
                ButtonSegment(value: true, label: Text('Create account')),
              ],
              selected: {_signUp},
              showSelectedIcon: false,
              onSelectionChanged: _busy ? null : (v) => setState(() => _signUp = v.first),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Column(
                key: ValueKey(_signUp),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_signUp ? 'Create your account' : 'Welcome back', style: display(wide ? 34 : 30)),
                  const SizedBox(height: 8),
                  Text(_signUp ? 'Pick a goal, get a plan. No investing experience needed.' : 'Log in to check on your goals.',
                      style: const TextStyle(fontSize: 16, color: PColors.slate)),
                ],
              ),
            ),
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
              label: Text(_signUp ? 'Sign up with Google' : 'Continue with Google'),
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
            ),
            const SizedBox(height: 18),
            const Row(children: [
              Expanded(child: Divider(color: PColors.line)),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or with email', style: TextStyle(color: PColors.slate))),
              Expanded(child: Divider(color: PColors.line)),
            ]),
            const SizedBox(height: 18),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _signUp
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(labelText: 'Full name'),
                        validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
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
              autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
              onFieldSubmitted: (_) => _submit(s),
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: _signUp ? 'At least 6 characters' : null,
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
                    if (!_email.text.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email first.')));
                      return;
                    }
                    await s.auth.resetPassword(_email.text.trim());
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
                  },
                  child: const Text('Forgot password?'),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () => _submit(s),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(_signUp ? 'Create account' : 'Log in'),
            ),
            const SizedBox(height: 16),
            const Text('By continuing you agree that Potfolio is an educational tool, not financial advice.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: PColors.slate)),
          ]),
        ),
      );

  void _submit(AppState s) {
    if (_busy || !_form.currentState!.validate()) return;
    _run(() => _signUp ? s.auth.signUp(_name.text.trim(), _email.text.trim(), _pw.text) : s.auth.signIn(_email.text.trim(), _pw.text));
  }
}

/// Left side of the wide (web) sign-in screen.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();
  @override
  Widget build(BuildContext context) => Container(
        color: PColors.navy,
        padding: const EdgeInsets.fromLTRB(56, 40, 56, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Lockup(markSize: 34, textColor: Colors.white, palette: MarkPalette.onNavy, background: PColors.navy),
          const Spacer(),
          Text('Build a', style: display(54, color: Colors.white)),
          const Wordmark(word: 'portfolio,', fontSize: 54, color: Colors.white, palette: MarkPalette.onNavy),
          const SizedBox(height: 4),
          Text('not a guess.', style: display(54, color: Colors.white)),
          const SizedBox(height: 18),
          const Text('Save for rent, a phone or japa. The AI Guardian builds a stock mix for your goal and tells you what to add each week.',
              style: TextStyle(color: Color(0xFFC9D6F2), fontSize: 17, height: 1.5)),
          const SizedBox(height: 32),
          const _DemoGoal(),
          const Spacer(),
          const Text('Educational, not financial advice. Tokenized stocks on Base, for eligible users outside the US.',
              style: TextStyle(color: Color(0xFF8FA3C8), fontSize: 12)),
        ]),
      );
}

/// A looping example goal so the panel feels alive.
class _DemoGoal extends StatefulWidget {
  const _DemoGoal();
  @override
  State<_DemoGoal> createState() => _DemoGoalState();
}

class _DemoGoalState extends State<_DemoGoal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = goalTemplates.first;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = Curves.easeInOutCubic.transform((_c.value * 1.25).clamp(0, 1).toDouble());
            final saved = 20 + 380 * v;
            return Row(children: [
              FloatingArt(t.art, height: 76),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('\$${saved.round()} of \$400', style: display(22)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: saved / 400, minHeight: 8, backgroundColor: PColors.line, color: v >= 1 ? PColors.gain : PColors.blue),
                  ),
                  const SizedBox(height: 6),
                  Text(v >= 1 ? 'Target reached' : 'Add \$15 every week', style: const TextStyle(fontSize: 12, color: PColors.slate)),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
