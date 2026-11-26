import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/image_saver.dart';
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
  String? _note; // feedback shown inside the sheet (a snackbar would sit behind it)

  Pot get pot => widget.pot;

  String get _slug => pot.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

  String get _fileName => 'potfolio-${_slug.isEmpty ? 'pot' : _slug}';

  /// Renders the preview card to PNG bytes at 3x for a sharp image.
  Future<Uint8List> _capture() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _card.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> _saveImage() async {
    setState(() => _busy = true);
    try {
      final msg = await saveImage(await _capture(), _fileName);
      _toast(msg);
      if (mounted) await context.read<AppState>().markShared();
    } catch (e) {
      _toast(_reason(e, 'Couldn’t save the image. Try again.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _reason(Object e, String fallback) {
    final m = e.toString().replaceFirst('Exception: ', '');
    return m.length < 120 && !m.contains('Error') ? m : fallback;
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

  /// System share sheet with the image and the link together.
  Future<void> _more() async {
    final link = await _ensureLink();
    if (link == null) return;
    final text = 'I’m saving for “${pot.name}” with Potfolio. See my plan: $link';
    try {
      final bytes = await _capture();
      await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'image/png', name: '$_fileName.png')], text: text, subject: pot.name);
    } catch (_) {
      await Share.share(text, subject: pot.name);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    setState(() => _note = m);
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
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              ),
            ),
          ]),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: PColors.navy, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(_note!, style: const TextStyle(color: Colors.white, fontSize: 13))),
              ]),
            ),
          ],
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
