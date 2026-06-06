import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/platform_service.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../providers/pairing_provider.dart';
import '../../auth/presentation/splash_screen.dart' show WabotLogoWidget;

const _g     = Color(0xFF25D366);
const _gd    = Color(0xFF128C7E);
const _bg    = Color(0xFF0A0C0F);
const _card  = Color(0xFF111418);
const _card2 = Color(0xFF0D0F12);
const _bord  = Color(0xFF1C2128);
const _ink   = Color(0xFFF2F3F5);
const _muted = Color(0xFF8A9199);

// ── Gradient border helper ──────────────────────────────────────────────────

class _GradientBorderBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final List<Color> gradientColors;
  final EdgeInsets? padding;

  const _GradientBorderBox({
    required this.child,
    this.radius = 20,
    this.gradientColors = const [Color(0xFF25D366), Color(0xFF1C2128), Color(0xFF1C2128)],
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(radius - 1.2),
        ),
        child: child,
      ),
    );
  }
}

// ── Main screen ────────────────────────────────────────────────────────────

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});
  @override ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(pairingProvider.notifier).checkStatus();
      if (mounted) {
        final st = ref.read(pairingProvider);
        if (st.status != PairingStatus.connected) {
          ref.read(pairingProvider.notifier).startQrPolling();
        }
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pairingProvider, (_, next) {
      if (next.status == PairingStatus.connected && mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) context.go('/home');
        });
      }
    });

    final st = ref.watch(pairingProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _HexPainter())),
        // Top gradient accent
        Positioned(top: 0, left: 0, right: 0,
          child: Container(height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_gd, _g, Color(0xFF34E07E)])))),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(children: [
                  // Logo
                  const WabotLogoWidget(size: 64, radius: 18, iconSize: 30)
                    .animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 14),
                  const Text('Connecter WhatsApp',
                    style: TextStyle(color: _ink, fontSize: 22,
                      fontWeight: FontWeight.w800, letterSpacing: -0.4))
                    .animate(delay: 80.ms).fadeIn().slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 4),
                  Text('Liez votre compte WhatsApp au bot ${AppConfig.appName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 13, height: 1.4))
                    .animate(delay: 120.ms).fadeIn(),
                  const SizedBox(height: 10),
                  _PlatformBadge().animate(delay: 160.ms).fadeIn(),
                  const SizedBox(height: 28),

                  // ── Tab bar ──────────────────────────────────────────
                  _GradientBorderBox(
                    radius: 18,
                    gradientColors: const [Color(0xFF25D366), Color(0xFF1C2128), Color(0xFF1E2530)],
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _card2,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: TabBar(
                        controller: _tab,
                        dividerColor: Colors.transparent,
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        indicator: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_g.withOpacity(0.18), _g.withOpacity(0.08)]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _g.withOpacity(0.45), width: 1),
                          boxShadow: [
                            BoxShadow(color: _g.withOpacity(0.12), blurRadius: 14),
                          ],
                        ),
                        labelColor: _g,
                        unselectedLabelColor: _muted,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13),
                        tabs: const [
                          Tab(
                            iconMargin: EdgeInsets.only(bottom: 2),
                            icon: Icon(Icons.qr_code_rounded, size: 17),
                            text: 'QR Code',
                          ),
                          Tab(
                            iconMargin: EdgeInsets.only(bottom: 2),
                            icon: Icon(Icons.pin_outlined, size: 17),
                            text: 'Code Pairing',
                          ),
                        ],
                      ),
                    ),
                  ).animate(delay: 200.ms).fadeIn(),

                  const SizedBox(height: 20),

                  // ── Tab content ──────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: _tab.index == 0
                      ? _QrTab(key: const ValueKey('qr'), state: st)
                      : _CodeTab(key: const ValueKey('code'),
                          ctrl: _phoneCtrl, state: st),
                  ).animate(delay: 250.ms).fadeIn(),

                  // ── Error banner ─────────────────────────────────────
                  if (st.error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBanner(message: st.error!).animate().fadeIn().shake(),
                  ],

                  const SizedBox(height: 18),

                  // ── Instructions ─────────────────────────────────────
                  _Instructions(isQr: _tab.index == 0)
                    .animate(delay: 300.ms).fadeIn(),

                  const SizedBox(height: 22),

                  TextButton(
                    onPressed: () =>
                        ref.read(authProvider.notifier).signOut(),
                    child: Text('Changer de serveur',
                      style: TextStyle(
                        color: _muted.withOpacity(0.55), fontSize: 12)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── QR tab ─────────────────────────────────────────────────────────────────

class _QrTab extends StatelessWidget {
  final PairingState state;
  const _QrTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.status == PairingStatus.connected) return const _SuccessView();
    if (state.qrString == null) {
      return const _LoadingView(message: 'Démarrage du bot…');
    }

    return Column(children: [
      // QR with gradient border + glow
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: _g.withOpacity(0.28), blurRadius: 36, spreadRadius: 2),
            BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 18),
          ],
        ),
        child: _GradientBorderBox(
          radius: 24,
          gradientColors: [_g, _g.withOpacity(0.3), _gd],
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
            ),
            child: QrImageView(
              data: state.qrString!,
              version: QrVersions.auto,
              size: 210,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0A0C0F),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0A0C0F),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _CountdownBar(expiresIn: state.qrExpiresIn),
    ]);
  }
}

