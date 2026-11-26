import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';

class _Page {
  final String art, eyebrow, title, body;
  final Color bg;
  const _Page(this.art, this.eyebrow, this.title, this.body, this.bg);
}

const _pages = [
  _Page('assets/illustrations/onboard_goal.svg', 'Start with a goal', 'Build a portfolio,\nnot a guess.',
      'Tell us what the money is for: wealth, tech growth, income or the long term. We take it from there.', PColors.cream),
  _Page('assets/illustrations/onboard_guardian.svg', 'Meet the Guardian', 'Every pick,\nexplained.',
      'Our AI Guardian proposes a mix of stocks, tells you why each one belongs and flags the risk before you commit.', Color(0xFFEFF4FF)),
  _Page('assets/illustrations/onboard_base.svg', 'Yours, onchain', 'Saved on Base.\nOwned by you.',
      'Get your own wallet in seconds. Your pots are yours to verify, and you approve every step.', Color(0xFFFFF3EC)),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _c = PageController();
  int _i = 0;

  void _next() {
    if (_i < _pages.length - 1) {
      _c.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      context.read<AppState>().finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pages[_i];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: p.bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(children: [
                    Lockup(markSize: 28, background: p.bg),
                    const Spacer(),
                    if (_i < _pages.length - 1)
                      TextButton(onPressed: () => context.read<AppState>().finishOnboarding(), child: const Text('Skip')),
                  ]),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _c,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _i = i),
                    itemBuilder: (_, i) => _PageBody(_pages[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var k = 0; k < _pages.length; k++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: k == _i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(color: k == _i ? PColors.blue : PColors.navy.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        ),
                    ]),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: _next, child: Text(_i == _pages.length - 1 ? 'Get started' : 'Next')),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  final _Page p;
  const _PageBody(this.p);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.92, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: SvgPicture.asset(p.art, height: (c.maxHeight * 0.45).clamp(180.0, 320.0).toDouble(), semanticsLabel: p.eyebrow),
                ),
              ),
              const SizedBox(height: 28),
              Text(p.eyebrow.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: PColors.blue)),
              const SizedBox(height: 10),
              Text(p.title, style: display(36)),
              const SizedBox(height: 12),
              Text(p.body, style: const TextStyle(fontSize: 16, height: 1.55, color: PColors.slate)),
            ]),
          ),
        ),
      );
}
