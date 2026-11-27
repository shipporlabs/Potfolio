import 'dart:math' as math;

import 'models.dart';

/// "What will it take?" — works backwards from an ambition to the monthly
/// contribution needed under different return assumptions. Pure maths, no
/// promises: returns are assumptions, not forecasts.
enum AmbitionKind { amount, income }

class Scenario {
  final String name;
  final String blurb;
  final double annual; // assumed yearly return, e.g. 0.07
  final Goal style; // Guardian mix that fits
  const Scenario(this.name, this.blurb, this.annual, this.style);
}

const scenarios = [
  Scenario('Steady', 'Mostly large, dividend-paying companies', 0.05, Goal.income),
  Scenario('Balanced', 'A spread across sectors', 0.07, Goal.wealth),
  Scenario('Growth', 'Leans on fast-growing tech', 0.09, Goal.tech),
];

const inflation = 0.03; // used when showing targets in today's money
const withdrawalRate = 0.04; // for passive-income ambitions

class Ambition {
  final AmbitionKind kind;
  final double value; // target amount, or monthly income
  final int years;
  final double start;
  final bool todaysMoney;
  const Ambition({required this.kind, required this.value, required this.years, required this.start, this.todaysMoney = true});

  /// The portfolio size needed, in future dollars.
  double get targetNominal {
    final base = kind == AmbitionKind.amount ? value : value * 12 / withdrawalRate;
    return todaysMoney ? base * math.pow(1 + inflation, years) : base;
  }

  /// Portfolio size in today's money (what the user typed, for income goals the capital needed).
  double get targetToday => kind == AmbitionKind.amount ? value : value * 12 / withdrawalRate;

  /// Monthly contribution needed at [annual] return. 0 if the start alone gets there.
  double monthlyNeeded(double annual) {
    final r = annual / 12, n = years * 12;
    final g = math.pow(1 + r, n).toDouble();
    final gap = targetNominal - start * g;
    if (gap <= 0) return 0;
    return gap * r / (g - 1);
  }

  /// Years to reach the target with [monthly] at [annual], or null if > 60 years.
  double? yearsWith(double monthly, double annual) {
    final r = annual / 12;
    var v = start;
    for (var m = 1; m <= 720; m++) {
      v = v * (1 + r) + monthly;
      final t = todaysMoney ? (kind == AmbitionKind.amount ? value : value * 12 / withdrawalRate) * math.pow(1 + inflation, m / 12) : targetNominal;
      if (v >= t) return m / 12;
    }
    return null;
  }

  /// Year-by-year projected value and total contributed, for the chart.
  List<(double value, double paidIn)> path(double annual, double monthly) {
    final r = annual / 12;
    var v = start, paid = start;
    final out = <(double, double)>[(v, paid)];
    for (var m = 1; m <= years * 12; m++) {
      v = v * (1 + r) + monthly;
      paid += monthly;
      if (m % 12 == 0) out.add((v, paid));
    }
    return out;
  }

  /// A short brief for the AI Guardian.
  String brief(Scenario s, double monthly) =>
      '${kind == AmbitionKind.amount ? 'Build \$${value.round()}' : 'Earn \$${value.round()} a month in passive income'} in $years years, '
      'starting with \$${start.round()} and adding about \$${monthly.round()} a month. Risk preference: ${s.name.toLowerCase()} (${s.blurb.toLowerCase()}).';
}