// ── Code tab ───────────────────────────────────────────────────────────────

class _CodeTab extends ConsumerWidget {
  final TextEditingController ctrl;
  final PairingState state;
  const _CodeTab({super.key, required this.ctrl, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.status == PairingStatus.connected) return const _SuccessView();
    if (state.pairingCode != null)
      return _CodeDisplay(code: state.pairingCode!, state: state);

    return _GradientBorderBox(
      radius: 22,
      gradientColors: [_g.withOpacity(0.35), _bord, _bord],
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label
        Row(children: [
          const Icon(Icons.phone_android_rounded, size: 14, color: _muted),
          const SizedBox(width: 6),
          Text('Numéro WhatsApp',
            style: TextStyle(
              color: _muted, fontSize: 11.5,
              fontWeight: FontWeight.w600, letterSpacing: 0.6)),
        ]),
        const SizedBox(height: 10),

        // Input field
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(
            color: _ink, fontSize: 16,
            fontWeight: FontWeight.w600, letterSpacing: 0.5),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d\+\s\-]'))
          ],
          decoration: InputDecoration(
            hintText: '242 06 123 4567',
            hintStyle: TextStyle(
              color: _muted.withOpacity(0.35),
              fontWeight: FontWeight.w400, letterSpacing: 0),
            filled: true,
            fillColor: _card2,
            prefixIcon: Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 0, 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _g.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _g.withOpacity(0.2)),
              ),
              child: const Text('+', style: TextStyle(
                color: _g, fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _bord)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _bord)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _g, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 16),
          ),
          onSubmitted: (_) => _submit(ref),
        ),
        const SizedBox(height: 7),
        Text('Format international sans +, ex: 2420612345678',
          style: TextStyle(color: _muted.withOpacity(0.5), fontSize: 11)),

        const SizedBox(height: 20),

        // Action button with gradient
        GestureDetector(
          onTap: state.status == PairingStatus.loading ? null : () => _submit(ref),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: state.status == PairingStatus.loading
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2EDE72), Color(0xFF25D366), Color(0xFF1BB354)]),
              color: state.status == PairingStatus.loading
                ? _g.withOpacity(0.3)
                : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: state.status == PairingStatus.loading
                ? []
                : [
                    BoxShadow(
                      color: _g.withOpacity(0.40),
                      blurRadius: 20,
                      offset: const Offset(0, 7)),
                  ],
            ),
            alignment: Alignment.center,
            child: state.status == PairingStatus.loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.key_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Obtenir le code',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5)),
                  ],
                ),
          ),
        ),
      ]),
    );
  }

  void _submit(WidgetRef ref) {
    final phone = ctrl.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length >= 7) {
      ref.read(pairingProvider.notifier).requestPairingCode(phone);
    }
  }
}

