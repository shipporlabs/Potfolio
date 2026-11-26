import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import '../services/checkout_service.dart';
import '../services/guardian_service.dart';
import '../services/pot_repository.dart';
import '../services/stocks_service.dart';
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

  AppUser? get user => auth.user.value;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    onboarded = p.getBool('onboarded') ?? false;
    watchlist = (p.getStringList('watchlist') ?? []).toSet();
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
    final saved = await pots.save(user!.uid, p);
    await refreshPots();
    return saved;
  }

  /// Records a deposit into a pot (PiggyVest-style "add to target").
  Future<Pot> addContribution(Pot p, double amount) async {
    final updated = p.copyWith(contributions: [...p.contributions, Contribution(amount, DateTime.now())]);
    final saved = await pots.save(user!.uid, updated);
    await refreshPots();
    return saved;
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
