import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../presentation/providers/auth_providers.dart';
import '../../auth/presentation/splash_screen.dart' show WabotLogoWidget;

// ── Palette ──────────────────────────────────────────────────────────────────
const _g      = Color(0xFF25D366);
const _gd     = Color(0xFF128C7E);
const _glt    = Color(0xFF34E07E);
const _bg     = Color(0xFF0A0C0F);
const _bg2    = Color(0xFF0F1520);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _card   = Color(0xFF111316);
const _card2  = Color(0xFF161B24);
const _border = Color(0xFF1E2730);

// ── Permission model ─────────────────────────────────────────────────────────
class _Perm {
  final IconData icon;
  final String   title;
  final String   desc;
  final Color    color;
  final Future<bool> Function() request;
  final Future<bool> Function() check;
  const _Perm({
    required this.icon, required this.title, required this.desc,
    required this.color, required this.request, required this.check,
  });
}

// ── Slide data ────────────────────────────────────────────────────────────────
class _SlideData {
  final String   title;
  final String   subtitle;
  final Widget   visual;
  final Color    accentColor;
  const _SlideData({
    required this.title, required this.subtitle,
    required this.visual, required this.accentColor,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {

  final _pageCtrl = PageController();
  int _page = 0;

  // Permissions state
  final Map<int, bool> _granted = {};
  bool _checking = false;
  late final List<_Perm> _perms;

  @override
  void initState() {
    super.initState();

    _perms = [
      _Perm(
        icon: Icons.notifications_active_rounded,
        title: 'Notifications',
        desc: 'Alertes bot en temps réel, même en arrière-plan.',
        color: _g,
        request: () => Permission.notification.request().then((s) => s.isGranted),
        check:   () => Permission.notification.isGranted,
      ),
      _Perm(
        icon: Icons.folder_rounded,
        title: 'Stockage',
        desc: 'Logs, exports et médias sauvegardés localement.',
        color: const Color(0xFF57B6FF),
        request: () async {
          if (Platform.isAndroid) {
            final sdkStr = await const MethodChannel('com.aivos.wabot/bot_engine')
                .invokeMethod<String?>('getSdkInt')
                .then((v) => v ?? '30')
                .catchError((_) => '30');
            final sdk = int.tryParse(sdkStr) ?? 30;
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
      _Perm(
        icon: Icons.battery_charging_full_rounded,
        title: 'Batterie illimitée',
        desc: 'Empêche Android de tuer le bot. Essentiel 24/7.',
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

  Future<void> _continue() async {
    HapticFeedback.mediumImpact();
    await ref.read(authProvider.notifier).markOnboardingDone();
  }

  void _nextPage() {
    if (_page < 3) {
      HapticFeedback.selectionClick();
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _continue();
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(children: [

          // ── Hex mesh background ──────────────────────────────────────────
          const Positioned.fill(child: _HexBg()),

          // ── Radial glow top ──────────────────────────────────────────────
          Positioned(
            top: -100, left: 0, right: 0,
            child: Container(
              height: 340,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x1625D366), Colors.transparent],
                  radius: 0.6,
                ),
              ),
            ),
          ),

          // ── Top accent line ──────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 2.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_gd, _g, _glt]),
              ),
            ),
          ),

          // ── Pages ────────────────────────────────────────────────────────
          SafeArea(
            child: Column(children: [

              // Skip button
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: _page < 3 ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: TextButton(
                    onPressed: () => _pageCtrl.animateToPage(
                      3,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                    ),
                    child: const Text(
                      'Passer',
                      style: TextStyle(color: _muted, fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),

              // PageView
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (p) => setState(() => _page = p),
                  children: [
                    _Slide0Welcome(h: h),
                    _Slide1Features(h: h),
                    _Slide2Dashboard(h: h),
                    _Slide3Perms(
                      perms: _perms,
                      granted: _granted,
                      checking: _checking,
                      onRequest: _requestPerm,
                    ),
                  ],
                ),
              ),

              // ── Bottom controls ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [

                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) => _Dot(active: i == _page)),
                  ),

                  const SizedBox(height: 24),

                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: _GradientButton(
                      label: _page < 3 ? 'Suivant' : 'Commencer',
                      onTap: _nextPage,
                    ),
                  ),

                  // Ignore link on last slide
                  if (_page == 3) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _continue,
                      child: const Text(
                        'Ignorer les permissions',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 44),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 0 — Bienvenue
// ─────────────────────────────────────────────────────────────────────────────
class _Slide0Welcome extends StatelessWidget {
  final double h;
  const _Slide0Welcome({required this.h});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          // Animated logo
          Stack(alignment: Alignment.center, children: [
            // Outer pulse ring
            Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_g.withOpacity(0.12), Colors.transparent],
                ),
              ),
            ).animate(onPlay: (c) => c.repeat())
              .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.15, 1.15),
                  duration: 2200.ms, curve: Curves.easeInOut)
              .fadeOut(begin: 1, duration: 2200.ms, curve: Curves.easeIn),

            // Inner glow
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _g.withOpacity(0.08),
              ),
            ),

