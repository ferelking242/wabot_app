import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_controller.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../core/config/app_config.dart';

const _g = Color(0xFF25D366); const _ink = Color(0xFFF2F3F5);
const _muted = Color(0xFF8A9199); const _border = Color(0xFF1E2128);
const _card = Color(0xFF111316); const _bg = Color(0xFF0D0E11);

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Paramètres', style: TextStyle(fontSize: 18, color: _ink, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Container(height: 2, width: 32, decoration: BoxDecoration(color: _g, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          _Group(title: 'Apparence', items: [
            _Item(icon: Icons.brightness_6_outlined, label: 'Thème sombre',
              trailing: Switch(value: theme.mode == ThemeMode.dark, activeColor: _g,
                onChanged: (_) => ref.read(themeControllerProvider.notifier).toggleBrightness())),
          ]),
          const SizedBox(height: 14),
          _Group(title: 'Compte', items: [
            _Item(icon: Icons.key_outlined, label: 'Clé API', subtitle: 'Masquée pour sécurité'),
            _Item(icon: Icons.logout_rounded, label: 'Se déconnecter', danger: true,
              onTap: () => ref.read(authProvider.notifier).signOut()),
          ]),
          const SizedBox(height: 14),
          _Group(title: 'À propos', items: [
            _Item(icon: Icons.info_outline_rounded, label: 'Version', subtitle: AppConfig.appVersion),
            _Item(icon: Icons.business_outlined,   label: 'Développé par', subtitle: AppConfig.company),
            _Item(icon: Icons.code_rounded,        label: AppConfig.appName, subtitle: AppConfig.appTagline),
          ]),
        ]),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title; final List<Widget> items;
  const _Group({required this.title, required this.items});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title.toUpperCase(), style: const TextStyle(fontSize: 10.5, color: _muted, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    const SizedBox(height: 8),
    Container(decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
      child: Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) Container(height: 1, color: _border),
          items[i],
        ],
      ])),
  ]);
}

class _Item extends StatelessWidget {
  final IconData icon; final String label; final String? subtitle;
  final Widget? trailing; final VoidCallback? onTap; final bool danger;
  const _Item({required this.icon, required this.label, this.subtitle, this.trailing, this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFF6B6B) : _ink;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 18, color: danger ? const Color(0xFFFF6B6B) : _muted),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13.5, color: color, fontWeight: FontWeight.w500)),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: _muted)),
          ])),
          if (trailing != null) trailing!,
          if (onTap != null && trailing == null) const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
        ]),
      ));
  }
}
