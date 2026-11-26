import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../targets.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/stock_widgets.dart';
import 'add_money_screen.dart';

class PotDetailScreen extends StatelessWidget {
  final Pot pot;
  final bool justCreated;
  const PotDetailScreen({super.key, required this.pot, this.justCreated = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    // Use the latest copy (deposits update it).
    final p = s.myPots.firstWhere((x) => x.id == pot.id, orElse: () => pot);
    final prices = s.stocks.priceMap();
    final v = p.valueNow(prices);
    final gain = p.marketGain(prices);
    final ch = p.invested > 0 ? gain / p.invested * 100 : 0.0;
    final plan = p.plan();
    return Scaffold(
      appBar: AppBar(title: Text(p.name), actions: [
        PopupMenuButton<String>(
          tooltip: 'More',
          onSelected: (k) async {
            if (k != 'delete') return;
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Delete this pot?'),
                content: const Text('This removes the plan from your account. It can’t be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: PColors.loss))),
                ],
              ),
            );
            if (ok == true) {
              await s.deletePot(p.id);
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete pot'))],
        ),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
            if (justCreated)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFE8F8EF), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, color: PColors.gain),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(plan != null ? 'Pot started. Add ${money(plan.perPeriod)} every ${p.frequency.per} to stay on track.' : 'Pot saved. You can track it here any time.',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            if (plan != null) ...[
              _TargetCard(pot: p, plan: plan, gain: gain),
              const SizedBox(height: 12),
              ..._guardianOnPlan(p, plan, gain).map((n) => Padding(padding: const EdgeInsets.only(bottom: 8), child: GuardianNote(n))),
              const SizedBox(height: 6),
            ],
            PCard(
              child: Row(children: [
                PotDonut(weights: p.allocations.map((a) => a.weight).toList(), size: 110, stroke: 16),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Value today (estimate)', style: TextStyle(color: PColors.slate, fontSize: 13)),
                    Text(money(v), style: display(28)),
                    const SizedBox(height: 4),
                    Text('${pct(ch)} from the market', style: TextStyle(fontWeight: FontWeight.w600, color: ch >= 0 ? PColors.gain : PColors.loss)),
                    const SizedBox(height: 6),
                    Text('You put in ${money(p.invested)} · ${p.goal.label} mix', style: const TextStyle(color: PColors.slate, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            Text('Holdings', style: display(20, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            PCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(children: [
                for (var i = 0; i < p.allocations.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      StockLogo(url: p.allocations[i].logo ?? '', fallback: p.allocations[i].name, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.allocations[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(p.allocations[i].reason, style: const TextStyle(fontSize: 12, color: PColors.slate)),
                        ]),
                      ),
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: PColors.chart[i % PColors.chart.length], borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Text('${p.allocations[i].weight.round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            for (final r in p.risks) Padding(padding: const EdgeInsets.only(bottom: 8), child: GuardianNote(r)),
            if (p.contributions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Deposits', style: display(20, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              PCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(children: [
                  for (final c in p.contributions.reversed.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.south_west_rounded, size: 18, color: PColors.gain),
                        const SizedBox(width: 10),
                        Expanded(child: Text(DateFormat('EEE d MMM, HH:mm').format(c.at))),
                        Text('+${money(c.amount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.flag_outlined, size: 18, color: PColors.slate),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Started ${DateFormat('d MMM yyyy').format(p.createdAt)}', style: const TextStyle(color: PColors.slate))),
                      Text(money(p.amount), style: const TextStyle(color: PColors.slate)),
                    ]),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            PCard(
              color: PColors.blueTint,
              child: Row(children: [
                const Icon(Icons.verified_outlined, color: PColors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(p.txHash == null ? 'Not yet recorded on Base. This unlocks when the pot contract is deployed.' : 'Recorded on Base · ${p.txHash!.substring(0, 10)}…',
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            const Text('Value is an estimate from reference prices on the day you started and today. $disclaimer', style: TextStyle(fontSize: 12, color: PColors.slate)),
          ]),
        ),
      ),
    );
  }

  /// The Guardian's take on the plan: honest about the market, practical about the gap.
  static List<String> _guardianOnPlan(Pot p, TargetPlan plan, double gain) {
    final notes = <String>[];
    if (plan.reached) {
      notes.add('You’ve reached your target with what you put in. If you need the money soon, consider moving it out of stocks so a dip can’t take it back.');
      return notes;
    }
    if (plan.overdue) {
      notes.add('The target date has passed and you’re ${money(plan.remaining)} short. Pick a new date or add the rest when you can.');
      return notes;
    }
    if (plan.delta < -0.5) {
      final behind = -plan.delta;
      notes.add('You’re ${money(behind)} behind plan. Adding ${money(plan.perPeriod)} every ${p.frequency.per} from now still gets you there by ${DateFormat('d MMM').format(plan.targetDate)}.');
    }
    if (gain < 0 && -gain >= p.invested * 0.03) {
      notes.add('The market is down ${money(-gain)} on this pot. That’s normal for stocks. Your plan only counts what you add, so keep going; prices may recover, but there’s no guarantee.');
    }
    if (plan.daysLeft <= 90 && (p.goal == Goal.tech || p.goal == Goal.longTerm)) {
      notes.add('Your date is close and this mix swings a lot. Consider a steadier mix for the last stretch.');
    }
    return notes;
  }
}

class _TargetCard extends StatelessWidget {
  final Pot pot;
  final TargetPlan plan;
  final double gain;
  const _TargetCard({required this.pot, required this.plan, required this.gain});

  @override
  Widget build(BuildContext context) {
    final tpl = templateById(pot.templateId);
    final status = plan.reached
        ? ('Target reached', PColors.gain)
        : plan.overdue
            ? ('Date passed', PColors.loss)
            : plan.delta >= plan.perPeriod * 0.5 && plan.delta > 0.5
                ? ('${money(plan.delta)} ahead', PColors.gain)
                : plan.delta < -0.5
                    ? ('${money(-plan.delta)} behind', PColors.clay)
                    : ('On track', PColors.gain);
    return PCard(
      color: PColors.navy,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(tpl?.icon ?? Icons.flag_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Target · ${DateFormat('d MMM yyyy').format(plan.targetDate)}', style: const TextStyle(color: Color(0xFFA8B6D4), fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: status.$2.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
            child: Text(status.$1, style: TextStyle(color: status.$2 == PColors.clay ? const Color(0xFFFFB896) : const Color(0xFF7FE0B0), fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: money(plan.invested), style: display(30, color: Colors.white)),
            TextSpan(text: '  of ${money(plan.target)}', style: const TextStyle(color: Color(0xFFC9D6F2), fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: plan.progress, minHeight: 10, backgroundColor: const Color(0xFF233457), color: PColors.midBlue),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('${(plan.progress * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(plan.reached ? 'Done' : '${money(plan.remaining)} to go · ${plan.daysLeft} days left', style: const TextStyle(color: Color(0xFFC9D6F2), fontSize: 13)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Stat(label: 'You added', value: money(plan.invested))),
          Expanded(child: _Stat(label: 'Market', value: '${gain >= 0 ? '+' : '−'}${money(gain.abs())}', color: gain >= 0 ? const Color(0xFF7FE0B0) : const Color(0xFFFF9C9C))),
          Expanded(child: _Stat(label: plan.reached ? 'Status' : 'Next deposit', value: plan.reached ? 'Reached' : DateFormat('EEE d MMM').format(plan.nextDue))),
        ]),
        if (!plan.reached) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: PColors.navy),
              onPressed: () => showAddDeposit(context, pot),
              icon: const Icon(Icons.add_rounded),
              label: Text('Add ${money(plan.perPeriod)} this ${pot.frequency.per}'),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFFA8B6D4), fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
      ]);
}

/// Bottom sheet to record a deposit into a pot.
Future<void> showAddDeposit(BuildContext context, Pot pot) async {
  final plan = pot.plan();
  final suggested = plan?.perPeriod ?? 0;
  final ctl = TextEditingController(text: suggested > 0 ? suggested.toStringAsFixed(suggested == suggested.roundToDouble() ? 0 : 2) : '');
  final added = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add to ${pot.name}', style: display(22, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          plan == null ? 'Record money you put into this pot.' : 'Your plan says ${money(suggested)} this ${pot.frequency.per}. Add more to get ahead.',
          style: const TextStyle(color: PColors.slate),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?'))],
          style: display(28),
          decoration: const InputDecoration(prefixText: '\$ ', labelText: 'Amount'),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final v in {if (suggested > 0) suggested, 10.0, 25.0, 50.0, 100.0})
            ActionChip(label: Text(money(v).replaceAll('.00', '')), onPressed: () => ctl.text = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final v = double.tryParse(ctl.text) ?? 0;
              if (v >= 1) Navigator.pop(c, v);
            },
            child: const Text('Record deposit'),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMoneyScreen()));
            },
            child: const Text('Need funds? Add money with card or bank'),
          ),
        ),
      ]),
    ),
  );
  if (added == null || !context.mounted) return;
  try {
    await context.read<AppState>().addContribution(pot, added);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${money(added)} added to ${pot.name}.')));
    }
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t save the deposit. Check your connection.')));
  }
}
