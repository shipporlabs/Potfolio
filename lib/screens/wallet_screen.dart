import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/stock_widgets.dart';
import 'add_money_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    await context.read<AppState>().createWallet();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _backup() async {
    final s = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Show your private key?'),
        content: const Text('Anyone with this key can move everything in your wallet. Never share it, and never type it into a website. Write it down and keep it somewhere safe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('I understand, show it')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final key = await s.wallet.exportPrivateKey();
    if (!mounted || key == null) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Private key', style: display(22)),
          const SizedBox(height: 12),
          SelectableText(key, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          const SizedBox(height: 16),
          const GuardianNote('Keep this offline. Potfolio can’t recover it for you.', title: 'Important'),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final a = s.address;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet'), actions: [
        if (a != null) IconButton(tooltip: 'Refresh balance', onPressed: s.refreshBalances, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        if (a == null) ...[
          PCard(
            color: PColors.cream,
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const PotfolioMark(size: 72, background: PColors.cream),
              const SizedBox(height: 16),
              Text('Your own Base wallet', style: display(24), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Created on this device in a second. Use it to receive USDC and hold tokenized stocks. Only you hold the key.',
                  textAlign: TextAlign.center, style: TextStyle(color: PColors.slate, height: 1.5)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Create my wallet'),
              ),
            ]),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: PColors.navy, borderRadius: BorderRadius.circular(26)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const PotfolioMark(size: 28, palette: MarkPalette.onNavy, background: PColors.navy),
                const SizedBox(width: 10),
                Text(AppConfig.networkName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const Spacer(),
                Tag('USDC', bg: Colors.white.withValues(alpha: 0.12), fg: Colors.white),
              ]),
              const SizedBox(height: 18),
              const Text('Balance', style: TextStyle(color: Color(0xFFA8B6D4), fontSize: 13)),
              Text(s.usdc == null ? '—' : money(s.usdc!), style: display(38, color: Colors.white)),
              if (s.funded != null) ...[
                const SizedBox(height: 6),
                Text('Added via checkout: ${money(s.funded!)}', style: const TextStyle(color: Color(0xFFA8B6D4), fontSize: 13)),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMoneyScreen())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add money'),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          PCard(
            child: Column(children: [
              const Text('Receive on Base', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: PColors.line)),
                child: QrImageView(data: a, size: 200, eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: PColors.navy), dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: PColors.navy)),
              ),
              const SizedBox(height: 14),
              SelectableText(a, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: a));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied')));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('${AppConfig.explorer}/address/$a'), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Basescan'),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          GuardianNote('Only send USDC on ${AppConfig.networkName} to this address. Other tokens or networks can be lost.', title: 'Heads up'),
          const SizedBox(height: 14),
          PCard(
            onTap: _backup,
            child: const Row(children: [
              Icon(Icons.key_rounded, color: PColors.navy),
              SizedBox(width: 12),
              Expanded(child: Text('Back up your wallet', style: TextStyle(fontWeight: FontWeight.w600))),
              Icon(Icons.chevron_right_rounded),
            ]),
          ),
        ],
      ]),
    );
  }
}
