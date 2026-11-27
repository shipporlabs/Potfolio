import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/checkout_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/stock_widgets.dart';

/// Add money: pay in local currency (bank transfer, mobile money) or USDC on
/// Base through Light checkout, or send USDC straight to your own wallet.
class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key});
  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

const _countries = {
  'NG': 'Nigeria', 'KE': 'Kenya', 'GH': 'Ghana', 'TZ': 'Tanzania', 'UG': 'Uganda', 'ZA': 'South Africa', 'RW': 'Rwanda',
  'ZM': 'Zambia', 'MW': 'Malawi', 'CM': 'Cameroon', 'SN': 'Senegal', 'CI': 'Côte d’Ivoire', 'BJ': 'Benin', 'ET': 'Ethiopia',
  'EG': 'Egypt', 'MA': 'Morocco', 'US': 'United States', 'GB': 'United Kingdom',
};

String _flag(String code) => code.length == 2 ? String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65)) : '🌍';

String _methodLabel(String m) => const {
      'bank_transfer': 'Bank transfer',
      'mobile_money': 'Mobile money',
      'lipa_namba': 'Lipa Namba',
      'wallet_transfer': 'USDC on Base',
    }[m] ??
    m;

IconData _methodIcon(String m) => const {
      'bank_transfer': Icons.account_balance_rounded,
      'mobile_money': Icons.phone_iphone_rounded,
      'lipa_namba': Icons.storefront_rounded,
      'wallet_transfer': Icons.account_balance_wallet_rounded,
    }[m] ??
    Icons.payments_rounded;

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  double _amount = 50;
  final _amountCtl = TextEditingController(text: '50');
  String? _secret;
  CheckoutView? _view;
  PayOption? _option;
  String? _method;
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;
  Timer? _poll;
  Timer? _tick;
  Duration _left = Duration.zero;
  Duration _total = const Duration(minutes: 30);

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _amountCtl.dispose();
    _phone.dispose();
    super.dispose();
  }

  CheckoutService get _co => context.read<AppState>().checkout;

  int get _stepIndex => _view == null ? 0 : ((_view!.payment == null && !_view!.isFinal) ? 1 : 2);

  void _setAmount(double v) => setState(() {
        _amount = v;
        _amountCtl.text = v.toStringAsFixed(0);
      });

  Future<void> _start() async {
    if (_amount < 1) {
      setState(() => _error = 'Enter at least \$1.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await context.read<AppState>().auth.idToken();
      final secret = await _co.createSession(_amount, token);
      final v = await _co.view(secret);
      setState(() {
        _secret = secret;
        _view = v;
        _option = v.options.isNotEmpty ? v.options.first : null;
        _method = _option?.methods.isNotEmpty == true ? _option!.methods.first : null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    if (_secret == null || _option == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final v = await _co.pay(_secret!, currency: _option!.currency, method: _method, phone: _phone.text.trim());
      setState(() => _view = v);
      _startPolling();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _restart() => setState(() {
        _poll?.cancel();
        _tick?.cancel();
        _view = null;
        _secret = null;
        _error = null;
      });

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final v = await _co.view(_secret!);
        if (!mounted) return;
        setState(() => _view = v);
        if (v.isFinal) {
          _poll?.cancel();
          _tick?.cancel();
          if (v.status == 'completed') context.read<AppState>().refreshBalances();
        }
      } catch (_) {}
    });
    _tick?.cancel();
    final exp = _view?.payment?.expiresAt;
    final now = _view?.now;
    if (exp != null && now != null) {
      final offset = DateTime.now().difference(now);
      _total = exp.difference(now);
      if (_total <= Duration.zero) _total = const Duration(minutes: 30);
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _left = exp.difference(DateTime.now().subtract(offset)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = context.read<AppState>().checkout.available;
    final step = _stepIndex;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add money'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => step == 1 && !_busy ? _restart() : Navigator.of(context).maybePop(),
        ),
      ),
      bottomNavigationBar: available && step < 2 ? _bottomBar(step) : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              if (available) ...[_Steps(index: step), const SizedBox(height: 20)],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Column(
                  key: ValueKey(step),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: !available
                      ? _noServer()
                      : step == 0
                          ? _amountStep()
                          : step == 1
                              ? _chooseStep()
                              : _payStep(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(14)),
                  child: Text(_error!, style: const TextStyle(color: PColors.loss, fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 28),
              const Center(child: Text('Secure checkout · Powered by Light', style: TextStyle(fontSize: 12, color: PColors.slate))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(int step) {
    String label;
    VoidCallback? onTap;
    if (step == 0) {
      label = 'Continue with ${money(_amount).replaceAll('.00', '')}';
      onTap = _busy ? null : _start;
    } else {
      final o = _option;
      final needsPhone = _method == 'mobile_money' || _method == 'lipa_namba';
      label = o == null ? 'Choose how to pay' : 'Get details to pay ${_fmtOption(o)}';
      onTap = _busy || o == null || (needsPhone && _phone.text.trim().length < 9) ? null : _pay;
    }
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: PColors.line))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: FilledButton(
              onPressed: onTap,
              child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(label),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _noServer() => [
        const PCard(
          color: PColors.blueTint,
          child: Text('Card, bank and mobile money top-ups need the Potfolio server. You can still send USDC on Base straight to your wallet.',
              style: TextStyle(height: 1.5)),
        ),
        const SizedBox(height: 14),
        const _OwnWalletCard(),
      ];

  // ── Step 1: amount ─────────────────────────────────────────────────────────
  List<Widget> _amountStep() => [
        Text('How much do you want to add?', style: display(26)),
        const SizedBox(height: 6),
        const Text('It arrives as USDC, a digital dollar, ready to invest.', style: TextStyle(color: PColors.slate)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: PColors.line)),
          child: Column(children: [
            IntrinsicWidth(
              child: TextField(
                controller: _amountCtl,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                style: display(52),
                decoration: InputDecoration(
                  prefixText: '\$',
                  prefixStyle: display(52, color: PColors.slate),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => _amount = double.tryParse(v) ?? 0),
              ),
            ),
            const Text('USD', style: TextStyle(color: PColors.slate, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              for (final v in [10.0, 25.0, 50.0, 100.0, 250.0])
                ChoiceChip(label: Text('\$${v.toStringAsFixed(0)}'), selected: _amount == v, onSelected: (_) => _setAmount(v), showCheckmark: false),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        const Row(children: [
          _Perk(icon: Icons.bolt_rounded, text: 'Usually minutes'),
          SizedBox(width: 8),
          _Perk(icon: Icons.lock_outline_rounded, text: 'Locked rate'),
          SizedBox(width: 8),
          _Perk(icon: Icons.public_rounded, text: '6+ countries'),
        ]),
        const SizedBox(height: 22),
        const _OwnWalletCard(),
      ];

  // ── Step 2: how to pay ─────────────────────────────────────────────────────
  List<Widget> _chooseStep() {
    final opts = _view!.options;
    final crypto = opts.where((o) => o.currency == 'USDC' || o.methods.contains('wallet_transfer')).toList();
    final local = opts.where((o) => !crypto.contains(o)).toList();
    return [
      Row(children: [
        Expanded(child: Text('How do you want to pay?', style: display(26))),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: PColors.blueTint, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.add_circle_outline_rounded, color: PColors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Adding ${money(_amount)} USDC', style: const TextStyle(fontWeight: FontWeight.w700))),
          TextButton(onPressed: _busy ? null : _restart, child: const Text('Change')),
        ]),
      ),
      if (local.isNotEmpty) ...[
        const SizedBox(height: 20),
        const _GroupLabel('Pay in your local currency'),
        for (final o in local) _optionTile(o),
      ],
      if (crypto.isNotEmpty) ...[
        const SizedBox(height: 14),
        const _GroupLabel('Pay with crypto'),
        for (final o in crypto) _optionTile(o),
      ],
    ];
  }

  Widget _optionTile(PayOption o) {
    final selected = _option == o;
    final isUsdc = o.currency == 'USDC';
    final needsPhone = selected && (_method == 'mobile_money' || _method == 'lipa_namba');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() {
            _option = o;
            _method = o.methods.isNotEmpty ? o.methods.first : null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? PColors.blue : PColors.line, width: selected ? 2 : 1),
              boxShadow: selected ? [BoxShadow(color: PColors.blue.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 6))] : const [],
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: isUsdc ? PColors.blue : PColors.mist, shape: BoxShape.circle),
                  child: isUsdc
                      ? const Text('\$', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))
                      : Text(_flag(o.country ?? ''), style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isUsdc ? 'USDC on Base' : (_countries[o.country] ?? o.country ?? o.currency), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(isUsdc ? 'From any wallet or exchange' : o.methods.map(_methodLabel).join(' · '), style: const TextStyle(fontSize: 12, color: PColors.slate)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_fmtOption(o), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(o.currency, style: const TextStyle(fontSize: 11, color: PColors.slate, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? PColors.blue : Colors.transparent,
                    border: Border.all(color: selected ? PColors.blue : PColors.line, width: 2),
                  ),
                  child: selected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                ),
              ]),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: selected && (o.methods.length > 1 || needsPhone)
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (o.methods.length > 1)
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final m in o.methods)
                                ChoiceChip(
                                  avatar: Icon(_methodIcon(m), size: 16, color: _method == m ? Colors.white : PColors.navy),
                                  label: Text(_methodLabel(m)),
                                  selected: _method == m,
                                  showCheckmark: false,
                                  onSelected: (_) => setState(() => _method = m),
                                ),
                            ]),
                          if (needsPhone) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: 'Mobile money number',
                                hintText: o.country == 'KE' ? '254712345678' : 'Country code + number',
                                prefixIcon: const Icon(Icons.phone_iphone_rounded),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ]),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Step 3: pay ────────────────────────────────────────────────────────────
  List<Widget> _payStep() {
    final v = _view!;
    final p = v.payment;
    if (v.status == 'completed') return _done();
    if (v.isFinal) return _failed(v.status);
    final isWallet = p?.method == 'wallet_transfer';
    final note = p?.note;
    final sandbox = note != null && note.toLowerCase().contains('sandbox');
    return [
      // Amount + timer
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(color: PColors.navy, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Send exactly', style: TextStyle(color: Color(0xFFA8B6D4), fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(p == null ? '—' : _fmtPay(p), style: display(36, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              if (p != null)
                InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => _copy('Amount', p.value.toStringAsFixed(p.currency == 'USDC' ? 2 : p.decimals)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Copy amount', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ]),
          ),
          if (_left > Duration.zero) _Countdown(left: _left, total: _total),
        ]),
      ),
      const SizedBox(height: 14),
      if (p != null && isWallet) _walletDetails(p),
      if (p != null && !isWallet) _bankDetails(p),
      const SizedBox(height: 14),
      _Progress(status: v.status),
      const SizedBox(height: 12),
      if (isWallet)
        const _Notice(icon: Icons.warning_amber_rounded, color: PColors.clay, bg: PColors.clayTint, text: 'Send USDC on the Base network only. Other tokens or networks can’t be recovered.'),
      if (note != null) ...[
        const SizedBox(height: 8),
        _Notice(icon: Icons.info_outline_rounded, color: PColors.slate, bg: Colors.white, text: sandbox ? 'Test mode: no real money is needed. This payment completes by itself.' : note),
      ],
      const SizedBox(height: 14),
      Center(
        child: TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('I’ll pay later · we’ll update your balance automatically')),
      ),
    ];
  }

  Widget _walletDetails(PaymentInstructions p) {
    final addr = p.accountNumber ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: PColors.line)),
      child: Column(children: [
        if (addr.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: PColors.line)),
            child: QrImageView(
              data: addr,
              size: 180,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: PColors.navy),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: PColors.navy),
            ),
          ),
        const SizedBox(height: 14),
        const Text('Deposit address', style: TextStyle(fontSize: 12, color: PColors.slate)),
        const SizedBox(height: 4),
        SelectableText(_chunk(addr), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 15, height: 1.5)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () => _copy('Address', addr), icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('Copy address'))),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(children: [
          const Text('Network', style: TextStyle(color: PColors.slate)),
          const Spacer(),
          Container(width: 16, height: 16, decoration: BoxDecoration(color: PColors.blue, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Text(p.bankName ?? 'Base', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        const Row(children: [
          Text('Token', style: TextStyle(color: PColors.slate)),
          Spacer(),
          Text('USDC', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _bankDetails(PaymentInstructions p) => Container(
        padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: PColors.line)),
        child: Column(children: [
          _copyRow('Bank', p.bankName),
          _copyRow('Account number', p.accountNumber, big: true),
          _copyRow('Account name', p.accountName),
          _copyRow('Reference', p.reference, highlight: true),
          _copyRow('Lipa Namba', p.lipaNamba, big: true),
          if (p.method == 'mobile_money')
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 8, 10, 8),
              child: Row(children: [
                Icon(Icons.phone_iphone_rounded, size: 18, color: PColors.blue),
                SizedBox(width: 8),
                Expanded(child: Text('Check your phone for a prompt to approve the payment.', style: TextStyle(fontSize: 13))),
              ]),
            ),
        ]),
      );

  List<Widget> _done() => [
        const SizedBox(height: 16),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, k, child) => Transform.scale(scale: k, child: child),
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: Color(0xFFE8F8EF), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: PColors.gain, size: 56),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(child: Text('${money(_amount)} added', style: display(30))),
        const SizedBox(height: 8),
        const Center(child: Text('Your balance updates in a moment. Put it to work in a pot.', textAlign: TextAlign.center, style: TextStyle(color: PColors.slate))),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ];

  List<Widget> _failed(String status) {
    final msg = const {
          'expired': 'The payment window closed before we received anything. If you already paid, it will be refunded or credited.',
          'mismatched': 'We received a different amount than expected. Our team will sort it out.',
          'cancelled': 'This payment was cancelled.',
        }[status] ??
        'This payment didn’t go through.';
    return [
      const SizedBox(height: 16),
      Center(
        child: Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(color: PColors.clayTint, shape: BoxShape.circle),
          child: const Icon(Icons.schedule_rounded, color: PColors.clay, size: 48),
        ),
      ),
      const SizedBox(height: 16),
      Center(child: Text('Payment ${status == 'expired' ? 'expired' : status}', style: display(26))),
      const SizedBox(height: 8),
      Center(child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: PColors.slate, height: 1.4))),
      const SizedBox(height: 22),
      FilledButton(onPressed: _restart, child: const Text('Start again')),
    ];
  }

  Widget _copyRow(String k, String? v, {bool big = false, bool highlight = false}) {
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: highlight ? const EdgeInsets.fromLTRB(10, 6, 0, 6) : EdgeInsets.zero,
      decoration: highlight ? BoxDecoration(color: PColors.clayTint, borderRadius: BorderRadius.circular(12)) : null,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(highlight ? '$k · include this' : k, style: TextStyle(fontSize: 12, color: highlight ? PColors.clay : PColors.slate, fontWeight: highlight ? FontWeight.w700 : FontWeight.w400)),
            const SizedBox(height: 2),
            SelectableText(v, style: big ? display(24, weight: FontWeight.w800) : const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
        ),
        IconButton(tooltip: 'Copy $k', icon: const Icon(Icons.copy_rounded, size: 18, color: PColors.blue), onPressed: () => _copy(k, v)),
      ]),
    );
  }

  void _copy(String what, String v) {
    Clipboard.setData(ClipboardData(text: v));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what copied'), duration: const Duration(seconds: 2)));
  }

  static String _chunk(String a) {
    if (a.length < 12) return a;
    final body = a.startsWith('0x') ? a.substring(2) : a;
    final parts = <String>[];
    for (var i = 0; i < body.length; i += 4) {
      parts.add(body.substring(i, i + 4 > body.length ? body.length : i + 4));
    }
    return '${a.startsWith('0x') ? '0x ' : ''}${parts.join(' ')}';
  }

  String _fmtOption(PayOption o) => o.currency == 'USDC' ? o.value.toStringAsFixed(2) : money(o.value, o.currency).replaceAll(RegExp(r'\.00$'), '');
  String _fmtPay(PaymentInstructions p) => p.currency == 'USDC' ? '${p.value.toStringAsFixed(2)} USDC' : money(p.value, p.currency);
}

