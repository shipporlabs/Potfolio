import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../services/stocks_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/stock_widgets.dart';
import 'create_pot_screen.dart';
import 'trade_sheet.dart';

class StockDetailScreen extends StatelessWidget {
  final Stock stock;
  const StockDetailScreen({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final watching = s.watchlist.contains(stock.symbol);
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
          tooltip: watching ? 'Remove from watchlist' : 'Add to watchlist',
          onPressed: () => s.toggleWatch(stock.symbol),
          icon: Icon(watching ? Icons.star_rounded : Icons.star_outline_rounded, color: watching ? PColors.blue : null),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
        Row(children: [
          StockLogo(url: stock.logo, fallback: stock.name, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stock.name, style: display(22, weight: FontWeight.w700)),
              Text('${stock.symbol} · ${stock.exchange} · ${stock.market.label}', style: const TextStyle(color: PColors.slate)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        FutureBuilder<HistoryResult>(
          future: stock.price == null ? s.stocks.history(stock) : null,
          builder: (context, snap) {
            // Not every stock has a live quote; fall back to the last daily close.
            final last = (snap.data?.points.isNotEmpty ?? false) ? snap.data!.points.last : null;
            final text = stock.price != null
                ? money(stock.price!, stock.currency)
                : last != null
                    ? money(last, stock.currency)
                    : (snap.connectionState == ConnectionState.waiting ? '…' : 'Price unavailable');
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(text, style: display(36)),
              if (stock.price == null && last != null)
                const Text('Last close', style: TextStyle(color: PColors.slate, fontSize: 13)),
            ]);
          },
        ),
        const SizedBox(height: 4),
        Row(children: [
          if (stock.changePct != null)
            Text('${pct(stock.changePct!)} today', style: TextStyle(fontWeight: FontWeight.w600, color: stock.changePct! >= 0 ? PColors.gain : PColors.loss)),
          if (stock.priceAt != null) ...[
            const SizedBox(width: 8),
            Text('as of ${DateFormat('d MMM, HH:mm').format(stock.priceAt!.toLocal())}', style: const TextStyle(color: PColors.slate, fontSize: 13)),
          ],
        ]),
        const SizedBox(height: 16),
        FutureBuilder<HistoryResult>(
          future: s.stocks.history(stock),
          builder: (context, snap) {
            final pts = snap.data?.points ?? const <double>[];
            if (pts.length < 2) {
              return Container(
                height: 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: PColors.line)),
                child: Text(snap.connectionState == ConnectionState.waiting ? 'Loading chart…' : (snap.data?.message ?? 'No chart for this stock yet.'),
                    style: const TextStyle(color: PColors.slate)),
              );
            }
            final up = pts.last >= pts.first;
            return SizedBox(
              height: 180,
              child: LineChart(LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i])],
                    isCurved: true,
                    color: up ? PColors.blue : PColors.loss,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: (up ? PColors.blue : PColors.loss).withValues(alpha: 0.08)),
                  ),
                ],
              )),
            );
          },
        ),
        const SizedBox(height: 20),
        PCard(
          child: Column(children: [
            _Row('Market', '${stock.market.flag} ${stock.market.label}'),
            _Row('Exchange', stock.exchange),
            _Row('Sector', stock.sector[0].toUpperCase() + stock.sector.substring(1)),
            _Row('On Base', stock.investable ? 'Yes, tokenized' : 'Not yet'),
            if (stock.contract != null && stock.contract!.isNotEmpty) _Row('Contract', '${stock.contract!.substring(0, 6)}…${stock.contract!.substring(stock.contract!.length - 4)}'),
          ]),
        ),
        const SizedBox(height: 14),
        if (stock.investable)
          const GuardianNote('A tokenized stock tracks a real share held by a custodian. It gives price exposure, not voting rights.', title: 'Good to know'),
        const SizedBox(height: 20),
        if (stock.investable && AppConfig.tradingEnabled) ...[
          FutureBuilder<BigInt?>(
            future: s.holding(stock),
            builder: (context, snap) {
              final held = snap.data ?? BigInt.zero;
              final u = units(held, stock.decimals);
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (held > BigInt.zero)
                  PCard(
                    child: Row(children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: PColors.blue),
                      const SizedBox(width: 12),
                      Expanded(child: Text('You hold ${fmtUnits(u)} ${stock.symbol}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      if (stock.price != null) Text('≈ ${money(u * stock.price!)}', style: const TextStyle(color: PColors.slate)),
                    ]),
                  ),
                if (held > BigInt.zero) const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => showTradeSheet(context, stock, buy: true),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Buy'),
                    ),
                  ),
                  if (held > BigInt.zero) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showTradeSheet(context, stock, buy: false),
                        icon: const Icon(Icons.remove_rounded),
                        label: const Text('Sell'),
                        style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 10),
              ]);
            },
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatePotScreen(preselect: stock))),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Or build a pot with this stock'),
          ),
        ] else if (stock.investable)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatePotScreen(preselect: stock))),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Build a pot with this stock'),
          )
        else
          OutlinedButton.icon(
            onPressed: () => s.toggleWatch(stock.symbol),
            icon: Icon(watching ? Icons.star_rounded : Icons.star_outline_rounded),
            label: Text(watching ? 'On your watchlist' : 'Add to watchlist'),
          ),
        if (stock.contract != null && stock.contract!.isNotEmpty) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => launchUrl(Uri.parse('${AppConfig.explorer.replaceAll('sepolia.', '')}/token/${stock.contract}'), mode: LaunchMode.externalApplication),
            child: const Text('View token on Basescan'),
          ),
        ],
        const SizedBox(height: 8),
        const Text(disclaimer, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: PColors.slate)),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String k, v;
  const _Row(this.k, this.v);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Text(k, style: const TextStyle(color: PColors.slate)),
          const SizedBox(width: 16),
          Expanded(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
