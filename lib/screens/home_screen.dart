import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/stock_widgets.dart';
import 'add_money_screen.dart';
import 'create_pot_screen.dart';
import 'pot_detail_screen.dart';
import 'shell.dart';
import 'stock_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final value = s.totalValue;
    final invested = s.totalInvested;
    final change = invested > 0 ? (value - invested) / invested * 100 : 0.0;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await s.stocks.list(Market.us, refresh: true);
            await s.refreshPots();
            await s.refreshBalances();
          },
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
            Row(children: [
              const PotfolioMark(size: 34, background: PColors.mist),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Good to see you,', style: TextStyle(fontSize: 13, color: PColors.slate)),
                  Text(s.user?.firstName ?? '', style: display(20, weight: FontWeight.w700)),
                ]),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => s.refreshBalances(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ]),
            const SizedBox(height: 18),
            _ValueCard(value: value, invested: invested, change: change, funded: s.funded, usdc: s.usdc),
            const SizedBox(height: 16),
            Row(children: [
              _Action(icon: Icons.add_rounded, label: 'Add money', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMoneyScreen()))),
              _Action(icon: Icons.auto_awesome_rounded, label: 'New pot', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePotScreen()))),
              _Action(icon: Icons.travel_explore_rounded, label: 'Markets', onTap: () => Shell.goTo(context, 1)),
              _Action(icon: Icons.qr_code_rounded, label: 'Receive', onTap: () => Shell.goTo(context, 3)),
            ]),
            if (s.address == null) ...[
              const SizedBox(height: 16),
              PCard(
                color: PColors.blueTint,
                onTap: () => Shell.goTo(context, 3),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: PColors.blue),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Get your free Base wallet to receive USDC and hold tokenized stocks.', style: TextStyle(fontSize: 14, height: 1.4))),
                  const Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            SectionTitle('Your pots', action: s.myPots.isEmpty ? null : 'See all', onAction: () => Shell.goTo(context, 2)),
            if (s.myPots.isEmpty)
              PCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePotScreen())),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: PColors.blueTint, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.auto_awesome_rounded, color: PColors.blue),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Create your first pot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Pick a goal and the Guardian builds an explained mix.', style: TextStyle(fontSize: 13, color: PColors.slate)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ]),
              )
            else
              ...s.myPots.take(3).map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PotCard(pot: p, prices: s.stocks.priceMap()),
                  )),
            const SizedBox(height: 8),
            SectionTitle('On Base today', action: 'Markets', onAction: () => Shell.goTo(context, 1)),
            FutureBuilder<List<Stock>>(
              future: s.stocks.list(Market.us),
              builder: (context, snap) {
                final list = (snap.data ?? []).where((x) => x.investable).take(6).toList();
                final show = list.isNotEmpty ? list : (snap.data ?? []).take(6).toList();
                if (snap.connectionState == ConnectionState.waiting && show.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                }
                return PCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(children: [
                    for (final st in show)
                      StockTile(stock: st, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StockDetailScreen(stock: st)))),
                  ]),
                );
              },
            ),
            const SizedBox(height: 16),
            const _LearnCard(),
          ]),
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final double value, invested, change;
  final double? funded, usdc;
  const _ValueCard({required this.value, required this.invested, required this.change, this.funded, this.usdc});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: PColors.navy, borderRadius: BorderRadius.circular(26)),
        child: Stack(children: [
          const Positioned(right: -30, top: -30, child: Opacity(opacity: 0.12, child: DonutO(size: 150, palette: MarkPalette.onNavy))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pots value', style: TextStyle(color: Color(0xFFA8B6D4), fontSize: 13)),
            const SizedBox(height: 6),
            Text(money(value), style: display(38, color: Colors.white)),
            const SizedBox(height: 8),
            Row(children: [
              Tag(invested > 0 ? '${pct(change)} all time' : 'Start with any amount',
                  bg: Colors.white.withValues(alpha: 0.12), fg: change >= 0 ? const Color(0xFF7CF0B5) : const Color(0xFFFF9A9A)),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _Mini('Wallet USDC', usdc == null ? '—' : money(usdc!))),
              Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.12)),
              const SizedBox(width: 16),
              Expanded(child: _Mini('Added via checkout', funded == null ? '—' : money(funded!))),
            ]),
          ]),
        ]),
      );
}

class _Mini extends StatelessWidget {
  final String k, v;
  const _Mini(this.k, this.v);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: Color(0xFFA8B6D4), fontSize: 12)),
        const SizedBox(height: 2),
        Text(v, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ]);
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: PColors.line)),
                child: Icon(icon, color: PColors.blue),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class PotCard extends StatelessWidget {
  final Pot pot;
  final Map<String, double> prices;
  const PotCard({super.key, required this.pot, required this.prices});
  @override
  Widget build(BuildContext context) {
    final v = pot.valueWith(prices);
    final ch = pot.amount > 0 ? (v - pot.amount) / pot.amount * 100 : 0.0;
    return PCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PotDetailScreen(pot: pot))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          LogoStack(urls: pot.allocations.map((a) => a.logo ?? '').toList(), names: pot.allocations.map((a) => a.name).toList()),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(v), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(pct(ch), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ch >= 0 ? PColors.gain : PColors.loss)),
          ]),
        ]),
        const SizedBox(height: 12),
        Text(pot.name, style: display(18, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('${pot.goal.label} · ${pot.allocations.length} stocks', style: const TextStyle(fontSize: 13, color: PColors.slate)),
        const SizedBox(height: 12),
        AllocationBar(weights: pot.allocations.map((a) => a.weight).toList(), height: 8),
      ]),
    );
  }
}

class _LearnCard extends StatelessWidget {
  const _LearnCard();
  @override
  Widget build(BuildContext context) => PCard(
        color: PColors.cream,
        child: Row(children: [
          const PotfolioMark(size: 44, background: PColors.cream),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('What do you actually own?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Tokenized stocks track a real share held by a custodian. You get the price exposure, not voting rights.',
                  style: TextStyle(fontSize: 13, height: 1.45, color: PColors.slate)),
            ]),
          ),
        ]),
      );
}