/// Amount → Method → Pay.
class _Steps extends StatelessWidget {
  final int index;
  const _Steps({required this.index});
  @override
  Widget build(BuildContext context) {
    const labels = ['Amount', 'Method', 'Pay'];
    return Row(children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: i <= index ? PColors.blue : PColors.line, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: i <= index ? PColors.blue : Colors.white, border: Border.all(color: i <= index ? PColors.blue : PColors.line, width: 2)),
            child: i < index
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: i <= index ? Colors.white : PColors.slate)),
          ),
          const SizedBox(width: 6),
          Text(labels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: i <= index ? PColors.navy : PColors.slate)),
        ]),
      ],
    ]);
  }
}

class _Perk extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Perk({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: PColors.line)),
          child: Column(children: [
            Icon(icon, size: 18, color: PColors.blue),
            const SizedBox(height: 4),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: PColors.slate)),
      );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final String text;
  const _Notice({required this.icon, required this.color, required this.bg, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: bg == Colors.white ? Border.all(color: PColors.line) : null),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ]),
      );
}

/// Ring that empties as the payment window runs out.
class _Countdown extends StatelessWidget {
  final Duration left, total;
  const _Countdown({required this.left, required this.total});
  @override
  Widget build(BuildContext context) {
    final f = (left.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final m = left.inMinutes.clamp(0, 999), s = (left.inSeconds % 60).toString().padLeft(2, '0');
    final low = left.inMinutes < 5;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 76,
          height: 76,
          child: CircularProgressIndicator(value: f, strokeWidth: 6, backgroundColor: Colors.white.withValues(alpha: 0.12), color: low ? const Color(0xFFFFB896) : PColors.midBlue),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$m:$s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const Text('left', style: TextStyle(color: Color(0xFFA8B6D4), fontSize: 10)),
        ]),
      ]),
    );
  }
}

