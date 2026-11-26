import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand.dart';
import 'home_screen.dart';
import 'markets_screen.dart';
import 'pots_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  static void goTo(BuildContext context, int tab) => context.findAncestorStateOfType<_ShellState>()?.go(tab);
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;
  void go(int i) => setState(() => _i = i);

  static const _dest = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.candlestick_chart_outlined, Icons.candlestick_chart, 'Markets'),
    (Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded, 'Pots'),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Wallet'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pages = const [HomeScreen(), MarketsScreen(), PotsScreen(), WalletScreen(), ProfileScreen()];
    final body = IndexedStack(index: _i, children: pages);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            backgroundColor: Colors.white,
            selectedIndex: _i,
            onDestinationSelected: go,
            labelType: NavigationRailLabelType.all,
            indicatorColor: PColors.blueTint,
            leading: const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: PotfolioMark(size: 36)),
            destinations: [for (final d in _dest) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2, color: PColors.blue), label: Text(d.$3))],
          ),
          const VerticalDivider(width: 1, color: PColors.line),
          Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body))),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: go,
        destinations: [for (final d in _dest) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2, color: PColors.blue), label: d.$3)],
      ),
    );
  }
}
