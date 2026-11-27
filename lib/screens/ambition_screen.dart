import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ambition.dart';
import '../targets.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/stock_widgets.dart';
import 'create_pot_screen.dart';

/// "What will it take?" — the starting point: an ambition, worked backwards.
class AmbitionScreen extends StatefulWidget {
  const AmbitionScreen({super.key});
  @override
  State<AmbitionScreen> createState() => _AmbitionScreenState();
}

class _AmbitionScreenState extends State<AmbitionScreen> {
  AmbitionKind _kind = AmbitionKind.amount;
  double _value = 100000;
  int _years = 10;
  double _start = 500;
  bool _today = true;
  int _pick = 1; // Balanced
  double? _canDo; // what the user can put in each month
  final _valueCtl = TextEditingController(text: '100000');
  final _startCtl = TextEditingController(text: '500');
  final _canCtl = TextEditingController();

  @override
  void dispose() {
    _valueCtl.dispose();
    _startCtl.dispose();
    _canCtl.dispose();
    super.dispose();
  }

  Ambition get _a => Ambition(kind: _kind, value: _value, years: _years, start: _start, todaysMoney: _today);

  void _setValue(double v) => setState(() {
        _value = v;
        _valueCtl.text = v.toStringAsFixed(0);
      });

  String _short(double v) {
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(v % 1e6 == 0 ? 0 : 1)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(v % 1e3 == 0 ? 0 : 1)}k';
    return '\$${v.toStringAsFixed(0)}';
  }

  void _build() {
    final a = _a;
    final sc = scenarios[_pick];
    final monthly = TargetPlan.roundUpAmount(a.monthlyNeeded(sc.annual));
    final paidIn = a.start + monthly * a.years * 12;
    final name = _kind == AmbitionKind.amount ? '${_short(_value)} in $_years years' : '${_short(_value)}/mo income';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreatePotScreen(
        prefill: PotPrefill(
          name: name,
          target: paidIn,
          date: addMonths(DateTime.now(), _years * 12),
          frequency: Frequency.monthly,
          start: _start,
          goal: sc.style,
          context: a.brief(sc, monthly),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final needs = [for (final sc in scenarios) a.monthlyNeeded(sc.annual)];
    final sc = scenarios[_pick];
    final monthly = needs[_pick];
    final path = a.path(sc.annual, monthly);
    final canYears = _canDo == null ? null : a.yearsWith(_canDo!, sc.annual);
    return Scaffold(
      appBar: AppBar(title: const Text('What will it take?')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
            Text('Name your ambition.\nWe’ll do the maths.', style: display(30)),
            const SizedBox(height: 16),
            SegmentedButton<AmbitionKind>(
              segments: const [
                ButtonSegment(value: AmbitionKind.amount, label: Text('Build an amount'), icon: Icon(Icons.savings_outlined)),
                ButtonSegment(value: AmbitionKind.income, label: Text('Monthly income'), icon: Icon(Icons.payments_outlined)),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() {
                _kind = v.first;
                _setValue(_kind == AmbitionKind.amount ? 100000 : 2000);
              }),
            ),
            const SizedBox(height: 14),
            PCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _valueCtl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: display(30),
                  decoration: InputDecoration(
                    labelText: _kind == AmbitionKind.amount ? 'I want to build' : 'I want to earn each month',
                    prefixText: '\$ ',
                    suffixText: _kind == AmbitionKind.income ? '/month' : null,
                  ),
                  onChanged: (v) => setState(() => _value = double.tryParse(v) ?? 0),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final v in _kind == AmbitionKind.amount ? [10000.0, 50000.0, 100000.0, 1000000.0] : [500.0, 2000.0, 5000.0])
                    ChoiceChip(label: Text(_short(v)), selected: _value == v, showCheckmark: false, onSelected: (_) => _setValue(v)),
                ]),
                const SizedBox(height: 18),
                Text('In $_years years', style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(value: _years.toDouble(), min: 1, max: 30, divisions: 29, label: '$_years years', onChanged: (v) => setState(() => _years = v.round())),
                TextField(
                  controller: _startCtl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Starting with', prefixText: '\$ '),
                  onChanged: (v) => setState(() => _start = double.tryParse(v) ?? 0),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _today,
                  onChanged: (v) => setState(() => _today = v),
                  title: const Text('In today’s money', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_today ? 'Adjusted for 3% yearly inflation: you’ll need ${money(a.targetNominal)} then.' : 'Not adjusted for inflation.'),
                ),
                if (_kind == AmbitionKind.income)
                  Text('To draw ${money(_value)} a month at a 4% yearly withdrawal, you need about ${money(a.targetToday)} invested.',
                      style: const TextStyle(fontSize: 13, color: PColors.slate, height: 1.4)),
              ]),
            ),
            const SizedBox(height: 18),
            Text('What it takes each month', style: display(20, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              for (var i = 0; i < scenarios.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _ScenarioCard(sc: scenarios[i], monthly: needs[i], selected: _pick == i, onTap: () => setState(() => _pick = i))),
              ],
            ]),
            const SizedBox(height: 16),
            PCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${sc.name} path', style: const TextStyle(fontWeight: FontWeight.w700))),
                  const _Legend(color: PColors.blue, label: 'Projected value'),
                  const SizedBox(width: 12),
                  const _Legend(color: PColors.clay, label: 'You put in'),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: LineChart(LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [for (var i = 0; i < path.length; i++) FlSpot(i.toDouble(), path[i].$1)],
                        isCurved: true,
                        color: PColors.blue,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: PColors.blue.withValues(alpha: 0.08)),
                      ),
                      LineChartBarData(
                        spots: [for (var i = 0; i < path.length; i++) FlSpot(i.toDouble(), path[i].$2)],
                        color: PColors.clay,
                        barWidth: 2,
                        dashArray: [6, 4],
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  )),
                ),
                const SizedBox(height: 10),
                Text(
                  monthly <= 0
                      ? 'Your starting amount could get there on its own at ${(sc.annual * 100).round()}% a year.'
                      : 'Put in ${money(path.last.$2)} over $_years years. At ${(sc.annual * 100).round()}% a year it could grow to ${money(path.last.$1)}.',
                  style: const TextStyle(fontSize: 13, color: PColors.slate, height: 1.4),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            PCard(
              color: PColors.cream,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reality check', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: _canCtl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'What can you put in each month?', prefixText: '\$ '),
                  onChanged: (v) => setState(() => _canDo = double.tryParse(v)),
                ),
                if (_canDo != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    canYears == null
                        ? 'At ${money(_canDo!)} a month this would take more than 60 years on the ${sc.name.toLowerCase()} path. Try a smaller ambition or a longer timeline.'
                        : 'At ${money(_canDo!)} a month, the ${sc.name.toLowerCase()} path gets there in about ${canYears.toStringAsFixed(1)} years.',
                    style: const TextStyle(height: 1.4),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 14),
            const GuardianNote(
              'Returns here are assumptions, not forecasts. Markets can fall for years, and the order of good and bad years changes the result. Use this to plan, then review it every few months.',
              title: 'How to read this',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _value > 0 && _years > 0 ? _build : null,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Build my strategy with the Guardian'),
            ),
            const SizedBox(height: 8),
            const Text(disclaimer, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: PColors.slate)),
          ]),
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final Scenario sc;
  final double monthly;
  final bool selected;
  final VoidCallback onTap;
  const _ScenarioCard({required this.sc, required this.monthly, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? PColors.navy : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? PColors.navy : PColors.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sc.name, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : PColors.navy)),
              Text('${(sc.annual * 100).round()}% a year', style: TextStyle(fontSize: 12, color: selected ? const Color(0xFFA8B6D4) : PColors.slate)),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(monthly <= 0 ? '\$0' : money(monthly).replaceAll('.00', ''), style: display(22, color: selected ? Colors.white : PColors.navy)),
              ),
              Text('a month', style: TextStyle(fontSize: 12, color: selected ? const Color(0xFFA8B6D4) : PColors.slate)),
            ]),
          ),
        ),
      );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: PColors.slate)),
      ]);
}