            // Logo
            WabotLogoWidget(size: 88, radius: 26, iconSize: 40)
              .animate()
              .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1),
                  duration: 700.ms, curve: Curves.easeOutBack)
              .fadeIn(duration: 500.ms),
          ]),

          const SizedBox(height: 36),

          // Title
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [_ink, _g],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(b),
            child: const Text(
              'Bienvenue sur\nWabot',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1.0,
              ),
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 600.ms)
            .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut),

          const SizedBox(height: 16),

          const Text(
            'Le bot WhatsApp autonome qui tourne\n24h/24, 7j/7 — directement sur votre téléphone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 15,
              height: 1.55,
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 600.ms)
            .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut),

          const SizedBox(height: 32),

          // Badges row
          Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              _Badge(label: 'WhatsApp Baileys', icon: Icons.verified_rounded, color: _g),
              _Badge(label: 'Node.js Embarqué', icon: Icons.memory_rounded, color: Color(0xFF57B6FF)),
              _Badge(label: 'Open Source', icon: Icons.code_rounded, color: Color(0xFFB57AFF)),
            ],
          ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 1 — Features
// ─────────────────────────────────────────────────────────────────────────────
class _Slide1Features extends StatelessWidget {
  final double h;
  const _Slide1Features({required this.h});

  static const _features = [
    _Feature(
      icon: Icons.smart_toy_rounded,
      title: 'Bot autonome 24/7',
      desc: 'Répond, gère les groupes et exécute des commandes sans intervention.',
      color: _g,
    ),
    _Feature(
      icon: Icons.dashboard_rounded,
      title: 'Dashboard en temps réel',
      desc: 'Statistiques, logs, sessions et groupes accessibles d\'un coup d\'œil.',
      color: Color(0xFF57B6FF),
    ),
    _Feature(
      icon: Icons.terminal_rounded,
      title: 'Commandes puissantes',
      desc: 'Système de commandes extensible, personnalisable et multi-préfixe.',
      color: Color(0xFFB57AFF),
    ),
    _Feature(
      icon: Icons.shield_rounded,
      title: 'Anti-ban intégré',
      desc: 'Circuit-breaker 429, rate limiting intelligent et gestion des erreurs.',
      color: Color(0xFFE67E22),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tout ce dont\nvous avez besoin.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: _ink,
              height: 1.15,
              letterSpacing: -0.7,
            ),
          ).animate().fadeIn(duration: 500.ms)
            .slideX(begin: -0.1, end: 0, duration: 500.ms, curve: Curves.easeOut),

          const SizedBox(height: 6),

          const Text(
            'Une plateforme complète pour automatiser WhatsApp.',
            style: TextStyle(color: _muted, fontSize: 14),
          ).animate().fadeIn(delay: 100.ms, duration: 500.ms),

