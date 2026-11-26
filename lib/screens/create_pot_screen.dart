import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/stock_widgets.dart';
import 'pot_detail_screen.dart';

/// Four calm steps: goal → amount → Guardian proposal → review and save.
class CreatePotScreen extends StatefulWidget {
  final Stock? preselect;
  const CreatePotScreen({super.key, this.preselect});
  @override
  State<CreatePotScreen> createState() => _CreatePotScreenState();
}

class _CreatePotScreenState extends State<CreatePotScreen> {
  int _step = 0;
  Goal _goal = Goal.tech;
  double _amount = 100;
  final _name = TextEditingController();
  GuardianProposal? _proposal;
  List<Allocation> _allocs = [];
  List<String> _risks = [];
  List<Stock> _universe = [];
  bool _busy = false;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _step = 2;
    });
    final s = context.read<AppState>();
    _universe = await s.stocks.list(Market.us);
    final p = await s.guardian.propose(_goal, _amount, _universe);
    var allocs = p.allocations;
    final pre = widget.preselect;
    if (pre != null && !allocs.any((a) => a.symbol == pre.symbol) && allocs.isNotEmpty) {
      allocs = [Allocation(symbol: pre.symbol, name: pre.name, weight: allocs.last.weight, reason: 'You picked this one', entryPrice: pre.price, logo: pre.logo), ...allocs.take(allocs.length - 1)];
    }
    if (!mounted) return;
    setState(() {
      _proposal = p;
      _allocs = allocs;
      _risks = p.risks;
      _busy = false;
    });
  }

  double get _total => _allocs.fold(0, (s, a) => s + a.weight);

  void _setWeight(int i, double w) {
    setState(() {
      _allocs[i] = _allocs[i].withWeight(w.roundToDouble());
      _risks = context.read<AppState>().guardian.review(_allocs, _universe);
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final s = context.read<AppState>();
    final pot = Pot(
      id: '',
      name: _name.text.trim().isEmpty ? _goal.label : _name.text.trim(),
      goal: _goal,
      amount: _amount,
      allocations: _allocs,
      risks: _risks,
      createdAt: DateTime.now(),
    );
    try {
      final saved = await s.savePot(pot);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PotDetailScreen(pot: saved, justCreated: true)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t save the pot. Check your connection.')));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['What is this pot for?', 'How much to start?', 'Your Guardian proposal', 'Review and save'];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _step == 0 || _busy ? Navigator.of(context).maybePop() : setState(() => _step = _step == 3 ? 2 : (_step == 2 ? 1 : 0)),
        ),
        title: Text('Step ${_step + 1} of 4'),
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: (_step + 1) / 4, minHeight: 6, backgroundColor: PColors.line, color: PColors.blue),
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 20), children: [
              Text(titles[_step], style: display(28)),
              const SizedBox(height: 16),
              if (_step == 0) ..._goalStep(),
              if (_step == 1) ..._amountStep(),
              if (_step == 2) ..._proposalStep(),
              if (_step == 3) ..._reviewStep(),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: _cta()),
        ]),
      ),
    );
  }

  Widget _cta() {
    switch (_step) {
      case 0:
        return FilledButton(onPressed: () => setState(() => _step = 1), child: const Text('Continue'));
      case 1:
        return FilledButton.icon(onPressed: _amount >= 1 ? _generate : null, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Ask the Guardian'));
      case 2:
        return FilledButton(
          onPressed: _busy || _total.round() != 100 || _allocs.isEmpty ? null : () => setState(() => _step = 3),
          child: Text(_total.round() == 100 ? 'Looks good' : 'Weights must add to 100% (now ${_total.round()}%)'),
        );
      default:
        return FilledButton(onPressed: _busy ? null : _save, child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Save my pot'));
    }
  }

  List<Widget> _goalStep() => [
        for (final g in Goal.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PCard(
              color: _goal == g ? PColors.blueTint : Colors.white,
              onTap: () => setState(() => _goal = g),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: _goal == g ? PColors.blue : PColors.mist, borderRadius: BorderRadius.circular(14)),
                  child: Icon(const {Goal.wealth: Icons.savings_outlined, Goal.tech: Icons.memory_rounded, Goal.income: Icons.payments_outlined, Goal.longTerm: Icons.hourglass_bottom_rounded}[g],
                      color: _goal == g ? Colors.white : PColors.navy),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(g.blurb, style: const TextStyle(fontSize: 13, color: PColors.slate)),
                  ]),
                ),
                Icon(_goal == g ? Icons.radio_button_checked : Icons.radio_button_off, color: _goal == g ? PColors.blue : PColors.line),
              ]),
            ),
          ),
      ];

  List<Widget> _amountStep() => [
        PCard(
          child: Column(children: [
            Text(money(_amount), style: display(44)),
            Slider(value: _amount.clamp(10, 5000).toDouble(), min: 10, max: 5000, divisions: 499, onChanged: (v) => setState(() => _amount = v.roundToDouble())),
            Wrap(spacing: 8, children: [
              for (final v in [50.0, 100.0, 250.0, 500.0, 1000.0])
                ChoiceChip(label: Text(money(v).replaceAll('.00', '')), selected: _amount == v, onSelected: (_) => setState(() => _amount = v), showCheckmark: false),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(controller: _name, decoration: InputDecoration(labelText: 'Pot name (optional)', hintText: _goal.label)),
        const SizedBox(height: 12),
        const Text('This sets your plan. You fund it from your wallet when you’re ready.', style: TextStyle(color: PColors.slate, fontSize: 13)),
      ];

  List<Widget> _proposalStep() {
    if (_busy || _proposal == null) {
      return [
        const SizedBox(height: 40),
        const Center(child: PotfolioMark(size: 72, background: PColors.mist)),
        const SizedBox(height: 20),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        const Center(child: Text('The Guardian is building your mix…', style: TextStyle(color: PColors.slate))),
      ];
    }
    return [
      Row(children: [
        PotDonut(weights: _allocs.map((a) => a.weight).toList(), size: 110, stroke: 16),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Tag(_proposal!.fromAi ? 'AI Guardian' : 'Guardian rules', bg: PColors.blueTint, fg: PColors.blue),
            const SizedBox(height: 8),
            Text(_proposal!.summary, style: const TextStyle(fontSize: 14, height: 1.45)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      for (var i = 0; i < _allocs.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(children: [
              Row(children: [
                StockLogo(url: _allocs[i].logo ?? '', fallback: _allocs[i].name, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_allocs[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(_allocs[i].reason, style: const TextStyle(fontSize: 12, color: PColors.slate)),
                  ]),
                ),
                Text('${_allocs[i].weight.round()}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
              Slider(
                value: _allocs[i].weight.clamp(0, 100).toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                activeColor: PColors.chart[i % PColors.chart.length],
                label: '${_allocs[i].weight.round()}%',
                onChanged: (v) => _setWeight(i, v),
              ),
            ]),
          ),
        ),
      for (final r in _risks) Padding(padding: const EdgeInsets.only(bottom: 8), child: GuardianNote(r)),
      TextButton.icon(onPressed: _generate, icon: const Icon(Icons.refresh_rounded), label: const Text('Ask again')),
    ];
  }

  List<Widget> _reviewStep() => [
        PCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name.text.trim().isEmpty ? _goal.label : _name.text.trim(), style: display(22, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${_goal.label} · ${money(_amount)}', style: const TextStyle(color: PColors.slate)),
            const SizedBox(height: 14),
            AllocationBar(weights: _allocs.map((a) => a.weight).toList()),
            const SizedBox(height: 10),
            for (var i = 0; i < _allocs.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: PColors.chart[i % PColors.chart.length], borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_allocs[i].name)),
                  Text('${_allocs[i].weight.round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  SizedBox(width: 72, child: Text(money(_amount * _allocs[i].weight / 100), textAlign: TextAlign.right, style: const TextStyle(color: PColors.slate))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        for (final r in _risks.take(2)) Padding(padding: const EdgeInsets.only(bottom: 8), child: GuardianNote(r)),
        const SizedBox(height: 4),
        const Text('Saving records your plan to your account. Recording it on Base unlocks when the pot contract is deployed.',
            style: TextStyle(fontSize: 13, color: PColors.slate)),
        const SizedBox(height: 8),
        const Text(disclaimer, style: TextStyle(fontSize: 12, color: PColors.slate)),
      ];
}
