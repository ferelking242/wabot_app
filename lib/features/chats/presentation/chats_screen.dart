import 'package:flutter/material.dart';
import '../../../shared/widgets/page_scaffold.dart';

const _g = Color(0xFF25D366); const _gd = Color(0xFF128C7E);
const _ink = Color(0xFFF2F3F5); const _muted = Color(0xFF8A9199);
const _border = Color(0xFF1E2128); const _card = Color(0xFF111316);

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});
  static const _data = [
    ('+33 6 12 34 56 78', 'Bonjour, comment ça va ?',       '14:32', true),
    ('+33 7 98 76 54 32', 'Merci pour votre réponse !',      '13:10', false),
    ('+242 06 001 0001',  'Quand sera disponible...',         '11:45', true),
    ('+1 555 123 4567',   'Thanks for the quick reply',       '09:20', false),
    ('+44 20 7946 0958',  'Can you send me the info again?', '08:05', true),
  ];
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Conversations',
    subtitle: '${_data.length} conversations récentes',
    child: Column(children: [
      Container(height: 38, padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
        child: const Row(children: [
          Icon(Icons.search_rounded, size: 16, color: _muted),
          SizedBox(width: 8),
          Expanded(child: TextField(style: TextStyle(fontSize: 13, color: _ink),
            decoration: InputDecoration(hintText: 'Rechercher…', hintStyle: TextStyle(color: _muted, fontSize: 13),
              border: InputBorder.none, isCollapsed: true, contentPadding: EdgeInsets.symmetric(vertical: 10)))),
        ])),
      const SizedBox(height: 12),
      for (final c in _data) ...[
        _Row(phone: c.$1, preview: c.$2, time: c.$3, bot: c.$4),
        Container(height: 1, color: _border),
      ],
    ]),
  );
}

class _Row extends StatelessWidget {
  final String phone, preview, time; final bool bot;
  const _Row({required this.phone, required this.preview, required this.time, required this.bot});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Container(width: 44, height: 44,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_gd, _g]), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(phone.substring(1, 3), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(phone, style: const TextStyle(fontSize: 13.5, color: _ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _muted)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(time, style: const TextStyle(fontSize: 10.5, color: _muted)),
        if (bot) ...[const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _g.withOpacity(.15), borderRadius: BorderRadius.circular(99)),
            child: const Text('BOT', style: TextStyle(fontSize: 9, color: _g, fontWeight: FontWeight.w800)))],
      ]),
    ]),
  );
}