// ── Code display ───────────────────────────────────────────────────────────

class _CodeDisplay extends StatelessWidget {
  final String code;
  final PairingState state;
  const _CodeDisplay({required this.code, required this.state});

  @override
  Widget build(BuildContext context) {
    final parts = code.split('-');
    return _GradientBorderBox(
      radius: 22,
      gradientColors: [_g.withOpacity(0.5), _g.withOpacity(0.1), _bord],
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Code copié !'),
              duration: const Duration(seconds: 2),
              backgroundColor: _g,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
              behavior: SnackBarBehavior.floating,
            ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(21),
          ),
          child: Column(children: [
            Text('Code de jumelage',
              style: TextStyle(
                color: _muted, fontSize: 11.5,
                fontWeight: FontWeight.w600, letterSpacing: 0.6)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < parts.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _g.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _g.withOpacity(0.25)),
                    ),
                    child: Text(parts[i], style: const TextStyle(
                      color: _g, fontSize: 30,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace', letterSpacing: 3)),
                  ),
                  if (i < parts.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('—', style: TextStyle(
                        color: _muted.withOpacity(0.4),
                        fontSize: 24, fontWeight: FontWeight.w200))),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.copy_rounded, size: 12,
                color: _muted.withOpacity(0.45)),
              const SizedBox(width: 5),
              Text('Appuyer pour copier',
                style: TextStyle(
                  color: _muted.withOpacity(0.5), fontSize: 11.5)),
            ]),
            if (state.status == PairingStatus.loading ||
                state.status == PairingStatus.waitingCode) ...[
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                  width: 13, height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: _g.withOpacity(0.7))),
                const SizedBox(width: 8),
                Text('En attente de connexion WhatsApp…',
                  style: TextStyle(color: _muted, fontSize: 12)),
              ]).animate(onPlay: (c) => c.repeat())
                .shimmer(color: _g.withOpacity(0.2)),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Countdown bar ──────────────────────────────────────────────────────────

class _CountdownBar extends StatefulWidget {
  final int expiresIn;
  const _CountdownBar({required this.expiresIn});
  @override State<_CountdownBar> createState() => _CState();
}

class _CState extends State<_CountdownBar> {
  late int _rem;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _rem = widget.expiresIn;
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _rem = (_rem - 1).clamp(0, 60));
    });
  }

  @override
  void didUpdateWidget(_CountdownBar old) {
    super.didUpdateWidget(old);
    if (old.expiresIn != widget.expiresIn) setState(() => _rem = widget.expiresIn);
  }

  @override void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final pct = (_rem / 60).clamp(0.0, 1.0);
    final color = pct > 0.5
      ? _g
      : pct > 0.25
        ? const Color(0xFFFAA61A)
        : const Color(0xFFED4245);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bord),
      ),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 4,
            backgroundColor: _bord, color: color)),
        const SizedBox(height: 7),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.refresh_rounded, size: 11,
            color: _muted.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text('Expire dans ${_rem}s · Se rafraîchit automatiquement',
            style: TextStyle(color: _muted.withOpacity(0.6), fontSize: 11)),
        ]),
      ]),
    );
  }
}

// ── Success ────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView();
  @override
  Widget build(BuildContext context) {
    return _GradientBorderBox(
      radius: 22,
      gradientColors: [_g.withOpacity(0.5), _g.withOpacity(0.1), _bord],
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(21),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [_g.withOpacity(0.2), _g.withOpacity(0.05)]),
              shape: BoxShape.circle,
              border: Border.all(color: _g.withOpacity(0.5), width: 2)),
            child: const Icon(Icons.check_rounded, color: _g, size: 44))
            .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 18),
          const Text('WhatsApp Connecté !',
            style: TextStyle(
              color: _g, fontSize: 19, fontWeight: FontWeight.w800))
            .animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 6),
          Text('Redirection vers le dashboard…',
            style: TextStyle(color: _muted, fontSize: 13))
            .animate(delay: 300.ms).fadeIn(),
        ]),
      ),
    );
  }
}

