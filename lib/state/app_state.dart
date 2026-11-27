import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import '../services/checkout_service.dart';
import '../services/guardian_service.dart';
import '../services/pot_repository.dart';
import '../services/stocks_service.dart';
import '../services/trade_service.dart';
import '../services/wallet_service.dart';

/// App-wide state shared through Provider.
class AppState extends ChangeNotifier {
  final AuthService auth;
  final PotRepository pots;
  final WorkerApi api;
  late final StocksService stocks = StocksService(api);
  late final GuardianService guardian = GuardianService(api);
  late final CheckoutService checkout = CheckoutService(api);
  final WalletService wallet = WalletService();
  late final TradeService trade = TradeService(api, wallet, auth.idToken);

  AppState({required this.auth, required this.pots, required this.api}) {
    auth.user.addListener(_onUser);
    _onUser();
  }

  bool onboarded = false;
  bool ready = false;
  String? address;
  double? usdc;
  double? funded;
  List<Pot> myPots = [];
  Set<String> watchlist = {};
  bool sharedOnce = false;
  bool eligible = false; // user confirmed they may hold tokenized stocks

  AppUser? get user => auth.user.value;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    onboarded = p.getBool('onboarded') ?? false;
    watchlist = (p.getStringList('watchlist') ?? []).toSet();
    sharedOnce = p.getBool('shared_once') ?? false;
    eligible = p.getBool('eligible_v1') ?? false;
    ready = true;
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    (await SharedPreferences.getInstance()).setBool('onboarded', true);
    notifyListeners();
  }

  Future<void> _onUser() async {
    final u = user;
    if (u == null) {
      myPots = [];
      notifyListeners();
      return;
    }
    address = await wallet.address();
    await refreshPots();
    refreshBalances();
    stocks.list(Market.us).then((_) => notifyListeners());
  }

  Future<void> createWallet() async {
    address = await wallet.create();
    final u = user;
    if (u != null) {
      try {
        await pots.saveProfile(u.uid, {'name': u.name, 'email': u.email, 'walletAddress': address});
      } catch (_) {}
    }
    notifyListeners();
    refreshBalances();
  }

  /// Money the user holds: wallet USDC plus card/bank credit from checkout.
  double get balance => (usdc ?? 0) + (funded ?? 0);

  /// Money planned for pots but not invested onchain (onchain buys already
  /// left the wallet, so they're not subtracted twice).
  double get inPots => myPots.fold<double>(0, (s, p) => s + p.paperAmount);

  /// What's free to put into a pot. Pots are envelopes over your balance,
  /// so a pot can't hold more than you actually have.
  double get available {
    final v = balance - inPots;
    return v > 0 ? v : 0;
  }

  Future<void> refreshBalances() async {
    if (address != null) usdc = await wallet.usdcBalance(address!);
    funded = await checkout.fundedBalance(await auth.idToken());
    notifyListeners();
  }

  Future<void> refreshPots() async {
    final u = user;
    if (u == null) return;
    try {
      myPots = await pots.list(u.uid);
    } catch (_) {}
    notifyListeners();
  }

  Future<Pot> savePot(Pot p) async {
    if (p.id.isEmpty && p.amount > available + 0.005) throw const NotEnoughMoney();
    final saved = await pots.save(user!.uid, p);
    await refreshPots();
    return saved;
  }

  /// Records a deposit into a pot (PiggyVest-style "add to target").
  Future<Pot> addContribution(Pot p, double amount) async {
    if (amount > available + 0.005) throw const NotEnoughMoney();
    final updated = p.copyWith(contributions: [...p.contributions, Contribution(amount, DateTime.now())]);
    final saved = await pots.save(user!.uid, updated);
    await refreshPots();
    return saved;
  }

  // ── Real trading (Base mainnet) ─────────────────────────────────────────

  bool get canTrade => AppConfig.tradingEnabled && address != null;

  Future<void> confirmEligible() async {
    eligible = true;
    (await SharedPreferences.getInstance()).setBool('eligible_v1', true);
    notifyListeners();
  }

  /// Raw units of a tokenized stock in the user's wallet.
  Future<BigInt?> holding(Stock s) async {
    if (address == null || s.contract == null || s.contract!.isEmpty) return null;
    return wallet.tokenBalance(s.contract!, address!);
  }

  Future<TradeResult> buyStock(Stock s, double usd, {void Function(String)? onStep}) async {
    if (usd > (usdc ?? 0) + 0.000001) throw TradeFailed('You have ${_m(usdc ?? 0)} USDC in your wallet. Add money first.');
    final r = await trade.execute(side: 'buy', token: s.contract!, amount: BigInt.from((usd * 1e6).floor()), onStep: onStep);
    await refreshBalances();
    return r;
  }

  Future<TradeResult> sellStock(Stock s, BigInt units, {void Function(String)? onStep}) async {
    final r = await trade.execute(side: 'sell', token: s.contract!, amount: units, onStep: onStep);
    await refreshBalances();
    return r;
  }

  /// Invests [usd] of wallet USDC into a pot: one swap per stock, by weight.
  /// Whatever succeeded is saved even if a later swap fails.
  Future<Pot> investInPot(Pot p, double usd, {void Function(String)? onStep}) async {
    await refreshBalances();
    if (usd > (usdc ?? 0) + 0.000001) throw TradeFailed('You have ${_m(usdc ?? 0)} USDC in your wallet. Add money first.');
    final universe = await stocks.list(Market.us);
    final contracts = {for (final st in universe) if (st.investable) st.symbol: st.contract!};
    final legs = p.allocations.where((a) => contracts.containsKey(a.symbol)).toList();
    if (legs.isEmpty) throw TradeFailed('None of this pot’s stocks can be bought on Base yet.');
    final totalW = legs.fold<double>(0, (s, a) => s + a.weight);
    final total = BigInt.from((usd * 1e6).floor());
    final trades = <PotTrade>[];
    Object? failure;
    for (var i = 0; i < legs.length; i++) {
      final a = legs[i];
      final part = BigInt.from((usd * a.weight / totalW * 1e6).floor());
      if (part < BigInt.from(500000)) continue; // skip legs under $0.50
      try {
        final r = await trade.execute(
          side: 'buy',
          token: contracts[a.symbol]!,
          amount: part,
          approve: total,
          onStep: (st) => onStep?.call('${a.symbol} (${i + 1} of ${legs.length}): $st'),
        );
        trades.add(PotTrade(symbol: a.symbol, token: contracts[a.symbol]!, side: 'buy', units: r.bought.toString(), usd: part.toDouble() / 1e6, hash: r.hash));
      } catch (e) {
        failure = e;
        break;
      }
    }
    var saved = p;
    if (trades.isNotEmpty) {
      final spent = trades.fold<double>(0, (s, t) => s + t.usd);
      saved = await pots.save(user!.uid, p.copyWith(contributions: [...p.contributions, Contribution(spent, DateTime.now(), trades: trades)]));
      await refreshPots();
    }
    await refreshBalances();
    if (failure != null) {
      throw TradeFailed(trades.isEmpty ? '$failure' : 'Bought ${trades.length} of ${legs.length} stocks, then: $failure');
    }
    return saved;
  }

  /// Sells everything this pot bought (capped at what the wallet still holds).
  Future<Pot> sellPot(Pot p, {void Function(String)? onStep}) async {
    final units = p.units;
    if (units.isEmpty) throw TradeFailed('This pot has nothing onchain to sell.');
    final bySymbol = {for (final t in p.trades) t.token: t.symbol};
    final trades = <PotTrade>[];
    Object? failure;
    var i = 0;
    for (final e in units.entries) {
      i++;
      final held = await wallet.tokenBalance(e.key, address!) ?? BigInt.zero;
      final amt = held < e.value ? held : e.value;
      if (amt <= BigInt.zero) continue;
      try {
        final r = await trade.execute(side: 'sell', token: e.key, amount: amt, onStep: (st) => onStep?.call('${bySymbol[e.key]} ($i of ${units.length}): $st'));
        trades.add(PotTrade(symbol: bySymbol[e.key] ?? '', token: e.key, side: 'sell', units: amt.toString(), usd: r.bought.toDouble() / 1e6, hash: r.hash));
      } catch (err) {
        failure = err;
        break;
      }
    }
    var saved = p;
    if (trades.isNotEmpty) {
      final soldShare = trades.length / units.length;
      saved = await pots.save(user!.uid, p.copyWith(contributions: [...p.contributions, Contribution(-p.invested * soldShare, DateTime.now(), trades: trades)]));
      await refreshPots();
    }
    await refreshBalances();
    if (failure != null) throw TradeFailed(trades.isEmpty ? '$failure' : 'Sold ${trades.length} of ${units.length}, then: $failure');
    return saved;
  }

  static String _m(double v) => '\$${v.toStringAsFixed(2)}';

  /// Creates a public read-only snapshot of a pot and returns its link.
  Future<String> sharePotLink(Map<String, dynamic> snapshot) async {
    final j = await api.post('/share', snapshot, token: await auth.idToken());
    final id = (j as Map)['id'].toString();
    await markShared();
    return '${AppConfig.siteUrl}/p/$id';
  }

  Future<void> markShared() async {
    if (sharedOnce) return;
    sharedOnce = true;
    (await SharedPreferences.getInstance()).setBool('shared_once', true);
    notifyListeners();
  }

  Future<void> deletePot(String id) async {
    await pots.delete(user!.uid, id);
    await refreshPots();
  }

  Future<void> toggleWatch(String symbol) async {
    watchlist.contains(symbol) ? watchlist.remove(symbol) : watchlist.add(symbol);
    (await SharedPreferences.getInstance()).setStringList('watchlist', watchlist.toList());
    notifyListeners();
  }

  double get totalInvested => myPots.fold(0, (s, p) => s + p.invested);
  double get totalValue {
    final prices = stocks.priceMap();
    return myPots.fold(0, (s, p) => s + p.valueNow(prices));
  }
}

/// Thrown when a pot would hold more than the user's available balance.
class NotEnoughMoney implements Exception {
  const NotEnoughMoney();
  @override
  String toString() => 'Not enough money available. Add money first.';
}
