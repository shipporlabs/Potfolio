import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../services/trade_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/stock_widgets.dart';
import 'add_money_screen.dart';

double units(BigInt raw, int decimals) => raw.toDouble() / math.pow(10, decimals);

String fmtUnits(double u) => u >= 100 ? u.toStringAsFixed(2) : (u >= 1 ? u.toStringAsFixed(4) : u.toStringAsPrecision(4));

/// Tokenized stocks are for eligible people outside the US. Asked once.
Future<bool> ensureEligible(BuildContext context) async {
  final s = context.read<AppState>();
  if (s.eligible) return true;
  var ticked = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Before your first trade'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Tokenized stocks are real shares held by a regulated custodian, issued as tokens on Base. They give price exposure, not voting rights. '
            'They aren’t available to US persons or in places where they aren’t allowed. Prices can fall and you can lose money.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: ticked,
            onChanged: (v) => set(() => ticked = v ?? false),
            title: const Text('I’m not a US person, and tokenized stocks are allowed where I live.', style: TextStyle(fontSize: 14)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: ticked ? () => Navigator.pop(c, true) : null, child: const Text('Continue')),
        ],
      ),
    ),
  );
  if (ok == true) await s.confirmEligible();
  return ok == true;
}

/// Runs a trade job with a live progress dialog, then shows the result.
Future<T?> runTrade<T>(BuildContext context, String title, Future<T> Function(void Function(String step) onStep) job, {String Function(T result)? done, List<String> Function(T result)? hashes}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TradeProgress<T>(title: title, job: job, done: done, hashes: hashes),
  );
}

class _TradeProgress<T> extends StatefulWidget {
  final String title;
  final Future<T> Function(void Function(String)) job;
  final String Function(T)? done;
  final List<String> Function(T)? hashes;
  const _TradeProgress({super.key, required this.title, required this.job, this.done, this.hashes});
  @override
  State<_TradeProgress<T>> createState() => _TradeProgressState<T>();
}

class _TradeProgressState<T> extends State<_TradeProgress<T>> {
  String _step = 'Starting';
  T? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.job((st) {
      if (mounted) setState(() => _step = st);
    }).then((r) {
      if (mounted) setState(() => _result = r);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e is TradeFailed ? e.message : 'Something went wrong: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final finished = _result != null || _error != null;
    final hashes = _result != null && widget.hashes != null ? widget.hashes!(_result as T) : const <String>[];
    return PopScope(
      canPop: finished,
      child: AlertDialog(
        title: Text(_error != null ? 'Trade stopped' : (_result != null ? 'Done' : widget.title)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!finished) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 14),
            Text(_step, style: const TextStyle(color: PColors.slate)),
            const SizedBox(height: 6),
            const Text('Keep the app open. Network fees are on Potfolio.', style: TextStyle(fontSize: 12, color: PColors.slate)),
          ],
          if (_error != null) Text(_error!, style: const TextStyle(height: 1.4)),
          if (_result != null) ...[
            Row(children: [
              const Icon(Icons.check_circle_rounded, color: PColors.gain),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.done?.call(_result as T) ?? 'Your trade went through.', style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35))),
            ]),
            for (final h in hashes.take(6))
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                onPressed: () => launchUrl(Uri.parse('${AppConfig.explorer}/tx/$h'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text('Basescan · ${h.substring(0, 10)}…'),
              ),
          ],
        ]),
        actions: [
          if (finished) FilledButton(onPressed: () => Navigator.of(context).pop(_result), child: const Text('Close')),
        ],
      ),
    );
  }
}

/// Buy or sell one tokenized stock.
Future<void> showTradeSheet(BuildContext context, Stock stock, {required bool buy}) async {
  final s = context.read<AppState>();
  if (!AppConfig.tradingEnabled) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trading runs on Base mainnet. This build is a test version.')));
    return;
  }
  if (s.address == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create your Base wallet first (Wallet tab).')));
    return;
  }
  if (!await ensureEligible(context)) return;
  if (!context.mounted) return;
  await s.refreshBalances();
  final held = await s.holding(stock) ?? BigInt.zero;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TradeSheet(stock: stock, buy: buy, held: held),
  );
}

