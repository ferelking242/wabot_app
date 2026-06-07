import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../presentation/providers/auth_providers.dart';

const _g      = Color(0xFF25D366);
const _gd     = Color(0xFF128C7E);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _border = Color(0xFF1E2128);
const _card   = Color(0xFF111316);
const _bg     = Color(0xFF0D0E11);
const _red    = Color(0xFFFF6B6B);

class _PermItem {
  final IconData icon;
  final String   title;
  final String   desc;
  final Color    color;
  final Future<bool> Function() request;
  final Future<bool> Function() check;

  const _PermItem({
    required this.icon, required this.title, required this.desc,
    required this.color, required this.request, required this.check,
  });
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  final Map<int, bool> _granted = {};
  bool _checking = false;

  late final List<_PermItem> _perms;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();

    _perms = [
      _PermItem(
        icon: Icons.notifications_active_outlined,
        title: 'Notifications',
        desc: 'Reçois les alertes du bot en temps réel même en arrière-plan.',
        color: _g,
        request: () => Permission.notification.request().then((s) => s.isGranted),
        check:   () => Permission.notification.isGranted,
      ),
      _PermItem(
        icon: Icons.folder_open_outlined,
        title: 'Accès stockage',
        desc: 'Sauvegarde les logs, exports et médias du bot.',
        color: const Color(0xFF57B6FF),
        request: () async {
          if (Platform.isAndroid) {
            final sdk = int.tryParse(
              await const MethodChannel('com.aivos.wabot/bot_engine')
                  .invokeMethod<String?>('getSdkInt')
                  .then((v) => v ?? '30')
                  .catchError((_) => '30'),
            ) ?? 30;
            if (sdk >= 30) {
              return Permission.manageExternalStorage.request().then((s) => s.isGranted);
            }
          }
          return Permission.storage.request().then((s) => s.isGranted);
        },
        check: () async {
          if (await Permission.manageExternalStorage.isGranted) return true;
          return Permission.storage.isGranted;
        },
      ),
      _PermItem(
        icon: Icons.battery_charging_full_outlined,
        title: 'Optimisation batterie',
        desc: 'Empêche Android de tuer le bot en veille. Essentiel pour fonctionner 24/7.',
        color: const Color(0xFFE67E22),
        request: () => Permission.ignoreBatteryOptimizations.request().then((s) => s.isGranted),
        check:   () => Permission.ignoreBatteryOptimizations.isGranted,
      ),
    ];

    _checkAll();
  }

  Future<void> _checkAll() async {
    if (!mounted) return;
    setState(() => _checking = true);
    for (int i = 0; i < _perms.length; i++) {
      final ok = await _perms[i].check();
      if (mounted) setState(() => _granted[i] = ok);
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _requestPerm(int idx) async {
    setState(() => _granted[idx] = false);
    final ok = await _perms[idx].request();
    if (mounted) setState(() => _granted[idx] = ok);
  }

  bool get _canContinue {
    // Les permissions de notification et batterie sont recommandées mais pas bloquantes
    // Seul le stockage est optionnel — on peut continuer sans
    return true;
  }

  Future<void> _continue() async {
    await ref.read(authProvider.notifier).markOnboardingDone();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 40),

            // ── Logo + titre ───────────────────────────────────────────────
            FadeTransition(
              opacity: _anim,
              child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_g, _gd],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: _g.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),
                const Text('Bienvenue sur Wabot',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                        color: _ink, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                const Text(
                  'Pour que Wabot fonctionne 24/7 en arrière-plan,\naccorde les permissions suivantes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
                ),
              ]),
            ),

            const SizedBox(height: 40),

            // ── Permissions ────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                itemCount: _perms.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final p   = _perms[i];
                  final ok  = _granted[i];
                  return _PermCard(
                    item: p,
                    granted: ok,
                    loading: _checking && ok == null,
                    onTap: () => _requestPerm(i),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // ── Info batterie ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: _muted, size: 16),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'L\'optimisation batterie est critique. Sans ça, Android peut tuer le bot au bout de quelques minutes.',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 20),

            // ── Bouton Continuer ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_g, _gd]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _g.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _continue,
                  child: const Text('Continuer',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                          fontSize: 16, letterSpacing: 0.3)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: _continue,
              child: const Text('Ignorer pour l\'instant',
                  style: TextStyle(color: _muted, fontSize: 13)),
            ),

            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

class _PermCard extends StatelessWidget {
  final _PermItem item;
  final bool?     granted;
  final bool      loading;
  final VoidCallback onTap;

  const _PermCard({required this.item, required this.granted,
    required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGranted = granted == true;
    final color     = isGranted ? _g : item.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isGranted ? _g.withOpacity(0.4) : _border),
        boxShadow: isGranted
            ? [BoxShadow(color: _g.withOpacity(0.08), blurRadius: 8)]
            : [],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 3),
          Text(item.desc,
              style: const TextStyle(fontSize: 12, color: _muted, height: 1.4)),
        ])),
        const SizedBox(width: 12),
        loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _muted))
            : isGranted
                ? Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: _g.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: _g, size: 18),
                  )
                : GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: item.color.withOpacity(0.3)),
                      ),
                      child: Text('Autoriser',
                          style: TextStyle(color: item.color, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
      ]),
    );
  }
}
