import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

/// How often the saver plans to add money to a pot.
enum Frequency { weekly, monthly }

extension FrequencyX on Frequency {
  String get label => this == Frequency.weekly ? 'Weekly' : 'Monthly';
  String get per => this == Frequency.weekly ? 'week' : 'month';
  String get short => this == Frequency.weekly ? 'wk' : 'mo';
}

/// A ready-made savings goal, PiggyVest style: what it's for, a sensible
/// starting target and timeline, and the stock mix that suits that horizon.
class GoalTemplate {
  final String id;
  final String title;
  final String blurb;
  final IconData icon;
  final double target; // USD
  final int months; // 0 = special date rule (see dateFrom)
  final Goal style;
  final Color tint;
  const GoalTemplate({
    required this.id,
    required this.title,
    required this.blurb,
    required this.icon,
    required this.target,
    required this.months,
    required this.style,
    required this.tint,
  });

  /// Suggested target date from [now].
  DateTime dateFrom(DateTime now) {
    if (id == 'detty') {
      // 1 December, at least two months away.
      var d = DateTime(now.year, 12, 1);
      if (d.difference(now).inDays < 60) d = DateTime(now.year + 1, 12, 1);
      return d;
    }
    return addMonths(now, months);
  }

  bool get isCustom => id == 'custom';

  /// Flat illustration in assets/illustrations/.
  String get art => 'assets/illustrations/goal_$id.svg';
}

const goalTemplates = <GoalTemplate>[
  GoalTemplate(id: 'rent', title: 'House rent', blurb: 'Have next year’s rent ready before it’s due.', icon: Icons.home_rounded, target: 400, months: 6, style: Goal.income, tint: Color(0xFFEAF0FF)),
  GoalTemplate(id: 'emergency', title: 'Emergency fund', blurb: 'A cushion for the months nobody plans for.', icon: Icons.health_and_safety_outlined, target: 500, months: 10, style: Goal.income, tint: Color(0xFFE8F8EF)),
  GoalTemplate(id: 'phone', title: 'New phone', blurb: 'Buy it in full, no instalments.', icon: Icons.smartphone_rounded, target: 300, months: 4, style: Goal.wealth, tint: Color(0xFFF3F6FC)),
  GoalTemplate(id: 'school', title: 'School fees', blurb: 'Fees, books and the extras.', icon: Icons.school_outlined, target: 600, months: 8, style: Goal.wealth, tint: Color(0xFFFFF4EE)),
  GoalTemplate(id: 'laptop', title: 'Laptop', blurb: 'The machine for your next level.', icon: Icons.laptop_mac_rounded, target: 800, months: 6, style: Goal.wealth, tint: Color(0xFFF3F6FC)),
  GoalTemplate(id: 'japa', title: 'Japa fund', blurb: 'Visa, flights and your first months abroad.', icon: Icons.flight_takeoff_rounded, target: 2000, months: 18, style: Goal.longTerm, tint: Color(0xFFEAF0FF)),
  GoalTemplate(id: 'detty', title: 'Detty December', blurb: 'Enjoy December without January regrets.', icon: Icons.celebration_outlined, target: 300, months: 0, style: Goal.wealth, tint: Color(0xFFFFF4EE)),
  GoalTemplate(id: 'custom', title: 'Your own goal', blurb: 'Name it, set the number and the date.', icon: Icons.edit_rounded, target: 100, months: 6, style: Goal.wealth, tint: Color(0xFFFBF6EE)),
];

GoalTemplate? templateById(String? id) {
  for (final t in goalTemplates) {
    if (t.id == id) return t;
  }
  return null;
}

/// Same day, [n] months later (clamped to the month's last day).
DateTime addMonths(DateTime d, int n) {
  final y = d.year + ((d.month - 1 + n) ~/ 12);
  final m = (d.month - 1 + n) % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, math.min(d.day, last));
}

/// Months between two dates, rounded to the nearest whole month (min 0).
int monthsBetween(DateTime a, DateTime b) => math.max(0, (b.difference(a).inDays / 30.44).round());

/// The PiggyVest-style plan for a pot with a target. Only counts money the
/// saver adds: market moves are reported separately and never promised.
class TargetPlan {
  final double target;
  final double start; // first deposit
  final double invested; // start + later deposits
  final DateTime createdAt;
  final DateTime targetDate;
  final Frequency frequency;
  final DateTime now;

  const TargetPlan({
    required this.target,
    required this.start,
    required this.invested,
    required this.createdAt,
    required this.targetDate,
    required this.frequency,
    required this.now,
  });

  double get remaining => math.max(0.0, target - invested);
  bool get reached => invested >= target - 0.005;
  double get progress => target <= 0 ? 0 : (invested / target).clamp(0, 1).toDouble();
  int get daysLeft => math.max(0, targetDate.difference(now).inDays);
  bool get overdue => !reached && now.isAfter(targetDate);

  /// Deposits left before the target date (at least one).
  int get periodsLeft => periodsBetween(now, targetDate, frequency);

  /// What to add each week or month from now on to reach the target.
  double get perPeriod => reached ? 0 : roundUpAmount(remaining / periodsLeft);

  /// Where the saver would be today if they had followed the plan evenly.
  double get expectedNow {
    final total = targetDate.difference(createdAt).inSeconds;
    if (total <= 0) return target;
    final done = now.difference(createdAt).inSeconds.clamp(0, total);
    return start + (target - start) * done / total;
  }

  /// Positive: ahead of plan. Negative: behind.
  double get delta => invested - expectedNow;

  /// Next date a deposit is due.
  DateTime get nextDue {
    var d = createdAt;
    var i = 0;
    while (!d.isAfter(now) && i < 1000) {
      i++;
      d = frequency == Frequency.weekly ? createdAt.add(Duration(days: 7 * i)) : addMonths(createdAt, i);
    }
    return d.isAfter(targetDate) ? targetDate : d;
  }

  static int periodsBetween(DateTime from, DateTime to, Frequency f) {
    final days = to.difference(from).inDays;
    if (days <= 0) return 1;
    final n = f == Frequency.weekly ? (days / 7).ceil() : (days / 30.44).ceil();
    return math.max(1, n);
  }

  /// Plan preview before the pot exists.
  static double previewPerPeriod({required double target, required double start, required DateTime date, required Frequency frequency, required DateTime now}) {
    final left = math.max(0.0, target - start);
    if (left <= 0) return 0;
    return roundUpAmount(left / periodsBetween(now, date, frequency));
  }

  /// Round up to whole dollars from $10, otherwise to cents.
  static double roundUpAmount(double v) {
    if (v <= 0) return 0;
    if (v >= 10) return v.ceilToDouble();
    return (v * 100).ceilToDouble() / 100;
  }
}
