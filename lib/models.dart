import 'package:cloud_firestore/cloud_firestore.dart';

enum Market { us, ng, eu, uk, ke }

extension MarketX on Market {
  String get code => name.toUpperCase();
  String get label => const {
        Market.us: 'US',
        Market.ng: 'Nigeria',
        Market.eu: 'Europe',
        Market.uk: 'UK',
        Market.ke: 'Kenya',
      }[this]!;
  String get flag => const {
        Market.us: '🇺🇸',
        Market.ng: '🇳🇬',
        Market.eu: '🇪🇺',
        Market.uk: '🇬🇧',
        Market.ke: '🇰🇪',
      }[this]!;
  String get currency => const {
        Market.us: 'USD',
        Market.ng: 'NGN',
        Market.eu: 'EUR',
        Market.uk: 'GBP',
        Market.ke: 'KES',
      }[this]!;
}

double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  if (v is Map) return _d(v['value'] ?? v['amount']);
  return null;
}

class Stock {
  final String symbol;
  final String name;
  final Market market;
  final String exchange;
  final String sector;
  final String? domain;
  final String? contract; // tokenized stock contract on Base (US only)
  final double? price;
  final double? changePct;
  final DateTime? priceAt;
  final String? logoUrl;

  const Stock({
    required this.symbol,
    required this.name,
    required this.market,
    required this.exchange,
    this.sector = 'other',
    this.domain,
    this.contract,
    this.price,
    this.changePct,
    this.priceAt,
    this.logoUrl,
  });

  /// Investable onchain today: only Coinbase tokenized US stocks on Base.
  bool get investable => contract != null && contract!.isNotEmpty;

  String get logo {
    if (logoUrl != null && logoUrl!.isNotEmpty) return logoUrl!;
    if (domain != null) return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
    return '';
  }

  String get currency => market.currency;

  Stock copyWith({double? price, double? changePct, DateTime? priceAt, String? contract, String? logoUrl}) => Stock(
        symbol: symbol,
        name: name,
        market: market,
        exchange: exchange,
        sector: sector,
        domain: domain,
        contract: contract ?? this.contract,
        price: price ?? this.price,
        changePct: changePct ?? this.changePct,
        priceAt: priceAt ?? this.priceAt,
        logoUrl: logoUrl ?? this.logoUrl,
      );

  factory Stock.fromJson(Map<String, dynamic> j, Market m) => Stock(
        symbol: (j['symbol'] ?? '').toString(),
        name: (j['name'] ?? j['symbol'] ?? '').toString(),
        market: m,
        exchange: (j['exchange'] ?? '').toString(),
        sector: (j['sector'] ?? 'other').toString(),
        domain: j['domain'] as String?,
        contract: (j['contract'] as String?)?.toLowerCase(),
        price: _d(j['price']),
        changePct: _d(j['changePct']),
        priceAt: j['priceAt'] != null ? DateTime.tryParse(j['priceAt'].toString()) : null,
        logoUrl: j['logo'] as String?,
      );
}

enum Goal { wealth, tech, income, longTerm }

extension GoalX on Goal {
  String get label => const {
        Goal.wealth: 'Build wealth',
        Goal.tech: 'Tech growth',
        Goal.income: 'Dividend income',
        Goal.longTerm: 'Long term',
      }[this]!;
  String get blurb => const {
        Goal.wealth: 'A balanced mix across sectors.',
        Goal.tech: 'Big tech names that can grow over years.',
        Goal.income: 'Steady companies that tend to pay dividends.',
        Goal.longTerm: 'Household names to hold for a decade.',
      }[this]!;
}

class Allocation {
  final String symbol;
  final String name;
  final double weight; // 0-100
  final String reason;
  final double? entryPrice;
  final String? logo;
  const Allocation({required this.symbol, required this.name, required this.weight, required this.reason, this.entryPrice, this.logo});

  Map<String, dynamic> toJson() => {'symbol': symbol, 'name': name, 'weight': weight, 'reason': reason, 'entryPrice': entryPrice, 'logo': logo};
  factory Allocation.fromJson(Map<String, dynamic> j) => Allocation(
        symbol: j['symbol'] as String,
        name: (j['name'] ?? j['symbol']) as String,
        weight: (_d(j['weight']) ?? 0),
        reason: (j['reason'] ?? '') as String,
        entryPrice: _d(j['entryPrice']),
        logo: j['logo'] as String?,
      );
  Allocation withWeight(double w) => Allocation(symbol: symbol, name: name, weight: w, reason: reason, entryPrice: entryPrice, logo: logo);
}

class GuardianProposal {
  final String summary;
  final List<Allocation> allocations;
  final List<String> risks;
  final bool fromAi;
  const GuardianProposal({required this.summary, required this.allocations, required this.risks, this.fromAi = false});
}

class Pot {
  final String id;
  final String name;
  final Goal goal;
  final double amount; // USD
  final List<Allocation> allocations;
  final List<String> risks;
  final DateTime createdAt;
  final String? txHash; // when recorded on Base

  const Pot({required this.id, required this.name, required this.goal, required this.amount, required this.allocations, required this.risks, required this.createdAt, this.txHash});

  Map<String, dynamic> toJson() => {
        'name': name,
        'goal': goal.name,
        'amount': amount,
        'allocations': allocations.map((a) => a.toJson()).toList(),
        'risks': risks,
        'createdAt': createdAt.toIso8601String(),
        'txHash': txHash,
      };

  factory Pot.fromJson(String id, Map<String, dynamic> j) {
    final created = j['createdAt'];
    return Pot(
      id: id,
      name: (j['name'] ?? 'My pot') as String,
      goal: Goal.values.firstWhere((g) => g.name == j['goal'], orElse: () => Goal.wealth),
      amount: _d(j['amount']) ?? 0,
      allocations: ((j['allocations'] as List?) ?? []).map((e) => Allocation.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      risks: ((j['risks'] as List?) ?? []).map((e) => e.toString()).toList(),
      createdAt: created is Timestamp ? created.toDate() : DateTime.tryParse(created?.toString() ?? '') ?? DateTime.now(),
      txHash: j['txHash'] as String?,
    );
  }

  /// Current value from entry prices and live prices; null prices count as flat.
  double valueWith(Map<String, double> prices) {
    var v = 0.0;
    for (final a in allocations) {
      final part = amount * a.weight / 100;
      final now = prices[a.symbol];
      final entry = a.entryPrice;
      v += (now != null && entry != null && entry > 0) ? part * now / entry : part;
    }
    return v;
  }
}
