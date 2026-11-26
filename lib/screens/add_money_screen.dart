import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/checkout_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/stock_widgets.dart';

/// Add money with Light checkout: pay in local currency (bank transfer,
/// mobile money) or USDC on Base; Light settles to Potfolio in USDC.
class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key});
  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  double _amount = 50;
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

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  CheckoutService get _co => context.read<AppState>().checkout;

  Future<void> _start() async {
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

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final v = await _co.view(_secret!);
        if (!mounted) return;
        setState(() => _view = v);
        if (v.isFinal) {
          _poll?.cancel();
          if (v.status == 'completed') context.read<AppState>().refreshBalances();
        }
      } catch (_) {}
    });
    _tick?.cancel();
    final exp = _view?.payment?.expiresAt;
    final now = _view?.now;
    if (exp != null && now != null) {
      final offset = DateTime.now().difference(now);
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _left = exp.difference(DateTime.now().subtract(offset)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = context.read<AppState>().checkout.available;
    return Scaffold(
      appBar: AppBar(title: const Text('Add money')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          if (!available)
            const PCard(
              color: PColors.blueTint,
              child: Text('Add money needs the Potfolio server (Cloudflare Worker) with Light API keys. Until it’s connected, you can still receive USDC on Base from the Wallet tab.',
                  style: TextStyle(height: 1.5)),
            )
          else if (_view == null)
            ..._amountStep()
          else if (_view!.payment == null && !_view!.isFinal)
            ..._chooseStep()
          else
            ..._payStep(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: PColors.loss)),
          ],
          const SizedBox(height: 24),
          const Center(child: Tag('Powered by Light', bg: PColors.mist, fg: PColors.slate)),
        ]),
      ),
    );
  }

  List<Widget> _amountStep() => [
        Text('How much?', style: display(28)),
        const SizedBox(height: 6),
        const Text('You’ll receive this amount as USDC in your Potfolio balance.', style: TextStyle(color: PColors.slate)),
        const SizedBox(height: 16),
        PCard(
          child: Column(children: [
            Text(money(_amount), style: display(44)),
            Slider(value: _amount, min: 5, max: 2000, divisions: 399, onChanged: (v) => setState(() => _amount = v.roundToDouble())),
            Wrap(spacing: 8, children: [
              for (final v in [10.0, 25.0, 50.0, 100.0, 250.0])
                ChoiceChip(label: Text(money(v).replaceAll('.00', '')), selected: _amount == v, onSelected: (_) => setState(() => _amount = v), showCheckmark: false),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _start,
          child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Continue'),
        ),
      ];

  List<Widget> _chooseStep() {
    final opts = _view!.options;
    final needsPhone = _method == 'mobile_money' || _method == 'lipa_namba';
    return [
      Text('How do you want to pay?', style: display(26)),
      const SizedBox(height: 14),
      for (final o in opts)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PCard(
            color: _option == o ? PColors.blueTint : Colors.white,
            onTap: () => setState(() {
              _option = o;
              _method = o.methods.isNotEmpty ? o.methods.first : null;
            }),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${o.currency}${o.country != null ? ' · ${o.country}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(o.methods.map(_label).join(', '), style: const TextStyle(fontSize: 13, color: PColors.slate)),
                ]),
              ),
              Text('≈ ${money(o.value, o.currency)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      if (_option != null && _option!.methods.length > 1)
        Wrap(spacing: 8, children: [
          for (final m in _option!.methods) ChoiceChip(label: Text(_label(m)), selected: _method == m, onSelected: (_) => setState(() => _method = m), showCheckmark: false),
        ]),
      if (needsPhone) ...[
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', hintText: '254712345678')),
      ],
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy || _option == null ? null : _pay, child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Get payment details')),
    ];
  }

  List<Widget> _payStep() {
    final v = _view!;
    final p = v.payment;
    if (v.status == 'completed') {
      return [
        const SizedBox(height: 24),
        const Center(child: Icon(Icons.check_circle_rounded, color: PColors.gain, size: 72)),
        const SizedBox(height: 16),
        Center(child: Text('Money received', style: display(26))),
        const SizedBox(height: 8),
        const Center(child: Text('Your balance updates in a moment.', style: TextStyle(color: PColors.slate))),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ];
    }
    if (v.isFinal) {
      return [
        const SizedBox(height: 24),
        const Center(child: Icon(Icons.error_outline_rounded, color: PColors.clay, size: 64)),
        const SizedBox(height: 12),
        Center(child: Text('Payment ${v.status}', style: display(24))),
        const SizedBox(height: 20),
        FilledButton(onPressed: () => setState(() {
          _view = null;
          _secret = null;
        }), child: const Text('Try again')),
      ];
    }
    final mins = _left.inMinutes.clamp(0, 999);
    final secs = (_left.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');
    return [
      Text('Send exactly', style: display(18, weight: FontWeight.w600, color: PColors.slate)),
      Text(p == null ? '—' : _fmt(p), style: display(34)),
      const SizedBox(height: 4),
      if (_left > Duration.zero) Text('Expires in $mins:$secs', style: const TextStyle(color: PColors.clay, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),
      if (p != null)
        PCard(
          child: Column(children: [
            if (p.method == 'wallet_transfer') ...[
              _copyRow('USDC address', p.accountNumber),
              _copyRow('Network', p.bankName),
            ] else ...[
              _copyRow('Bank', p.bankName),
              _copyRow('Account name', p.accountName),
              _copyRow('Account number', p.accountNumber),
              _copyRow('Reference', p.reference),
              _copyRow('Lipa Namba', p.lipaNamba),
            ],
          ]),
        ),
      if (p?.note != null) ...[const SizedBox(height: 12), GuardianNote(p!.note!, title: 'Note')],
      if (p?.method == 'wallet_transfer') ...[const SizedBox(height: 12), const GuardianNote('Send USDC on Base only. Other tokens or networks are lost.', title: 'Heads up')],
      const SizedBox(height: 20),
      const Row(children: [
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 12),
        Text('Waiting for your payment…', style: TextStyle(color: PColors.slate)),
      ]),
    ];
  }

  Widget _copyRow(String k, String? v) {
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: const TextStyle(fontSize: 12, color: PColors.slate)),
            SelectableText(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
        IconButton(
          tooltip: 'Copy $k',
          icon: const Icon(Icons.copy_rounded, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: v));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$k copied')));
          },
        ),
      ]),
    );
  }

  String _fmt(PaymentInstructions p) => p.currency == 'USDC' ? '${p.value.toStringAsFixed(2)} USDC' : money(p.value, p.currency);

  String _label(String m) => const {
        'bank_transfer': 'Bank transfer',
        'mobile_money': 'Mobile money',
        'lipa_namba': 'Lipa Namba',
        'wallet_transfer': 'USDC on Base',
      }[m] ??
      m;
}
