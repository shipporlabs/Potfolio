import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/brand.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        PCard(
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: PColors.blueTint,
              child: Text((u?.name.isNotEmpty == true ? u!.name[0] : '?').toUpperCase(), style: display(22, color: PColors.blue)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u?.name.isNotEmpty == true ? u!.name : 'Investor', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(u?.email ?? '', style: const TextStyle(color: PColors.slate)),
              ]),
            ),
            if (s.auth.isDemo) const Tag('Demo', bg: PColors.clayTint, fg: PColors.clay),
          ]),
        ),
        const SizedBox(height: 16),
        PCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            _Item(Icons.lan_outlined, 'Network', AppConfig.networkName),
            _Item(Icons.cloud_outlined, 'Server', AppConfig.hasWorker ? 'Connected' : 'Not connected'),
            _Item(Icons.account_balance_wallet_outlined, 'Wallet', s.address == null ? 'Not created' : '${s.address!.substring(0, 6)}…${s.address!.substring(s.address!.length - 4)}'),
            _Item(Icons.star_outline_rounded, 'Watchlist', '${s.watchlist.length} stocks'),
          ]),
        ),
        const SizedBox(height: 16),
        const PCard(
          color: PColors.cream,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Our promises', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            SizedBox(height: 8),
            Text('• The Guardian explains, it never predicts.\n• Nothing is saved or signed without your tap.\n• Tokenized stocks give price exposure, not voting rights.\n• Your wallet key stays on your device.',
                style: TextStyle(height: 1.7, color: PColors.navy)),
          ]),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => s.auth.signOut(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log out'),
        ),
        const SizedBox(height: 20),
        const Center(child: Lockup(markSize: 26)),
        const SizedBox(height: 8),
        const Text('Potfolio is an educational tool, not financial advice or an offer to buy or sell securities. Tokenized stocks are available to eligible users outside the US.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: PColors.slate, height: 1.5)),
      ]),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String k, v;
  const _Item(this.icon, this.k, this.v);
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: PColors.navy),
        title: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(v, style: const TextStyle(color: PColors.slate)),
      );
}
