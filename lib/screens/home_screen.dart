import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../targets.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/motion.dart';
import '../widgets/stock_widgets.dart';
import 'add_money_screen.dart';
import 'create_pot_screen.dart';
import 'pot_detail_screen.dart';
import 'share_pot_sheet.dart';
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
            _ValueCard(value: value, invested: invested, change: change, balance: s.usdc == null && s.funded == null ? null : s.balance, available: s.available),
            const SizedBox(height: 16),
            Row(children: [
              _Action(icon: Icons.add_rounded, label: 'Add money', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMoneyScreen()))),
              _Action(icon: Icons.auto_awesome_rounded, label: 'New pot', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePotScreen()))),
              _Action(icon: Icons.travel_explore_rounded, label: 'Markets', onTap: () => Shell.goTo(context, 1)),
              _Action(icon: Icons.qr_code_rounded, label: 'Receive', onTap: () => Shell.goTo(context, 3)),
            ]),
            const SizedBox(height: 12),
            const _ThingsToDo(),
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
            SectionTitle('Start a goal', action: 'All goals', onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePotScreen()))),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: goalTemplates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _GoalChip(t: goalTemplates[i]),
              ),
            ),
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
  final double? balance;
  final double available;
  const _ValueCard({required this.value, required this.invested, required this.change, this.balance, required this.available});
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
              Expanded(child: _Mini('Your balance', balance == null ? '—' : money(balance!))),
              Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.12)),
              const SizedBox(width: 16),
              Expanded(child: _Mini('Free to save', balance == null ? '—' : money(available))),
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
    final v = pot.valueNow(prices);
    final ch = pot.invested > 0 ? (v - pot.invested) / pot.invested * 100 : 0.0;
    final plan = pot.plan();
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
        if (plan == null) ...[
          Text('${pot.goal.label} · ${pot.allocations.length} stocks', style: const TextStyle(fontSize: 13, color: PColors.slate)),
          const SizedBox(height: 12),
          AllocationBar(weights: pot.allocations.map((a) => a.weight).toList(), height: 8),
        ] else ...[
          Text(
            plan.reached
                ? 'Target reached · ${money(plan.target)}'
                : '${money(plan.invested)} of ${money(plan.target)} · ${money(plan.perPeriod)}/${pot.frequency.short}',
            style: const TextStyle(fontSize: 13, color: PColors.slate),
          ),
          const SizedBox(height: 12),
          AnimatedProgressBar(value: plan.progress, height: 8, background: PColors.line, color: plan.reached ? PColors.gain : PColors.blue),
        ],
      ]),
    );
  }
}

class _GoalChip extends StatelessWidget {
  final GoalTemplate t;
  const _GoalChip({required this.t});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: PCard(
          padding: const EdgeInsets.all(8),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatePotScreen(template: t))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Center(child: FloatingArt(t.art, height: 78, animate: false))),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(t.isCustom ? 'Set your own' : money(t.target).replaceAll('.00', ''), style: const TextStyle(fontSize: 12, color: PColors.slate)),
              ]),
            ),
          ]),
        ),
      );
}

class _Todo {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final bool urgent;
  final VoidCallback onTap;
  const _Todo(this.icon, this.title, this.subtitle, {required this.done, required this.onTap, this.urgent = false});
}

/// A short, friendly checklist: setup steps first, then deposits that are due.
class _ThingsToDo extends StatelessWidget {
  const _ThingsToDo();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final items = <_Todo>[];

    // Deposits due in the next 3 days, or pots behind plan.
    for (final p in s.myPots) {
      final plan = p.plan(now);
      if (plan == null || plan.reached || plan.overdue) continue;
      final daysToDue = plan.nextDue.difference(now).inDays;
      if (p.invested <= 0) {
        items.add(_Todo(Icons.savings_rounded, 'Fund ${p.name}', 'Your plan starts with the first deposit',
            done: false, urgent: true, onTap: () => showAddDeposit(context, p)));
      } else if (plan.delta < -0.5 || daysToDue <= 3) {
        items.add(_Todo(
          Icons.savings_rounded,
          'Add ${money(plan.perPeriod)} to ${p.name}',
          plan.delta < -0.5 ? '${money(-plan.delta)} behind plan' : (daysToDue <= 0 ? 'Due today' : 'Due in $daysToDue ${daysToDue == 1 ? 'day' : 'days'}'),
          done: false,
          urgent: plan.delta < -0.5,
          onTap: () => showAddDeposit(context, p),
        ));
      }
      if (items.length >= 2) break;
    }

    final setup = <_Todo>[
      _Todo(Icons.account_balance_wallet_rounded, 'Get your Base wallet', 'Free, takes a second', done: s.address != null, onTap: () => Shell.goTo(context, 3)),
      _Todo(Icons.flag_rounded, 'Start your first goal', 'Rent, phone, japa or your own', done: s.myPots.isNotEmpty,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePotScreen()))),
      _Todo(Icons.add_card_rounded, 'Add money', 'Card or bank, arrives as USDC', done: s.balance > 0,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMoneyScreen()))),
      if (s.myPots.isNotEmpty)
        _Todo(Icons.ios_share_rounded, 'Share a pot', 'Friends keep you on track', done: s.sharedOnce, onTap: () => showSharePot(context, s.myPots.first)),
    ];
    final doneCount = setup.where((t) => t.done).length;
    final open = [...items, ...setup.where((t) => !t.done)];
    if (open.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Things to do', style: display(18, weight: FontWeight.w700)),
            const Spacer(),
            Text('$doneCount of ${setup.length} set up', style: const TextStyle(fontSize: 12, color: PColors.slate, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          AnimatedProgressBar(value: setup.isEmpty ? 1 : doneCount / setup.length, height: 6, color: PColors.gain, background: PColors.line),
          const SizedBox(height: 6),
          for (final t in open.take(4))
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: t.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: t.urgent ? PColors.clayTint : PColors.blueTint, borderRadius: BorderRadius.circular(12)),
                    child: Icon(t.icon, size: 20, color: t.urgent ? PColors.clay : PColors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(t.subtitle, style: TextStyle(fontSize: 12, color: t.urgent ? PColors.clay : PColors.slate)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: PColors.slate),
                ]),
              ),
            ),
        ]),
      ),
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
