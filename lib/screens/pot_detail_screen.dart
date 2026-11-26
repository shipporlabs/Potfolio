import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/stock_widgets.dart';

class PotDetailScreen extends StatelessWidget {
  final Pot pot;
  final bool justCreated;
  const PotDetailScreen({super.key, required this.pot, this.justCreated = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final prices = s.stocks.priceMap();
    final v = pot.valueWith(prices);
    final ch = pot.amount > 0 ? (v - pot.amount) / pot.amount * 100 : 0.0;
    return Scaffold(
      appBar: AppBar(title: Text(pot.name), actions: [
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
              await s.deletePot(pot.id);
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete pot'))],
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        if (justCreated)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFE8F8EF), borderRadius: BorderRadius.circular(16)),
            child: const Row(children: [
              Icon(Icons.check_circle_rounded, color: PColors.gain),
              SizedBox(width: 10),
              Expanded(child: Text('Pot saved. You can track it here any time.', style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
        PCard(
          child: Row(children: [
            PotDonut(weights: pot.allocations.map((a) => a.weight).toList(), size: 120, stroke: 18),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Current value', style: TextStyle(color: PColors.slate, fontSize: 13)),
                Text(money(v), style: display(30)),
                const SizedBox(height: 4),
                Text('${pct(ch)} since ${DateFormat('d MMM').format(pot.createdAt)}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: ch >= 0 ? PColors.gain : PColors.loss)),
                const SizedBox(height: 6),
                Text('Plan: ${money(pot.amount)} · ${pot.goal.label}', style: const TextStyle(color: PColors.slate, fontSize: 13)),
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
            for (var i = 0; i < pot.allocations.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  StockLogo(url: pot.allocations[i].logo ?? '', fallback: pot.allocations[i].name, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(pot.allocations[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(pot.allocations[i].reason, style: const TextStyle(fontSize: 12, color: PColors.slate)),
                    ]),
                  ),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: PColors.chart[i % PColors.chart.length], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text('${pot.allocations[i].weight.round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        for (final r in pot.risks) Padding(padding: const EdgeInsets.only(bottom: 8), child: GuardianNote(r)),
        const SizedBox(height: 8),
        PCard(
          color: PColors.blueTint,
          child: Row(children: [
            const Icon(Icons.verified_outlined, color: PColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(pot.txHash == null ? 'Not yet recorded on Base. This unlocks when the pot contract is deployed.' : 'Recorded on Base · ${pot.txHash!.substring(0, 10)}…',
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('Value uses reference prices from the day you created the pot and today. $disclaimer',
            style: TextStyle(fontSize: 12, color: PColors.slate)),
      ]),
    );
  }
}
