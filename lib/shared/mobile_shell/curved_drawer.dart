import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/responsive_role_shell.dart' show RoleNavEntry;

const _terra  = Color(0xFF25D366);
const _orange = Color(0xFF128C7E);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _border = Color(0xFF1E2128);
const _white  = Colors.white;
const _bg     = Color(0xFF0D0E11);
const _subtle = Color(0xFF111316);

class CurvedDrawer extends StatelessWidget {
  final List<RoleNavEntry> entries;
  final String currentLabelKey;
  final String? user;
  final ValueChanged<RoleNavEntry> onSelect;
  const CurvedDrawer({
    super.key,
    required this.entries,
    required this.currentLabelKey,
    required this.user,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: _bg,
      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_orange, _terra], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _terra.withOpacity(.3), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Icon(Icons.chat_rounded, size: 20, color: _white))),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Admin', style: TextStyle(fontSize: 14, color: _white, fontWeight: FontWeight.w800)),
              Text('Administrateur', style: TextStyle(fontSize: 11, color: Colors.white70)),
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        // Nav items
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 2),
          itemBuilder: (_, i) {
            final e = entries[i];
            final sel = e.labelKey == currentLabelKey;
            return _DrawerTile(entry: e, selected: sel, onTap: () => onSelect(e));
          },
        )),
        // Footer
        Padding(padding: const EdgeInsets.all(16), child: Container(height: 1, color: _border)),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Row(children: [
          const Icon(Icons.chat_rounded, size: 14, color: _terra),
          const SizedBox(width: 6),
          Text('Wabot Dashboard', style: TextStyle(fontSize: 11, color: _terra.withOpacity(.8), fontWeight: FontWeight.w600)),
        ])),
      ])),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final RoleNavEntry entry;
  final bool selected;
  final VoidCallback onTap;
  const _DrawerTile({required this.entry, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _terra.withOpacity(.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: _terra.withOpacity(.3)) : null,
        ),
        child: Row(children: [
          Icon(selected ? (entry.activeIcon ?? entry.icon) : entry.icon, size: 18,
            color: selected ? _terra : _muted),
          const SizedBox(width: 12),
          Text(entry.labelKey, style: TextStyle(fontSize: 13.5, color: selected ? _ink : _muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          if (selected) ...[const Spacer(), Container(width: 4, height: 4, decoration: BoxDecoration(color: _terra, shape: BoxShape.circle))],
        ]),
      ),
    );
  }
}
