import 'package:flutter/material.dart';

const _card   = Color(0xFF111316);
const _border = Color(0xFF1E2128);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _green  = Color(0xFF25D366);

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final String? trend;
  final Color? color;
  const StatCard({super.key, required this.icon, required this.label, required this.value, this.trend, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? _green;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.22), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: c.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: c)),
          const Spacer(),
          if (trend != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: c.withOpacity(.15), borderRadius: BorderRadius.circular(99)),
            child: Text(trend!, style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 11.5, color: _muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 26, color: _ink, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}
