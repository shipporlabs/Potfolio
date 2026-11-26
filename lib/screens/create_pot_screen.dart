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
import 'pot_detail_screen.dart';

/// Four calm steps, PiggyVest style:
/// what you're saving for → target, date and how often → Guardian mix → review.
class CreatePotScreen extends StatefulWidget {
  final Stock? preselect;
  final GoalTemplate? template;
  const CreatePotScreen({super.key, this.preselect, this.template});
  @override
  State<CreatePotScreen> createState() => _CreatePotScreenState();
}

class _CreatePotScreenState extends State<CreatePotScreen> {
  int _step = 0;
  GoalTemplate _tpl = goalTemplates.first;
  Goal _goal = goalTemplates.first.style;
  double _target = goalTemplates.first.target;
  late DateTime _date = goalTemplates.first.dateFrom(DateTime.now());
  Frequency _freq = Frequency.weekly;
  double _start = 25;
  final _name = TextEditingController();
  final _targetCtl = TextEditingController();
  final _startCtl = TextEditingController();
  GuardianProposal? _proposal;
  List<Allocation> _allocs = [];
  List<String> _risks = [];
  List<Stock> _universe = [];
  bool _busy = false;

  static final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _pick(widget.template!, silent: true);
      _step = 1;
    } else {
      _syncFields();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _targetCtl.dispose();
    _startCtl.dispose();
    super.dispose();
  }

  void _syncFields() {
    _targetCtl.text = _target.toStringAsFixed(0);
    _startCtl.text = _start == _start.roundToDouble() ? _start.toStringAsFixed(0) : _start.toStringAsFixed(2);
  }

  void _pick(GoalTemplate t, {bool silent = false}) {
    void apply() {
      _tpl = t;
      _goal = t.style;
      _target = t.target;
      _date = t.dateFrom(DateTime.now());
      _start = (t.target * 0.05).clamp(5, 100).roundToDouble();
      _name.text = t.isCustom ? '' : t.title;
      _syncFields();
    }

    if (silent) {
      apply();
    } else {
      setState(apply);
    }
  }

  int get _months => monthsBetween(DateTime.now(), _date);

  double get _perPeriod => TargetPlan.previewPerPeriod(target: _target, start: _start, date: _date, frequency: _freq, now: DateTime.now());

  String? get _targetError {
    if (_target < 10) return 'Set a target of at least \$10.';
    if (_start < 1) return 'Start with at least \$1.';
    if (_start >= _target) return 'Your first deposit already covers the target.';
    if (_date.difference(DateTime.now()).inDays < 28) return 'Pick a date at least 4 weeks away.';
    return null;
  }

  /// Short goals get a steadier mix and an honest note about stock swings.
  List<String> _horizonNotes() {
    final notes = <String>[];
    if (_months < 12) {
      notes.add('Your date is ${_months <= 1 ? 'about a month' : '$_months months'} away. Stocks can fall in the short run, so this pot leans on steadier names and you may need to top up if the market dips.');
    }
    if (_months < 6 && _goal == Goal.tech) {
      notes.add('An all-tech mix swings the most. For a goal this close, a balanced or income mix is usually calmer.');
    }
    return notes;
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _step = 2;
    });
    final s = context.read<AppState>();
    _universe = await s.stocks.list(Market.us);
    final p = await s.guardian.propose(_goal, _start, _universe);
    var allocs = p.allocations;
    final pre = widget.preselect;
    if (pre != null && !allocs.any((a) => a.symbol == pre.symbol) && allocs.isNotEmpty) {
      allocs = [Allocation(symbol: pre.symbol, name: pre.name, weight: allocs.last.weight, reason: 'You picked this one', entryPrice: pre.price, logo: pre.logo), ...allocs.take(allocs.length - 1)];
    }
    if (!mounted) return;
    setState(() {
      _proposal = p;
      _allocs = allocs;
      _risks = [..._horizonNotes(), ...p.risks];
      _busy = false;
    });
  }

  double get _total => _allocs.fold(0, (s, a) => s + a.weight);

  void _setWeight(int i, double w) {
    setState(() {
      _allocs[i] = _allocs[i].withWeight(w.roundToDouble());
      _risks = [..._horizonNotes(), ...context.read<AppState>().guardian.review(_allocs, _universe)];
    });
  }

  String get _potName => _name.text.trim().isEmpty ? (_tpl.isCustom ? 'My goal' : _tpl.title) : _name.text.trim();

  Future<void> _save() async {
    setState(() => _busy = true);
    final s = context.read<AppState>();
    final pot = Pot(
      id: '',
      name: _potName,
      goal: _goal,
      amount: _start,
      allocations: _allocs,
      risks: _risks,
      createdAt: DateTime.now(),
      target: _target,
      targetDate: _date,
      frequency: _freq,
      templateId: _tpl.id,
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
    final titles = ['What are you saving for?', 'Set your target', 'Your Guardian mix', 'Review your plan'];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _step == 0 || _busy ? Navigator.of(context).maybePop() : setState(() => _step = _step - 1),
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 20), children: [
                  Text(titles[_step], style: display(28)),
                  const SizedBox(height: 16),
                  if (_step == 0) ..._templateStep(),
                  if (_step == 1) ..._targetStep(),
                  if (_step == 2) ..._proposalStep(),
                  if (_step == 3) ..._reviewStep(),
                ]),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: SizedBox(width: double.infinity, child: _cta())),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _cta() {
    switch (_step) {
      case 0:
        return FilledButton(onPressed: () => setState(() => _step = 1), child: const Text('Continue'));
      case 1:
        return FilledButton.icon(
          onPressed: _targetError == null ? _generate : null,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Ask the Guardian'),
        );
      case 2:
        return FilledButton(
          onPressed: _busy || _total.round() != 100 || _allocs.isEmpty ? null : () => setState(() => _step = 3),
          child: Text(_total.round() == 100 ? 'Looks good' : 'Weights must add to 100% (now ${_total.round()}%)'),
        );
      default:
        return FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Start my pot'),
        );
    }
  }

  // ── Step 1: templates ─────────────────────────────────────────────
  List<Widget> _templateStep() => [
        const Text('Pick a goal. You can change the amount and date next.', style: TextStyle(color: PColors.slate)),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 560 ? 3 : 2;
          final w = (c.maxWidth - 12 * (cols - 1)) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final t in goalTemplates) SizedBox(width: w, child: _TemplateCard(t: t, selected: _tpl.id == t.id, onTap: () => _pick(t))),
          ]);
        }),
      ];

  // ── Step 2: target, date, frequency ───────────────────────────────
  List<Widget> _targetStep() {
    final err = _targetError;
    final now = DateTime.now();
    return [
      PCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: _tpl.tint, borderRadius: BorderRadius.circular(12)),
              child: Icon(_tpl.icon, color: PColors.navy, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _name,
                decoration: InputDecoration(labelText: 'Pot name', hintText: _tpl.isCustom ? 'e.g. Car, wedding, business' : _tpl.title),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _MoneyField(
            label: 'Target',
            controller: _targetCtl,
            onChanged: (v) => setState(() => _target = v),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final v in [100.0, 250.0, 500.0, 1000.0, 2500.0])
              ChoiceChip(
                label: Text(money(v).replaceAll('.00', '')),
                selected: _target == v,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _target = v;
                  _syncFields();
                }),
              ),
          ]),
          const SizedBox(height: 20),
          const Text('By when?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in [3, 6, 9, 12, 18, 24])
              ChoiceChip(
                label: Text('$m months'),
                selected: _months == m,
                showCheckmark: false,
                onSelected: (_) => setState(() => _date = addMonths(now, m)),
              ),
            ActionChip(
              avatar: const Icon(Icons.event_rounded, size: 18),
              label: Text(_dateFmt.format(_date)),
              onPressed: () async {
                final first = now.add(const Duration(days: 28));
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date.isBefore(first) ? first : _date,
                  firstDate: first,
                  lastDate: addMonths(now, 120),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
          ]),
          const SizedBox(height: 20),
          const Text('How often will you add money?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<Frequency>(
            segments: const [
              ButtonSegment(value: Frequency.weekly, label: Text('Weekly'), icon: Icon(Icons.calendar_view_week_rounded)),
              ButtonSegment(value: Frequency.monthly, label: Text('Monthly'), icon: Icon(Icons.calendar_month_rounded)),
            ],
            selected: {_freq},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _freq = v.first),
          ),
          const SizedBox(height: 20),
          _MoneyField(
            label: 'Start with',
            helper: 'Your first deposit. The Guardian builds the mix from this.',
            controller: _startCtl,
            onChanged: (v) => setState(() => _start = v),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      if (err != null)
        Text(err, style: const TextStyle(color: PColors.loss, fontWeight: FontWeight.w600))
      else
        _PlanPreview(
          perPeriod: _perPeriod,
          frequency: _freq,
          target: _target,
          date: _date,
          start: _start,
        ),
      const SizedBox(height: 20),
      const Text('How should the Guardian build it?', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in Goal.values)
          ChoiceChip(label: Text(g.label), selected: _goal == g, showCheckmark: false, onSelected: (_) => setState(() => _goal = g)),
      ]),
      const SizedBox(height: 8),
      Text(_goal.blurb, style: const TextStyle(fontSize: 13, color: PColors.slate)),
      for (final n in _horizonNotes()) Padding(padding: const EdgeInsets.only(top: 12), child: GuardianNote(n)),
    ];
  }

  // ── Step 3: Guardian proposal ─────────────────────────────────────
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

  // ── Step 4: review ────────────────────────────────────────────────
  List<Widget> _reviewStep() => [
        PCard(
          color: PColors.navy,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_tpl.icon, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(_potName, style: display(22, color: Colors.white, weight: FontWeight.w700))),
            ]),
            const SizedBox(height: 14),
            Text('${money(_target)} by ${_dateFmt.format(_date)}', style: display(26, color: Colors.white)),
            const SizedBox(height: 6),
            Text('Start with ${money(_start)}, then add ${money(_perPeriod)} every ${_freq.per}.',
                style: const TextStyle(color: Color(0xFFC9D6F2), height: 1.4)),
          ]),
        ),
        const SizedBox(height: 12),
        PCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_goal.label} mix', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
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
                  SizedBox(width: 72, child: Text(money(_start * _allocs[i].weight / 100), textAlign: TextAlign.right, style: const TextStyle(color: PColors.slate))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        for (final r in _risks.take(2)) Padding(padding: const EdgeInsets.only(bottom: 8), child: GuardianNote(r)),
        const SizedBox(height: 4),
        const Text('The plan counts only what you add. Market gains are a bonus on top and losses can happen, so the Guardian will tell you if you fall behind.',
            style: TextStyle(fontSize: 13, color: PColors.slate, height: 1.45)),
        const SizedBox(height: 8),
        const Text(disclaimer, style: TextStyle(fontSize: 12, color: PColors.slate)),
      ];
}

