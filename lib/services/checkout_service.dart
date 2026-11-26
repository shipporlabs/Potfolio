import '../config.dart';
import 'api.dart';

/// One way to pay offered by Light (Sendlight) checkout.
class PayOption {
  final String currency;
  final String? country;
  final List<String> methods;
  final String amount; // minor units
  final int decimals;
  const PayOption({required this.currency, this.country, required this.methods, required this.amount, required this.decimals});
  double get value => (double.tryParse(amount) ?? 0) / _pow10(decimals);
  factory PayOption.fromJson(Map j) => PayOption(
        currency: j['currency'].toString(),
        country: j['country']?.toString(),
        methods: ((j['methods'] as List?) ?? []).map((e) => e.toString()).toList(),
        amount: (j['amount'] ?? '0').toString(),
        decimals: (j['decimals'] as num?)?.toInt() ?? 2,
      );
}

class PaymentInstructions {
  final String method;
  final String? accountNumber, accountName, bankName, reference, lipaNamba, note;
  final String amount;
  final String currency;
  final int decimals;
  final DateTime? expiresAt;
  const PaymentInstructions({required this.method, this.accountNumber, this.accountName, this.bankName, this.reference, this.lipaNamba, this.note, required this.amount, required this.currency, required this.decimals, this.expiresAt});
  double get value => (double.tryParse(amount) ?? 0) / _pow10(decimals);
  factory PaymentInstructions.fromJson(Map j) {
    final amt = (j['amount'] as Map?) ?? const {};
    return PaymentInstructions(
      method: (j['method'] ?? '').toString(),
      accountNumber: j['account_number'] as String?,
      accountName: j['account_name'] as String?,
      bankName: j['bank_name'] as String?,
      reference: j['reference'] as String?,
      lipaNamba: j['lipa_namba'] as String?,
      note: j['note'] as String?,
      amount: (amt['amount'] ?? '0').toString(),
      currency: (amt['currency'] ?? '').toString(),
      decimals: (j['decimals'] as num?)?.toInt() ?? 2,
      expiresAt: DateTime.tryParse('${j['expires_at'] ?? ''}'),
    );
  }
}

class CheckoutView {
  final String status;
  final List<PayOption> options;
  final PaymentInstructions? payment;
  final DateTime? now;
  final DateTime? expiresAt;
  const CheckoutView({required this.status, required this.options, this.payment, this.now, this.expiresAt});
  bool get isFinal => const {'completed', 'expired', 'failed', 'mismatched', 'cancelled'}.contains(status);
  factory CheckoutView.fromJson(Map j) => CheckoutView(
        status: (j['status'] ?? '').toString(),
        options: ((j['options'] as List?) ?? []).whereType<Map>().map(PayOption.fromJson).toList(),
        payment: j['payment'] is Map && (j['payment']['account_number'] != null || j['payment']['lipa_namba'] != null || j['payment']['note'] != null)
            ? PaymentInstructions.fromJson(j['payment'] as Map)
            : null,
        now: DateTime.tryParse('${j['now'] ?? ''}'),
        expiresAt: DateTime.tryParse('${j['expires_at'] ?? ''}'),
      );
}

/// Add money with Light checkout. The Worker creates and signs the session
/// (API keys never touch the app), then proxies the public checkout endpoints.
class CheckoutService {
  final WorkerApi _api;
  CheckoutService(this._api);

  bool get available => AppConfig.hasWorker;

  Future<String> createSession(double amountUsd, String? token) async {
    final j = await _api.post('/checkout/sessions', {'amountUsd': amountUsd}, token: token);
    return j['clientSecret'] as String;
  }

  Future<CheckoutView> view(String secret) async => CheckoutView.fromJson(await _api.get('/checkout/view/$secret') as Map);

  Future<CheckoutView> pay(String secret, {required String currency, String? method, String? phone, String? network}) async {
    final j = await _api.post('/checkout/pay/$secret', {
      'currency': currency,
      if (method != null) 'method': method,
      if (phone != null && phone.isNotEmpty) 'phone_number': phone,
      if (network != null && network.isNotEmpty) 'mobile_network': network,
    });
    return CheckoutView.fromJson(j as Map);
  }

  /// Funds credited after Light's checkout_session.completed webhook.
  Future<double?> fundedBalance(String? token) async {
    if (!available || token == null) return null;
    try {
      final j = await _api.get('/balance', token: token);
      return (j['usdc'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }
}

double _pow10(int d) {
  var x = 1.0;
  for (var i = 0; i < d; i++) {
    x *= 10;
  }
  return x;
}
