import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/stock_widgets.dart';
import 'stock_detail_screen.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});
  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  Market _m = Market.us;
  String _q = '';
  bool _watchOnly = false;
  late Future<List<Stock>> _f;

  @override
  void initState() {
    super.initState();
    _f = context.read<AppState>().stocks.list(_m);
  }

  void _pick(Market m) => setState(() {
        _m = m;
        _f = context.read<AppState>().stocks.list(m);
      });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Markets')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search companies or tickers'),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final m in Market.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('${m.flag}  ${m.label}'),
                  selected: _m == m,
                  onSelected: (_) => _pick(m),
                  selectedColor: PColors.navy,
                  labelStyle: TextStyle(color: _m == m ? Colors.white : PColors.navy, fontWeight: FontWeight.w600),
                  showCheckmark: false,
                  side: const BorderSide(color: PColors.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: const Text('★ Watchlist'),
                selected: _watchOnly,
                onSelected: (v) => setState(() => _watchOnly = v),
                showCheckmark: false,
                side: const BorderSide(color: PColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: _m == Market.us
              ? const _Banner(Icons.verified, PColors.blueTint, PColors.blue, 'Verified stocks are tokenized on Base and can go in your pots. Prices are Chainlink reference values.')
              : _Banner(Icons.visibility_outlined, PColors.mist, PColors.slate, '${_m.label} stocks are watch-only for now. Prices are delayed and need a data key on the server.'),
        ),
        Expanded(
          child: FutureBuilder<List<Stock>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return const Center(child: CircularProgressIndicator());
              var list = snap.data ?? [];
              if (_q.isNotEmpty) list = list.where((x) => x.name.toLowerCase().contains(_q) || x.symbol.toLowerCase().contains(_q)).toList();
              if (_watchOnly) list = list.where((x) => s.watchlist.contains(x.symbol)).toList();
              if (list.isEmpty) return const Center(child: Text('Nothing here yet.', style: TextStyle(color: PColors.slate)));
              return RefreshIndicator(
                onRefresh: () async => setState(() => _f = s.stocks.list(_m, refresh: true)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: PColors.line),
                  itemBuilder: (_, i) => StockTile(
                    stock: list[i],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StockDetailScreen(stock: list[i]))),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color bg, fg;
  final String text;
  const _Banner(this.icon, this.bg, this.fg, this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: PColors.navy))),
        ]),
      );
}