/// Sent → Received → Added, driven by the checkout status.
class _Progress extends StatelessWidget {
  final String status;
  const _Progress({required this.status});
  @override
  Widget build(BuildContext context) {
    final stage = const {'processing': 1, 'received': 1, 'confirming': 1, 'completed': 2}[status] ?? 0;
    const steps = [
      ('Waiting for your payment', 'Send it from your bank, phone or wallet'),
      ('Payment received', 'We’re converting it to USDC'),
      ('Added to your balance', 'Ready to invest'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: PColors.line)),
      child: Column(children: [
        for (var i = 0; i < steps.length; i++)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              SizedBox(
                width: 22,
                height: 22,
                child: i < stage
                    ? const CircleAvatar(backgroundColor: PColors.gain, child: Icon(Icons.check_rounded, size: 14, color: Colors.white))
                    : i == stage
                        ? const CircularProgressIndicator(strokeWidth: 2.5)
                        : Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: PColors.line, width: 2))),
              ),
              if (i < steps.length - 1) Container(width: 2, height: 26, color: i < stage ? PColors.gain : PColors.line),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(steps[i].$1, style: TextStyle(fontWeight: FontWeight.w700, color: i <= stage ? PColors.navy : PColors.slate)),
                  Text(steps[i].$2, style: const TextStyle(fontSize: 12, color: PColors.slate)),
                ]),
              ),
            ),
          ]),
      ]),
    );
  }
}