class _TradeSheet extends StatefulWidget {
  final Stock stock;
  final bool buy;
  final BigInt held;
  const _TradeSheet({required this.stock, required this.buy, required this.held});
  @override
  State<_TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends State<_TradeSheet> {
  final _ctl = TextEditingController();
  double _pct = 1; // sell: share of holding
  TradeQuote? _quote;
  bool _loading = false;
  String? _err;

  Stock get st => widget.stock;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  BigInt get _sellRaw => widget.buy
      ? BigInt.from(((double.tryParse(_ctl.text) ?? 0) * 1e6).floor())
      : (_pct >= 1 ? widget.held : BigInt.from((widget.held.toDouble() * _pct).floor()));

  Future<void> _review() async {
    final s = context.read<AppState>();
    final amt = _sellRaw;
    String? err;
    if (widget.buy && amt < BigInt.from(1000000)) err = 'The smallest buy is \$1.';
    if (widget.buy && amt.toDouble() / 1e6 > (s.usdc ?? 0)) err = 'You have ${money(s.usdc ?? 0)} USDC in your wallet.';
    if (!widget.buy && amt <= BigInt.zero) err = 'You don’t hold any ${st.symbol}.';
    if (err != null) {
      setState(() => _err = err);
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
      _quote = null;
    });
    try {
      final q = await s.trade.quote(side: widget.buy ? 'buy' : 'sell', token: st.contract!, amount: amt, taker: s.address!);
      if (mounted) setState(() => _quote = q);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final s = context.read<AppState>();
    final amt = _sellRaw;
    final nav = Navigator.of(context);
    final r = await runTrade<TradeResult>(
      context,
      widget.buy ? 'Buying ${st.symbol}' : 'Selling ${st.symbol}',
      (step) => widget.buy ? s.buyStock(st, amt.toDouble() / 1e6, onStep: step) : s.sellStock(st, amt, onStep: step),
      done: (r) => widget.buy
          ? 'You bought ${fmtUnits(units(r.bought, st.decimals))} ${st.symbol} for ${money(r.sold.toDouble() / 1e6)}.'
          : 'You sold ${fmtUnits(units(r.sold, st.decimals))} ${st.symbol} for ${money(r.bought.toDouble() / 1e6)}.',
      hashes: (r) => [r.hash],
    );
    if (r != null) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final q = _quote;
    final heldU = units(widget.held, st.decimals);
    double? estUnits, estUsd, perUnit;
    if (q != null) {
      if (widget.buy) {
        estUnits = units(q.buyAmount, st.decimals);
        perUnit = estUnits > 0 ? q.sellAmount.toDouble() / 1e6 / estUnits : null;
      } else {
        estUsd = q.buyAmount.toDouble() / 1e6;
        final u = units(q.sellAmount, st.decimals);
        perUnit = u > 0 ? estUsd / u : null;
      }
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          StockLogo(url: st.logo, fallback: st.name, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Text('${widget.buy ? 'Buy' : 'Sell'} ${st.name}', style: display(22, weight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        Text(
          widget.buy ? 'USDC in your wallet: ${money(s.usdc ?? 0)}' : 'You hold ${fmtUnits(heldU)} ${st.symbol}',
          style: const TextStyle(color: PColors.slate),
        ),
        const SizedBox(height: 16),
        if (widget.buy) ...[
          TextField(
            controller: _ctl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?'))],
            style: display(28),
            decoration: const InputDecoration(prefixText: '\$ ', labelText: 'Amount in USDC'),
            onChanged: (_) => setState(() => _quote = null),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final v in [5.0, 10.0, 25.0, 50.0])
              ActionChip(label: Text('\$${v.toStringAsFixed(0)}'), onPressed: () => setState(() {
                    _ctl.text = v.toStringAsFixed(0);
                    _quote = null;
                  })),
            if ((s.usdc ?? 0) >= 1)
              ActionChip(label: const Text('Max'), onPressed: () => setState(() {
                    _ctl.text = (((s.usdc ?? 0) * 100).floor() / 100).toStringAsFixed(2);
                    _quote = null;
                  })),
          ]),
          if ((s.usdc ?? 0) < 1)
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMoneyScreen())),
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Add USDC to your wallet'),
            ),
        ] else ...[
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 0.25, label: Text('25%')),
              ButtonSegment(value: 0.5, label: Text('50%')),
              ButtonSegment(value: 1, label: Text('All')),
            ],
            selected: {_pct},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() {
              _pct = v.first;
              _quote = null;
            }),
          ),
          const SizedBox(height: 8),
          Text('Selling ${fmtUnits(units(_sellRaw, st.decimals))} ${st.symbol}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 14),
        if (q != null)
          PCard(
            color: PColors.blueTint,
            child: Column(children: [
              _line(widget.buy ? 'You get about' : 'You receive about', widget.buy ? '${fmtUnits(estUnits!)} ${st.symbol}' : money(estUsd!)),
              if (perUnit != null) _line('Price per token', money(perUnit)),
              _line(
                'At least',
                widget.buy ? '${fmtUnits(units(q.minBuyAmount, st.decimals))} ${st.symbol}' : money(q.minBuyAmount.toDouble() / 1e6),
              ),
              if (q.potfolioFee > BigInt.zero) _line('Potfolio fee', money(q.potfolioFee.toDouble() / 1e6)),
              _line('Network fee', 'Paid by Potfolio'),
              if (q.route.isNotEmpty) _line('Route', q.route.join(', ')),
            ]),
          ),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: PColors.loss, fontWeight: FontWeight.w600))),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _loading ? null : (q == null ? _review : _confirm),
          child: _loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(q == null ? 'Review' : (widget.buy ? 'Confirm buy' : 'Confirm sell')),
        ),
        const SizedBox(height: 8),
        const Text('Prices move. You’ll get at least the amount shown or the trade won’t go through. Not financial advice.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: PColors.slate)),
      ]),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(color: PColors.slate))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