          const SizedBox(height: 28),

          ...List.generate(_features.length, (i) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FeatureRow(feature: _features[i], delay: 150 + i * 80),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String   title;
  final String   desc;
  final Color    color;
  const _Feature({required this.icon, required this.title,
    required this.desc, required this.color});
}

class _FeatureRow extends StatelessWidget {
  final _Feature feature;
  final int      delay;
  const _FeatureRow({required this.feature, required this.delay});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: feature.color.withOpacity(0.18), width: 1),
          ),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: feature.color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(feature.icon, color: feature.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 3),
                Text(feature.desc,
                    style: const TextStyle(fontSize: 12, color: _muted, height: 1.4)),
              ],
            )),
          ]),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay), duration: 500.ms)
      .slideX(begin: 0.08, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 2 — Dashboard mockup
// ─────────────────────────────────────────────────────────────────────────────
class _Slide2Dashboard extends StatelessWidget {
  final double h;
  const _Slide2Dashboard({required this.h});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tableau de bord\npuissant.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: _ink,
              height: 1.15,
              letterSpacing: -0.7,
            ),
          ).animate().fadeIn(duration: 500.ms)
            .slideX(begin: -0.1, end: 0, duration: 500.ms, curve: Curves.easeOut),

          const SizedBox(height: 6),
          const Text(
            'Suivez chaque métrique de votre bot en direct.',
            style: TextStyle(color: _muted, fontSize: 14),
          ).animate().fadeIn(delay: 100.ms, duration: 500.ms),

          const SizedBox(height: 24),

          // Mockup cards grid
          _MockupCard(),

          const SizedBox(height: 16),

          // Status bar
          _StatusBar().animate()
            .fadeIn(delay: 700.ms, duration: 500.ms)
            .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

class _MockupCard extends StatelessWidget {
  const _MockupCard();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: const [
        _StatMock(label: 'Messages', value: '1 247', icon: Icons.chat_bubble_rounded, color: _g, delay: 200),
        _StatMock(label: 'Groupes', value: '38', icon: Icons.group_rounded, color: Color(0xFF57B6FF), delay: 300),
        _StatMock(label: 'Commandes', value: '523', icon: Icons.terminal_rounded, color: Color(0xFFB57AFF), delay: 400),
        _StatMock(label: 'Uptime', value: '99.8%', icon: Icons.bolt_rounded, color: Color(0xFFE67E22), delay: 500),
      ],
    );
  }
}

