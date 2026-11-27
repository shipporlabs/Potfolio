import '../config.dart';
import 'api.dart';
import 'wallet_service.dart';

/// A firm price from the Worker (0x Swap API on Base) for one swap.
class TradeQuote {
  final String side; // buy | sell
  final String token;
  final BigInt sellAmount;
  final BigInt buyAmount;
  final BigInt minBuyAmount;
  final String? spender; // set when an approval is needed first
  final Map<String, dynamic> tx;
  final List<String> route;
  final BigInt potfolioFee; // in USDC micro-units, 0 if none

  TradeQuote.fromJson(Map<String, dynamic> j)
      : side = '${j['side']}',
        token = '${j['token']}',
        sellAmount = BigInt.parse('${j['sellAmount'] ?? 0}'),
        buyAmount = BigInt.parse('${j['buyAmount'] ?? 0}'),
        minBuyAmount = BigInt.parse('${j['minBuyAmount'] ?? 0}'),
        spender = j['allowanceSpender'] as String?,
        tx = Map<String, dynamic>.from((j['transaction'] as Map?) ?? {}),
        route = ((j['route'] as List?) ?? []).map((e) => '$e').toSet().toList(),
        potfolioFee = BigInt.tryParse('${(j['fees'] as Map?)?['integratorFee']?['amount'] ?? 0}') ?? BigInt.zero;
}

class TradeResult {
  final String hash;
  final BigInt sold;
  final BigInt bought;
  const TradeResult(this.hash, this.sold, this.bought);
  String get url => '${AppConfig.explorer}/tx/$hash';
}

class TradeFailed implements Exception {
  final String message;
  TradeFailed(this.message);
  @override
  String toString() => message;
}

/// Buys and sells tokenized stocks with USDC from the user's own wallet.
/// The Worker only prepares transactions; the key never leaves the device.
class TradeService {
  final WorkerApi api;
  final WalletService wallet;
  final Future<String?> Function() idToken;
  TradeService(this.api, this.wallet, this.idToken);

  static final _minGas = BigInt.from(20000000000000); // 0.00002 ETH

  Future<TradeQuote> quote({required String side, required String token, required BigInt amount, required String taker}) async {
    final j = await api.get('/trade/quote', query: {'side': side, 'token': token, 'amount': amount.toString(), 'taker': taker});
    return TradeQuote.fromJson(Map<String, dynamic>.from(j as Map));
  }

  /// Makes sure the wallet has a little ETH for network fees (Potfolio pays).
  Future<void> ensureGas(String address) async {
    if (await wallet.ethBalance(address) >= _minGas) return;
    try {
      await api.post('/gas/topup', {'address': address}, token: await idToken());
    } on ApiException catch (e) {
      throw TradeFailed(e.message);
    }
    for (var i = 0; i < 15; i++) {
      if (await wallet.ethBalance(address) >= _minGas) return;
      await Future.delayed(const Duration(seconds: 2));
    }
    throw TradeFailed('Network fee top-up is taking long. Try again in a minute.');
  }

  /// Runs one swap: gas → approval (if needed) → fresh quote → send → wait.
  /// [approve] lets a caller approve more than this trade (e.g. a whole pot) once.
  Future<TradeResult> execute({
    required String side,
    required String token,
    required BigInt amount,
    BigInt? approve,
    void Function(String step)? onStep,
  }) async {
    final me = await wallet.address();
    if (me == null) throw TradeFailed('Create your wallet first.');
    onStep?.call('Checking network fees');
    await ensureGas(me);

    onStep?.call('Getting the best price');
    var q = await _quote(side, token, amount, me);
    if (q.spender != null) {
      onStep?.call(side == 'buy' ? 'Approving USDC' : 'Approving the stock token');
      final sellToken = side == 'buy' ? AppConfig.usdc : token;
      final want = (approve != null && approve > amount) ? approve : amount;
      final h = await wallet.approve(sellToken, q.spender!, want);
      if (!await wallet.waitFor(h)) throw TradeFailed('The approval didn’t go through.');
      q = await _quote(side, token, amount, me);
    }

    onStep?.call(side == 'buy' ? 'Buying' : 'Selling');
    final tx = q.tx;
    final gas = int.tryParse('${tx['gas'] ?? ''}');
    final hash = await wallet.send(
      to: '${tx['to']}',
      data: '${tx['data']}',
      value: BigInt.tryParse('${tx['value'] ?? 0}') ?? BigInt.zero,
      gas: gas == null ? 600000 : (gas * 13 ~/ 10),
    );
    onStep?.call('Confirming on Base');
    if (!await wallet.waitFor(hash)) throw TradeFailed('The trade didn’t go through, so nothing was spent except a tiny network fee. Try again.');
    return TradeResult(hash, q.sellAmount, q.buyAmount);
  }

  Future<TradeQuote> _quote(String side, String token, BigInt amount, String me) async {
    try {
      return await quote(side: side, token: token, amount: amount, taker: me);
    } on ApiException catch (e) {
      throw TradeFailed(e.message);
    }
  }
}
