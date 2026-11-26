import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/share_card.dart';

/// Share a pot as an image or as a public read-only link.
Future<void> showSharePot(BuildContext context, Pot pot) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: PColors.mist,
      builder: (_) => _ShareSheet(pot: pot),
    );

class _ShareSheet extends StatefulWidget {
  final Pot pot;
  const _ShareSheet({required this.pot});
  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _card = GlobalKey();
  bool _amounts = false;
  bool _busy = false;
  String? _link;

  Pot get pot => widget.pot;

  String get _slug => pot.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

  Future<void> _saveImage() async {
    setState(() => _busy = true);
    try {
      final boundary = _card.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'potfolio-${_slug.isEmpty ? 'pot' : _slug}.png')],
        text: 'My ${pot.name} pot on Potfolio',
      );
      if (mounted) await context.read<AppState>().markShared();
    } catch (_) {
      _toast('Couldn’t create the image. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _snapshot() {
    final s = context.read<AppState>();
    final plan = pot.plan();
    return {
      'name': pot.name,
      'goal': pot.goal.label,
      'template': pot.templateId,
      'showAmounts': _amounts,
      'createdAt': pot.createdAt.toIso8601String(),
      'allocations': pot.allocations.map((a) => {'symbol': a.symbol, 'name': a.name, 'weight': a.weight.round(), 'logo': a.logo}).toList(),
      if (plan != null) ...{
        'progress': double.parse(plan.progress.toStringAsFixed(4)),
        'targetDate': plan.targetDate.toIso8601String(),
        'frequency': pot.frequency.name,
        'reached': plan.reached,
        if (_amounts) ...{
          'target': plan.target,
          'invested': plan.invested,
          'perPeriod': plan.perPeriod,
        },
      },
      if (_amounts) 'value': double.parse(pot.valueNow(s.stocks.priceMap()).toStringAsFixed(2)),
    };
  }

  Future<String?> _ensureLink() async {
    if (_link != null) return _link;
    setState(() => _busy = true);
    try {
      final link = await context.read<AppState>().sharePotLink(_snapshot());
      if (mounted) setState(() => _link = link);
      return link;
    } catch (e) {
      _toast('Couldn’t create a link. Sign in and check your connection.');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    final link = await _ensureLink();
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    _toast('Link copied');
  }

  Future<void> _whatsApp() async {
    final link = await _ensureLink();
    if (link == null) return;
    final text = Uri.encodeComponent('I’m saving for “${pot.name}” with Potfolio. See my plan: $link');
    await launchUrl(Uri.parse('https://wa.me/?text=$text'), mode: LaunchMode.externalApplication);
  }

  Future<void> _more() async {
    final link = await _ensureLink();
    if (link == null) return;
    await Share.share('I’m saving for “${pot.name}” with Potfolio. See my plan: $link', subject: pot.name);
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final h = MediaQuery.of(context).size.height;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Share this pot', style: display(22, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Friends see your goal and mix. Amounts stay hidden unless you show them.', style: TextStyle(color: PColors.slate)),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.48),
            child: FittedBox(
              fit: BoxFit.contain,
              child: RepaintBoundary(
                key: _card,
                child: PotShareCard(pot: pot, showAmounts: _amounts, valueNow: pot.valueNow(s.stocks.priceMap())),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _amounts,
            onChanged: _busy
                ? null
                : (v) => setState(() {
                      _amounts = v;
                      _link = null; // a new snapshot is needed
                    }),
            title: const Text('Show amounts', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Target, saved and per-deposit amounts'),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _saveImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Save image'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _copyLink,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Copy link'),
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _whatsApp,
                icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                label: const Text('WhatsApp'),
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _more,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('More'),
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              ),
            ),
          ]),
          if (_link != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: PColors.line)),
              child: Row(children: [
                const Icon(Icons.public_rounded, size: 18, color: PColors.slate),
                const SizedBox(width: 8),
                Expanded(child: SelectableText(_link!, style: const TextStyle(fontSize: 13))),
              ]),
            ),
          ],
          if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        ]),
      ),
    );
  }
}
