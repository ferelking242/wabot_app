import 'package:flutter/material.dart';

class PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String label;
  const PlaceholderPage({super.key, required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 56, color: cs.onSurfaceVariant),
      const SizedBox(height: 12),
      Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Aucune donnée disponible', style: TextStyle(color: cs.onSurfaceVariant)),
    ]));
  }
}
