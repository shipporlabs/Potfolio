import '../config.dart';
import '../models.dart';
import 'api.dart';

/// The AI Guardian. Uses the Worker (Cloudflare Workers AI) when available,
/// otherwise a transparent on-device rule set. It explains and flags risk;
/// it never predicts prices or tells users to buy.
class GuardianService {
  final WorkerApi _api;
  GuardianService(this._api);

  Future<GuardianProposal> propose(Goal goal, double amount, List<Stock> universe) async {
    final pool = universe.where((s) => s.investable).toList();
    final candidates = pool.length >= 4 ? pool : universe;
    if (AppConfig.hasWorker) {
      try {
        final j = await _api.post('/guardian', {
          'goal': goal.name,
          'amount': amount,
          'universe': candidates.map((s) => {'symbol': s.symbol, 'name': s.name, 'sector': s.sector}).toList(),
        });
        final allocs = ((j['allocations'] as List?) ?? [])
            .map((e) => Allocation.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((a) => candidates.any((s) => s.symbol == a.symbol))
            .toList();
        if (allocs.length >= 3) {
          final withMeta = _attach(_normalise(allocs), candidates);
          return GuardianProposal(
            summary: (j['summary'] ?? goal.blurb).toString(),
            allocations: withMeta,
            risks: _risks(withMeta, candidates, extra: ((j['risks'] as List?) ?? []).map((e) => e is Map ? (e['message'] ?? '').toString() : e.toString()).where((e) => e.isNotEmpty).toList()),
            fromAi: true,
          );
        }
      } catch (_) {/* fall back */}
    }
    return _rules(goal, candidates);
  }

  static const _templates = {
    Goal.tech: ['tech', 'tech', 'tech', 'tech'],
    Goal.income: ['consumer', 'finance', 'consumer', 'health'],
    Goal.wealth: ['tech', 'finance', 'consumer', 'health'],
    Goal.longTerm: ['tech', 'consumer', 'finance', 'tech'],
  };
  static const _weights = [30.0, 25.0, 25.0, 20.0];
  static const _reasons = {
    'tech': 'Large tech business with room to grow',
    'consumer': 'Everyday brand with steady demand',
    'finance': 'Payments and finance add balance',
    'health': 'Healthcare tends to hold up in slowdowns',
    'energy': 'Energy adds a different driver',
    'other': 'Adds variety to the mix',
  };

  GuardianProposal _rules(Goal goal, List<Stock> pool) {
    final used = <String>{};
    final picks = <Allocation>[];
    final tmpl = _templates[goal]!;
    for (var i = 0; i < tmpl.length; i++) {
      final s = pool.firstWhere((x) => x.sector == tmpl[i] && !used.contains(x.symbol),
          orElse: () => pool.firstWhere((x) => !used.contains(x.symbol), orElse: () => pool.first));
      if (used.contains(s.symbol)) continue;
      used.add(s.symbol);
      picks.add(Allocation(symbol: s.symbol, name: s.name, weight: _weights[i], reason: _reasons[s.sector] ?? _reasons['other']!, entryPrice: s.price, logo: s.logo));
    }
    final n = _normalise(picks);
    return GuardianProposal(summary: '${n.length} stocks for ${goal.label.toLowerCase()}. ${goal.blurb}', allocations: n, risks: _risks(n, pool));
  }

  List<Allocation> _normalise(List<Allocation> a) {
    final t = a.fold<double>(0, (s, x) => s + x.weight);
    if (t <= 0) return a;
    final scaled = a.map((x) => x.withWeight((x.weight / t * 100).roundToDouble())).toList();
    final diff = 100 - scaled.fold<double>(0, (s, x) => s + x.weight);
    if (diff != 0 && scaled.isNotEmpty) scaled[0] = scaled[0].withWeight(scaled[0].weight + diff);
    return scaled;
  }

  List<Allocation> _attach(List<Allocation> a, List<Stock> pool) => a.map((x) {
        final s = pool.firstWhere((p) => p.symbol == x.symbol);
        return Allocation(symbol: x.symbol, name: s.name, weight: x.weight, reason: x.reason.isEmpty ? (_reasons[s.sector] ?? '') : x.reason, entryPrice: s.price, logo: s.logo);
      }).toList();

  List<String> _risks(List<Allocation> a, List<Stock> pool, {List<String> extra = const []}) {
    final out = <String>[...extra];
    final sectors = a.map((x) => pool.firstWhere((s) => s.symbol == x.symbol, orElse: () => pool.first).sector).toSet();
    if (sectors.length == 1) out.add('All ${a.length} are ${sectors.first} companies. A slump in that sector would move them together.');
    final big = a.where((x) => x.weight > 35).toList();
    for (final b in big) {
      out.add('${b.name} is ${b.weight.round()}% of the pot. A bad year for one company would hurt a lot.');
    }
    if (out.isEmpty) out.add('Stocks can fall. Only invest money you can leave alone for years.');
    return out;
  }

  /// Review an edited allocation.
  List<String> review(List<Allocation> a, List<Stock> pool) => _risks(a, pool);
}
