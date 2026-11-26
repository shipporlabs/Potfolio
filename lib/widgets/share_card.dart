import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models.dart';
import '../targets.dart';
import '../theme.dart';
import 'brand.dart';
import 'stock_widgets.dart';

/// The shareable picture of a pot: brand, goal, progress and mix.
/// Amounts are hidden unless [showAmounts] is on, so people can share
/// their plan without sharing their balance.
class PotShareCard extends StatelessWidget {
  final Pot pot;
  final bool showAmounts;
  final double? valueNow;
  const PotShareCard({super.key, required this.pot, required this.showAmounts, this.valueNow});

  static const width = 360.0;

  @override
  Widget build(BuildContext context) {
    final plan = pot.plan();
    final tpl = templateById(pot.templateId);
    final top = [...pot.allocations]..sort((a, b) => b.weight.compareTo(a.weight));
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: BoxDecoration(
          color: PColors.navy,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Lockup(markSize: 24, textColor: Colors.white, palette: MarkPalette.onNavy, background: PColors.navy),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
              child: Text(pot.goal.label, style: const TextStyle(color: Color(0xFFC9D6F2), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pot.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: display(24, color: Colors.white, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                if (plan != null)
                  Text(
                    showAmounts
                        ? '${money(plan.target)} by ${DateFormat('MMM yyyy').format(plan.targetDate)}'
                        : 'Goal for ${DateFormat('MMM yyyy').format(plan.targetDate)}',
                    style: const TextStyle(color: Color(0xFFC9D6F2), fontSize: 14),
                  )
                else if (showAmounts)
                  Text('${money(valueNow ?? pot.invested)} today', style: const TextStyle(color: Color(0xFFC9D6F2), fontSize: 14)),
              ]),
            ),
            if (tpl != null) SvgPicture.asset(tpl.art, height: 72),
          ]),
          if (plan != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              Text('${(plan.progress * 100).round()}%', style: display(34, color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.reached
                      ? 'Target reached'
                      : showAmounts
                          ? '${money(plan.invested)} saved · ${money(plan.perPeriod)} a ${pot.frequency.per}'
                          : 'of the way there · saving ${pot.frequency.label.toLowerCase()}',
                  style: const TextStyle(color: Color(0xFFC9D6F2), fontSize: 13, height: 1.3),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: plan.progress, minHeight: 10, backgroundColor: const Color(0xFF233457), color: plan.reached ? const Color(0xFF3DDC97) : PColors.midBlue),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('The mix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PColors.slate)),
              const SizedBox(height: 8),
              AllocationBar(weights: pot.allocations.map((a) => a.weight).toList(), height: 8),
              const SizedBox(height: 8),
              for (var i = 0; i < top.length && i < 4; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    StockLogo(url: top[i].logo ?? '', fallback: top[i].name, size: 26),
                    const SizedBox(width: 10),
                    Expanded(child: Text(top[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PColors.navy))),
                    Text('${top[i].weight.round()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: PColors.navy)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Text('Built with the AI Guardian on Base', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
            ),
            Text(Uri.parse(AppConfig.siteUrl).host, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}