/// Already have USDC? Send it straight to your own wallet (no checkout, no fee).
class _OwnWalletCard extends StatelessWidget {
  const _OwnWalletCard();
  @override
  Widget build(BuildContext context) {
    final addr = context.watch<AppState>().address;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: addr == null
            ? null
            : () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (c) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Send USDC to your wallet', style: display(22, weight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        const Text('From Binance, Coinbase or any wallet. Choose the Base network.', textAlign: TextAlign.center, style: TextStyle(color: PColors.slate)),
                        const SizedBox(height: 16),
                        QrImageView(
                          data: addr!,
                          size: 200,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: PColors.navy),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: PColors.navy),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(_AddMoneyScreenState._chunk(addr!), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, height: 1.5)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: addr!));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet address copied')));
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copy my address'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _Notice(icon: Icons.warning_amber_rounded, color: PColors.clay, bg: PColors.clayTint, text: 'Only USDC on Base. Other tokens or networks can’t be recovered.'),
                      ]),
                    ),
                  ),
                ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: PColors.line)),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: PColors.blueTint, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.qr_code_2_rounded, color: PColors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Already have USDC?', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(addr == null ? 'Create your wallet first (Wallet tab)' : 'Send it straight to your wallet. No fee, arrives in seconds.',
                    style: const TextStyle(fontSize: 12, color: PColors.slate)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: PColors.slate),
          ]),
        ),
      ),
    );
  }
}
