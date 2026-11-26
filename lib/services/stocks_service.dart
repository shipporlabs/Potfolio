import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models.dart';
import 'api.dart';

/// Loads stock lists per market.
/// With a Worker: live lists and prices from /stocks.
/// Without: bundled lists, plus Coinbase tokenized-stock data for the US.
class StocksService {
  final WorkerApi _api;
  final Map<Market, List<Stock>> _cache = {};
  final Map<Market, DateTime> _at = {};
  StocksService(this._api);

  Future<List<Stock>> list(Market m, {bool refresh = false}) async {
    final fresh = _at[m] != null && DateTime.now().difference(_at[m]!) < const Duration(minutes: 3);
    if (!refresh && fresh && _cache[m] != null) return _cache[m]!;
    List<Stock> out;
    try {
      if (AppConfig.hasWorker) {
        final j = await _api.get('/stocks', query: {'market': m.code});
        out = ((j['stocks'] as List?) ?? []).map((e) => Stock.fromJson(Map<String, dynamic>.from(e as Map), m)).toList();
        if (out.isEmpty) out = await _bundled(m);
      } else {
        out = await _bundled(m);
        if (m == Market.us) out = await _mergeTokenized(out);
      }
    } catch (_) {
      out = _cache[m] ?? await _bundled(m);
    }
    _cache[m] = out;
    _at[m] = DateTime.now();
    return out;
  }

  Future<List<Stock>> _bundled(Market m) async {
    final raw = await rootBundle.loadString('assets/data/stocks_${m.name}.json');
    final list = (jsonDecode(raw) as List).map((e) => Stock.fromJson(Map<String, dynamic>.from(e as Map), m)).toList();
    return list;
  }

  /// Adds contract addresses and Chainlink reference prices from the public
  /// Coinbase Tokenized Stocks API (no key). Works on mobile; browsers may block it (CORS),
  /// which is why the Worker is recommended for web.
  Future<List<Stock>> _mergeTokenized(List<Stock> base) async {
    try {
      final r = await http.get(Uri.parse('${AppConfig.tokenizedStocksApi}?page_size=500')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return base;
      final body = jsonDecode(r.body);
      List recs = body is List ? body : (body is Map ? (body.values.firstWhere((v) => v is List, orElse: () => const []) as List) : const []);
      final byTicker = <String, Map>{};
      for (final rec in recs.whereType<Map>()) {
        final t = _norm((rec['ticker'] ?? rec['symbol'] ?? '').toString());
        if (t.isNotEmpty) byTicker[t] = rec;
      }
      return base.map((s) {
        final rec = byTicker[_norm(s.symbol)];
        if (rec == null) return s;
        final nav = rec['nav_price'];
        final price = nav is num ? nav.toDouble() : double.tryParse('${nav ?? ''}');
        return s.copyWith(
          contract: (rec['contract_address'] ?? '').toString().toLowerCase(),
          price: (price != null && price > 0) ? price : s.price,
          priceAt: DateTime.tryParse('${rec['nav_price_updated_at'] ?? ''}'),
          logoUrl: '${AppConfig.tokenizedStocksApi}/images/${rec['symbol'] ?? s.symbol}',
        );
      }).toList();
    } catch (_) {
      return base;
    }
  }

  String _norm(String t) {
    var x = t.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (x.length > 1 && x.endsWith('X')) x = x.substring(0, x.length - 1);
    return x;
  }

  Map<String, double> priceMap() {
    final m = <String, double>{};
    for (final l in _cache.values) {
      for (final s in l) {
        if (s.price != null) m[s.symbol] = s.price!;
      }
    }
    return m;
  }

  Future<List<double>> history(Stock s, {String range = '1M'}) async {
    if (!AppConfig.hasWorker) return const [];
    try {
      final j = await _api.get('/history', query: {'symbol': s.symbol, 'market': s.market.code, 'range': range});
      return ((j['points'] as List?) ?? []).map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return const [];
    }
  }
}
