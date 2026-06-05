import 'package:flutter/material.dart';
import '../../../shared/widgets/page_scaffold.dart';

const _g = Color(0xFF25D366); const _ink = Color(0xFFF2F3F5);
const _muted = Color(0xFF8A9199); const _border = Color(0xFF1E2128); const _card = Color(0xFF111316);

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});
  @override State<AutomationScreen> createState() => _AS();
}
class _AS extends State<AutomationScreen> {
  final _rules = [
    _Rule('Bonjour automatique', 'Premier message',   'Envoyer un message',  true),
    _Rule('Hors bureau',         'Message la nuit',   'Répondre hors-bureau', true),
    _Rule('FAQ produit',         'Mot-clé: prix',     'Envoyer la grille',   false),
    _Rule('Accusé de réception', 'Tout message',      'Envoyer un lu ✓',     false),
  ];
  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Automations',
    subtitle: '${_rules.where((r) => r.active).length} règles actives',
    actions: [ActionButton(label: 'Nouvelle règle', icon: Icons.add_rounded, primary: true, onTap: () {})],
    child: Column(children: [
      for (final r in _rules) ...[
        _RuleCard(rule: r, onToggle: (v) => setState(() => r.active = v)),
        const SizedBox(height: 10),
      ],
    ]),
  );
}

class _Rule { final String name, trigger, action; bool active; _Rule(this.name, this.trigger, this.action, this.active); }

class _RuleCard extends StatelessWidget {
  final _Rule rule; final ValueChanged<bool> onToggle;
  const _RuleCard({required this.rule, required this.onToggle});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
    child: Row(children: [
      Container(width: 42, height: 42,
        decoration: BoxDecoration(color: rule.active ? _g.withOpacity(.15) : Colors.white10, borderRadius: BorderRadius.circular(11)),
        child: Icon(Icons.auto_fix_high_outlined, size: 20, color: rule.active ? _g : _muted)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rule.name, style: const TextStyle(fontSize: 13.5, color: _ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text('${rule.trigger} → ${rule.action}', style: const TextStyle(fontSize: 11.5, color: _muted)),
      ])),
      Switch(value: rule.active, onChanged: onToggle, activeColor: _g),
    ]),
  );
}