class _StatMock extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final int delay;
  const _StatMock({required this.label, required this.value,
    required this.icon, required this.color, required this.delay});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: _g, shape: BoxShape.circle),
                ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                        color: color, letterSpacing: -0.5)),
                Text(label,
                    style: const TextStyle(fontSize: 11, color: _muted,
                        fontWeight: FontWeight.w500)),
              ]),
            ],
          ),
        ),
      ),
    ).animate()
      .fadeIn(delay: Duration(milliseconds: delay), duration: 500.ms)
      .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1),
          delay: Duration(milliseconds: delay), duration: 500.ms,
          curve: Curves.easeOutBack);
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _g.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _g.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(width: 8, height: 8,
                decoration: const BoxDecoration(color: _g, shape: BoxShape.circle))
              .animate(onPlay: (c) => c.repeat())
              .fadeOut(duration: 900.ms, curve: Curves.easeInOut)
              .then().fadeIn(duration: 900.ms),
            const SizedBox(width: 10),
            const Text('Bot connecté · WhatsApp en ligne',
                style: TextStyle(color: _g, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            const Text('En direct', style: TextStyle(color: _muted, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 3 — Permissions
// ─────────────────────────────────────────────────────────────────────────────
class _Slide3Perms extends StatelessWidget {
  final List<_Perm>       perms;
  final Map<int, bool>    granted;
  final bool              checking;
  final void Function(int) onRequest;

  const _Slide3Perms({
    required this.perms, required this.granted,
    required this.checking, required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _g.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _g.withOpacity(0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_open_rounded, color: _g, size: 13),
                SizedBox(width: 5),
                Text('Dernière étape',
                    style: TextStyle(color: _g, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 14),

          const Text(
            'Permissions\nrequises.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: _ink,
              height: 1.15,
              letterSpacing: -0.7,
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 500.ms)
            .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOut),

          const SizedBox(height: 6),
          const Text(
            'Pour fonctionner 24/7 en arrière-plan, Wabot\na besoin de ces accès.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
          ).animate().fadeIn(delay: 160.ms, duration: 500.ms),

          const SizedBox(height: 24),

          ...List.generate(perms.length, (i) {
            final p  = perms[i];
            final ok = granted[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PermCard(
                perm: p, granted: ok,
                loading: checking && ok == null,
                onTap: () => onRequest(i),
                delay: 200 + i * 80,
              ),
            );
          }),

          const SizedBox(height: 10),

          // Battery note
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE67E22).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE67E22).withOpacity(0.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFE67E22), size: 15),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La permission batterie est critique — sans elle, Android peut tuer le bot après quelques minutes.',
                      style: TextStyle(color: Color(0xFFE67E22), fontSize: 11, height: 1.4),
                    ),
                  ),
                ]),
              ),
            ),
          ).animate().fadeIn(delay: 600.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

class _PermCard extends StatelessWidget {
  final _Perm  perm;
  final bool?  granted;
  final bool   loading;
  final int    delay;
  final VoidCallback onTap;
  const _PermCard({required this.perm, required this.granted,
    required this.loading, required this.delay, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGranted = granted == true;
    final color     = isGranted ? _g : perm.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isGranted ? _g.withOpacity(0.07) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isGranted ? _g.withOpacity(0.35) : _border,
                width: 1,
              ),
            ),
            child: Row(children: [
              // Icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(perm.icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(perm.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 3),
                  Text(perm.desc,
                      style: const TextStyle(fontSize: 12, color: _muted, height: 1.4)),
                ],
              )),
              const SizedBox(width: 12),
              if (loading)
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _muted),
                )
              else if (isGranted)
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _g.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: _g, size: 18),
                ).animate().scale(
                    begin: const Offset(0.4, 0.4), end: const Offset(1, 1),
                    duration: 350.ms, curve: Curves.easeOutBack)
              else
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: perm.color.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: perm.color.withOpacity(0.35)),
                    ),
                    child: Text('Autoriser',
                        style: TextStyle(
                          color: perm.color, fontSize: 12,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ).animate()
      .fadeIn(delay: Duration(milliseconds: delay), duration: 500.ms)
      .slideX(begin: 0.05, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width:  active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? _g : _border,
        borderRadius: BorderRadius.circular(4),
        boxShadow: active
            ? [BoxShadow(color: _g.withOpacity(0.45), blurRadius: 6, offset: const Offset(0, 2))]
            : [],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  const _Badge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_gd, _g, _glt],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: _g.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 5)),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hex mesh background painter
// ─────────────────────────────────────────────────────────────────────────────
class _HexBg extends StatelessWidget {
  const _HexBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_bg, _bg2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(painter: _HexPainter()),
    );
  }
}

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C2128).withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    const r  = 28.0;
    final h  = r * math.sqrt(3);
    final cols = (size.width  / h        + 2).ceil();
    final rows = (size.height / (r * 1.5) + 2).ceil();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final x = col * h + (row.isOdd ? h / 2 : 0);
        final y = row * r * 1.5;
        _hex(canvas, paint, Offset(x, y), r);
      }
    }
  }

  void _hex(Canvas canvas, Paint paint, Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 180.0 * (60.0 * i - 30.0);
      final pt = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexPainter old) => false;
}