// ── Loading ────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({required this.message});
  @override
  Widget build(BuildContext context) => _GradientBorderBox(
    radius: 22,
    gradientColors: [_bord, _bord, _bord],
    child: Container(
      height: 180,
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(21)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(
            color: _g, strokeWidth: 2.5,
            backgroundColor: _g.withOpacity(0.1))),
        const SizedBox(height: 16),
        Text(message,
          style: const TextStyle(color: _muted, fontSize: 13)),
      ]),
    ),
  );
}

// ── Error banner ───────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFED4245).withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: const Color(0xFFED4245).withOpacity(0.25))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(Icons.warning_amber_rounded,
          color: Color(0xFFED4245), size: 16)),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
        style: const TextStyle(
          color: Color(0xFFED4245), fontSize: 12.5, height: 1.4))),
    ]));
}

// ── Platform badge ─────────────────────────────────────────────────────────

class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge();
  @override
  Widget build(BuildContext context) {
    final local = PlatformService.runsLocalBot;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _g.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _g.withOpacity(0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: _g, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _g.withOpacity(0.6), blurRadius: 6)]),
        ),
        Icon(local ? Icons.smartphone_rounded : Icons.cloud_rounded,
          size: 12, color: _g.withOpacity(0.8)),
        const SizedBox(width: 5),
        Text(
          local
            ? 'Bot local · ${PlatformService.platformLabel}'
            : 'Aivos Cloud',
          style: TextStyle(
            color: _g.withOpacity(0.85), fontSize: 11.5,
            fontWeight: FontWeight.w600)),
      ]));
  }
}

// ── Instructions ───────────────────────────────────────────────────────────

class _Instructions extends StatelessWidget {
  final bool isQr;
  const _Instructions({required this.isQr});

  @override
  Widget build(BuildContext context) {
    final steps = isQr
      ? ['Ouvrez WhatsApp sur votre téléphone',
         'Appuyez sur les 3 points → Appareils liés',
         'Appuyez sur "Lier un appareil"',
         'Scannez le QR code ci-dessus']
      : ['Ouvrez WhatsApp sur votre téléphone',
         'Appuyez sur les 3 points → Appareils liés',
         '"Lier un appareil" → continuer sans QR',
         'Entrez le code à 8 chiffres affiché'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _g.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _g.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 3.5, height: 14,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_g, _gd]),
              borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 8),
          Text('Comment faire',
            style: TextStyle(
              color: _g.withOpacity(0.9), fontSize: 12.5,
              fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 20, height: 20,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_g.withOpacity(0.22), _g.withOpacity(0.08)]),
                  shape: BoxShape.circle,
                  border: Border.all(color: _g.withOpacity(0.28))),
                child: Text('${i + 1}',
                  style: const TextStyle(
                    color: _g, fontSize: 9.5, fontWeight: FontWeight.w900))),
              const SizedBox(width: 10),
              Expanded(child: Text(steps[i],
                style: TextStyle(
                  color: _muted.withOpacity(0.85),
                  fontSize: 12.5, height: 1.4))),
            ])),
      ]),
    );
  }
}

// ── Hex background painter ─────────────────────────────────────────────────

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF161B22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    const r = 26.0;
    final w = r * math.sqrt(3);
    final h = r * 2;
    int row = 0;
    for (double y = -h; y < size.height + h; y += h * 0.75) {
      final offset = (row % 2) * w / 2;
      for (double x = -w + offset; x < size.width + w; x += w) {
        _hex(canvas, p, Offset(x, y), r);
      }
      row++;
    }
  }

  void _hex(Canvas c, Paint p, Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 180 * (60 * i - 30);
      final pt = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    c.drawPath(path, p);
  }

  @override bool shouldRepaint(_) => false;
}
