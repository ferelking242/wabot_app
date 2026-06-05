import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/widgets/page_scaffold.dart';

const _g = Color(0xFF25D366); const _gd = Color(0xFF128C7E);
const _ink = Color(0xFFF2F3F5); const _muted = Color(0xFF8A9199);
const _border = Color(0xFF1E2128); const _card = Color(0xFF111316);

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override State<SessionsScreen> createState() => _SS();
}
class _SS extends State<SessionsScreen> {
  final _sessions = <_Sess>[
    _Sess('+33 6 12 34 56 78', true,  432),
    _Sess('+33 7 98 76 54 32', true,  815),
    _Sess('+242 06 001 0001',  false, 0),
  ];

  @override
  Widget build(BuildContext context) {
    final active = _sessions.where((s) => s.connected).length;
    return PageScaffold(
      title: 'Sessions WhatsApp',
      subtitle: '$active connectée${active > 1 ? "s" : ""}',
      actions: [ActionButton(label: 'Nouvelle session', icon: Icons.add_rounded, primary: true, onTap: () => _qr(context))],
      child: Column(children: [
        for (final s in _sessions) ...[_SessionCard(sess: s, onDelete: () => setState(() => _sessions.remove(s))), const SizedBox(height: 10)],
      ]),
    );
  }

  void _qr(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => Dialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Scanner le QR Code', style: TextStyle(fontSize: 16, color: _ink, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('WhatsApp → Appareils liés → Lier un appareil', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: QrImageView(data: 'wabot://new/${DateTime.now().millisecondsSinceEpoch}', version: QrVersions.auto, size: 200, backgroundColor: Colors.white)),
        const SizedBox(height: 14),
        Text('En attente de scan…', style: TextStyle(color: _g.withOpacity(.85), fontSize: 12)),
      ])),
    ));
  }
}

class _Sess { final String phone; bool connected; final int msgs; _Sess(this.phone, this.connected, this.msgs); }

class _SessionCard extends StatelessWidget {
  final _Sess sess; final VoidCallback onDelete;
  const _SessionCard({required this.sess, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
    child: Row(children: [
      Container(width: 44, height: 44,
        decoration: BoxDecoration(color: sess.connected ? _g.withOpacity(.15) : Colors.white10, borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.phone_android_rounded, size: 22, color: sess.connected ? _g : _muted)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(sess.phone, style: const TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: sess.connected ? _g : Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(sess.connected ? 'Connectée · ${sess.msgs} msgs' : 'Déconnectée', style: const TextStyle(fontSize: 11.5, color: _muted)),
        ]),
      ])),
      IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFFF6B6B)), onPressed: onDelete),
    ]),
  );
}
