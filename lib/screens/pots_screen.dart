import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/stock_widgets.dart';
import 'create_pot_screen.dart';
import 'home_screen.dart';

class PotsScreen extends StatelessWidget {
  const PotsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    void create() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePotScreen()));
    return Scaffold(
      appBar: AppBar(title: const Text('Pots')),
      floatingActionButton: s.myPots.isEmpty
          ? null
          : FloatingActionButton.extended(onPressed: create, icon: const Icon(Icons.add_rounded), label: const Text('New pot'), backgroundColor: PColors.blue, foregroundColor: Colors.white),
      body: s.myPots.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  SvgPicture.asset('assets/illustrations/empty_pots.svg', height: 200, semanticsLabel: 'An empty pot'),
                  const SizedBox(height: 24),
                  Text('No pots yet', style: display(26)),
                  const SizedBox(height: 8),
                  const Text('A pot is a mix of stocks for one goal. The Guardian builds it and explains every pick.',
                      textAlign: TextAlign.center, style: TextStyle(color: PColors.slate, height: 1.5)),
                  const SizedBox(height: 24),
                  SizedBox(width: 280, child: FilledButton.icon(onPressed: create, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Create a pot'))),
                ]),
              ),
            )
          : RefreshIndicator(
              onRefresh: s.refreshPots,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 96), children: [
                PCard(
                  color: PColors.navy,
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('All pots', style: TextStyle(color: Color(0xFFA8B6D4), fontSize: 13)),
                        Text(money(s.totalValue), style: display(28, color: Colors.white)),
                      ]),
                    ),
                    Text('${s.myPots.length} ${s.myPots.length == 1 ? 'pot' : 'pots'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 14),
                for (final p in s.myPots) Padding(padding: const EdgeInsets.only(bottom: 12), child: PotCard(pot: p, prices: s.stocks.priceMap())),
              ]),
            ),
    );
  }
}
