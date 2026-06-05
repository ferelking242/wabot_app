import 'package:flutter/material.dart';

const _green  = Color(0xFF25D366);
const _greenDk = Color(0xFF128C7E);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _border = Color(0xFF1E2128);
const _card   = Color(0xFF111316);
const _bg     = Color(0xFF0D0E11);
const _white  = Colors.white;

class PageScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  const PageScaffold({super.key, required this.title, this.subtitle, this.actions = const [], required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, color: _ink, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: _muted))],
            ])),
            ...actions,
          ]),
          const SizedBox(height: 6),
          Container(height: 2, width: 32, decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          child,
        ]),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  const ActionButton({super.key, required this.label, this.icon, this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(cursor: SystemMouseCursors.click,
        child: Container(
          height: 34, padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: primary ? const LinearGradient(colors: [_greenDk, _green], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            color: primary ? null : _card,
            borderRadius: BorderRadius.circular(9),
            border: primary ? null : Border.all(color: _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 13, color: primary ? _white : _ink), const SizedBox(width: 6)],
            Text(label, style: TextStyle(color: primary ? _white : _ink, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class DataPanel extends StatelessWidget {
  final String? title;
  final List<Widget> headerActions;
  final Widget child;
  final EdgeInsetsGeometry padding;
  const DataPanel({super.key, this.title, this.headerActions = const [], required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Padding(padding: padding, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
          Container(width: 3, height: 16, decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title!, style: const TextStyle(fontSize: 13, color: _ink, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
          const Spacer(),
          ...headerActions,
        ])),
        child,
      ])),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bg;
  const StatusPill({super.key, required this.label, required this.color, this.bg});
  factory StatusPill.success(String l) => StatusPill(label: l, color: const Color(0xFF25D366), bg: const Color(0xFF0D2318));
  factory StatusPill.warning(String l) => StatusPill(label: l, color: const Color(0xFFF59E0B), bg: const Color(0xFF1F1700));
  factory StatusPill.danger(String l)  => StatusPill(label: l, color: const Color(0xFFFF6B6B), bg: const Color(0xFF200A0A));
  factory StatusPill.neutral(String l) => StatusPill(label: l, color: const Color(0xFF8A9199), bg: const Color(0xFF1E2128));

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: bg ?? const Color(0xFF1E2128), borderRadius: BorderRadius.circular(99)),
    child: Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
  );
}
