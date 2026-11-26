import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../theme.dart';

final _usd = NumberFormat.simpleCurrency(name: 'USD');
String money(double v, [String currency = 'USD']) {
  if (currency == 'USD') return _usd.format(v);
  final sym = const {'NGN': '₦', 'EUR': '€', 'GBP': '£', 'KES': 'KSh '}[currency] ?? '$currency ';
  return '$sym${NumberFormat('#,##0.00').format(v)}';
}

String pct(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';

/// Round company logo on a white disc, with a letter fallback.
class StockLogo extends StatelessWidget {
  final String url;
  final String fallback;
  final double size;
  const StockLogo({super.key, required this.url, required this.fallback, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final letter = Center(
      child: Text(fallback.isEmpty ? '?' : fallback[0],
          style: TextStyle(fontWeight: FontWeight.w800, color: PColors.navy, fontSize: size * 0.4)),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: PColors.line)),
      padding: EdgeInsets.all(size * 0.2),
      child: ClipOval(
        child: url.isEmpty
            ? letter
            : Image.network(
                url,
                fit: BoxFit.contain,
                // Decode at display size, not the source size.
                cacheWidth: (size * 3).round(),
                gaplessPlayback: true,
                // Show the letter until the logo arrives.
                frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : letter,
                errorBuilder: (_, __, ___) => letter,
                semanticLabel: '$fallback logo',
              ),
      ),
    );
  }
}

class LogoStack extends StatelessWidget {
  final List<String> urls;
  final List<String> names;
  final double size;
  const LogoStack({super.key, required this.urls, required this.names, this.size = 28});
  @override
  Widget build(BuildContext context) {
    final n = urls.length.clamp(0, 5).toInt();
    return SizedBox(
      width: n == 0 ? 0.0 : size + (n - 1) * size * 0.7,
      height: size,
      child: Stack(children: [
        for (var i = 0; i < n; i++)
          Positioned(left: i * size * 0.7, child: StockLogo(url: urls[i], fallback: names[i], size: size)),
      ]),
    );
  }
}

class StockTile extends StatelessWidget {
  final Stock stock;
  final VoidCallback? onTap;
  final Widget? trailing;
  const StockTile({super.key, required this.stock, this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) {
    final ch = stock.changePct;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          StockLogo(url: stock.logo, fallback: stock.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(stock.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                if (stock.investable) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, size: 14, color: PColors.blue),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${stock.symbol} · ${stock.exchange}', style: const TextStyle(fontSize: 12, color: PColors.slate)),
            ]),
          ),
          trailing ??
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(stock.price != null ? money(stock.price!, stock.currency) : '—',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(height: 2),
                if (ch != null)
                  Text(pct(ch), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ch >= 0 ? PColors.gain : PColors.loss)),
                else
                  Text(stock.investable ? 'On Base' : 'Watch', style: const TextStyle(fontSize: 12, color: PColors.slate)),
              ]),
        ]),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Row(children: [
          Expanded(child: Text(title, style: display(20, weight: FontWeight.w700))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      );
}
