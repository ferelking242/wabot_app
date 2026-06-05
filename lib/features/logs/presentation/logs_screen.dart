import 'package:flutter/material.dart';
import '../../../shared/widgets/page_scaffold.dart';

const _g = Color(0xFF25D366); const _ink = Color(0xFFF2F3F5);
const _muted = Color(0xFF8A9199); const _border = Color(0xFF1E2128);

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});
  static const _logs = [
    _L('14:32:01','INFO',  'Message envoyé à +33612345678'),
    _L('14:31:55','INFO',  'Webhook déclenché: message.received'),
    _L('14:30:10','WARN',  'Session session-3 déconnectée'),
    _L('14:29:03','ERROR', 'Timeout webhook: https://api.example.com/hook'),
    _L('14:28:44','INFO',  'Message reçu de +33798765432'),
    _L('14:27:11','INFO',  'Automation "Bonjour" déclenchée'),
    _L('14:26:33','INFO',  'Clé API validée pour client-abc'),
    _L('14:25:01','ERROR', 'Connexion WebSocket perdue: session-3'),
  ];
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: "Logs d'activité",
    subtitle: 'Temps réel · ${_logs.length} entrées',
    actions: [
      ActionButton(label: 'Exporter', icon: Icons.download_outlined, onTap: () {}),
      const SizedBox(width: 8),
      ActionButton(label: 'Vider', icon: Icons.delete_sweep_outlined, onTap: () {}),
    ],
    child: Container(
      decoration: BoxDecoration(color: const Color(0xFF080A0C), borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: Column(children: _logs.map((l) => _LogRow(l: l)).toList()),
    ),
  );
}

class _L { final String t, lvl, msg; const _L(this.t, this.lvl, this.msg); }

class _LogRow extends StatelessWidget {
  final _L l;
  const _LogRow({required this.l});
  Color get _c => l.lvl == 'ERROR' ? const Color(0xFFFF6B6B) : l.lvl == 'WARN' ? const Color(0xFFF59E0B) : const Color(0xFF25D366);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(children: [
      Text(l.t, style: const TextStyle(fontSize: 11, color: Color(0xFF4A5568), fontFamily: 'monospace')),
      const SizedBox(width: 10),
      Container(width: 46, alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(color: _c.withOpacity(.12), borderRadius: BorderRadius.circular(4)),
        child: Text(l.lvl, style: TextStyle(fontSize: 10, color: _c, fontWeight: FontWeight.w800))),
      const SizedBox(width: 10),
      Expanded(child: Text(l.msg, style: const TextStyle(fontSize: 12, color: Color(0xFFD1D5DB), fontFamily: 'monospace'))),
    ]),
  );
}