class _TemplateCard extends StatelessWidget {
  final GoalTemplate t;
  final bool selected;
  final VoidCallback onTap;
  const _TemplateCard({required this.t, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final m = monthsBetween(now, t.dateFrom(now));
    return Material(
      color: selected ? PColors.blueTint : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? PColors.blue : PColors.line, width: selected ? 1.5 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: selected ? PColors.blue : t.tint, borderRadius: BorderRadius.circular(12)),
              child: Icon(t.icon, size: 22, color: selected ? Colors.white : PColors.navy),
            ),
            const SizedBox(height: 10),
            Text(t.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(t.blurb, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: PColors.slate, height: 1.35)),
            const SizedBox(height: 8),
            Text(t.isCustom ? 'You decide' : '${money(t.target).replaceAll('.00', '')} · $m mo',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PColors.blue)),
          ]),
        ),
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  final String label;
  final String? helper;
  final TextEditingController controller;
  final ValueChanged<double> onChanged;
  const _MoneyField({required this.label, this.helper, required this.controller, required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?'))],
        style: display(26),
        decoration: InputDecoration(labelText: label, prefixText: '\$ ', helperText: helper),
        onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
      );
}

class _PlanPreview extends StatelessWidget {
  final double perPeriod, target, start;
  final Frequency frequency;
  final DateTime date;
  const _PlanPreview({required this.perPeriod, required this.frequency, required this.target, required this.date, required this.start});
  @override
  Widget build(BuildContext context) {
    final n = TargetPlan.periodsBetween(DateTime.now(), date, frequency);
    return PCard(
      color: PColors.blueTint,
      child: Row(children: [
        const Icon(Icons.flag_rounded, color: PColors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add ${money(perPeriod)} every ${frequency.per}', style: display(20, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${money(start)} now, then $n ${frequency.label.toLowerCase()} deposits, reaches ${money(target)} by ${DateFormat('d MMM yyyy').format(date)}. The plan counts only what you add; any market gain is extra.',
                style: const TextStyle(fontSize: 13, color: PColors.slate, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}
