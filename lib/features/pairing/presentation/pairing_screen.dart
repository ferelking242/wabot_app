import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
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

const _g    = Color(0xFF25D366);
const _gd   = Color(0xFF128C7E);
const _bg   = Color(0xFF0A0C0F);
const _ink  = Color(0xFFF2F3F5);
const _muted = Color(0xFF8A9199);

// Glass card helper
class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final double opacity;
  final Color? borderColor;

  const _Glass({
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.all(20),
    this.opacity = 0.045,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.07),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Hex background painter (unchanged)
class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C2128).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const r = 32.0;
    final h = r * math.sqrt(3);
    final cols = (size.width / (h) + 2).ceil();
    final rows = (size.height / (r * 1.5) + 2).ceil();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final x = col * h + (row.isOdd ? h / 2 : 0);
        final y = row * r * 1.5;
        _drawHex(canvas, paint, Offset(x, y), r);
      }
    }
  }

  void _drawHex(Canvas canvas, Paint paint, Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i - 30);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexPainter old) => false;
}

// ── Main screen ─────────────────────────────────────────────────────────────

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
        // Hex background
        Positioned.fill(child: CustomPaint(painter: _HexPainter())),
        // Top accent line
        Positioned(top: 0, left: 0, right: 0,
          child: Container(height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_gd, _g, Color(0xFF34E07E)])))),
        // Radial green glow top-center
        Positioned(
          top: -80, left: 0, right: 0,
          child: Container(
            height: 260,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  _g.withOpacity(0.10),
                  Colors.transparent,
                ],
                radius: 0.7,
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(children: [
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

                  // ── Tab bar (glass, no heavy border) ────────────────
                  _Glass(
                    radius: 18,
                    padding: const EdgeInsets.all(5),
                    opacity: 0.06,
                    borderColor: _g.withOpacity(0.18),
                    child: SizedBox(
                      height: 50,
                      child: TabBar(
                        controller: _tab,
                        dividerColor: Colors.transparent,
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        indicator: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_g.withOpacity(0.22), _g.withOpacity(0.08)]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _g.withOpacity(0.4), width: 1),
                          boxShadow: [
                            BoxShadow(color: _g.withOpacity(0.15), blurRadius: 12),
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

                  // ── Bot starting indicator ───────────────────────────
                  if (st.status == PairingStatus.botStarting &&
                      st.startingMessage != null) ...[
                    const SizedBox(height: 14),
                    _StartingBanner(message: st.startingMessage!)
                      .animate().fadeIn(),
                  ],

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
                        color: _muted.withOpacity(0.5), fontSize: 12)),
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

// ── QR tab ───────────────────────────────────────────────────────────────────

class _QrTab extends StatelessWidget {
  final PairingState state;
  const _QrTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.status == PairingStatus.connected) return const _SuccessView();
    if (state.status == PairingStatus.botStarting || state.qrString == null) {
      return _LoadingView(
        message: state.startingMessage ?? 'Démarrage du bot…',
      );
    }

    return Column(children: [
      // QR with green glow, no heavy box
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: _g.withOpacity(0.30), blurRadius: 40, spreadRadius: 2),
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _g.withOpacity(0.5), width: 2),
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

// ── Code tab ─────────────────────────────────────────────────────────────────

class _CodeTab extends ConsumerWidget {
  final TextEditingController ctrl;
  final PairingState state;
  const _CodeTab({super.key, required this.ctrl, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.status == PairingStatus.connected) return const _SuccessView();
    if (state.pairingCode != null)
      return _CodeDisplay(code: state.pairingCode!, state: state);
    if (state.status == PairingStatus.botStarting)
      return _LoadingView(
        message: state.startingMessage ?? 'Démarrage du bot…',
        color: _g,
      );

    return _Glass(
      radius: 22,
      padding: const EdgeInsets.all(22),
      opacity: 0.055,
      borderColor: _g.withOpacity(0.20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label
        Row(children: [
          const Icon(Icons.phone_android_rounded, size: 14, color: _muted),
          const SizedBox(width: 6),
          const Text('Numéro WhatsApp',
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
            fillColor: Colors.white.withOpacity(0.04),
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
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10))),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10))),
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

        // Action button
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

// ── Code display ─────────────────────────────────────────────────────────────

class _CodeDisplay extends StatelessWidget {
  final String code;
  final PairingState state;
  const _CodeDisplay({required this.code, required this.state});

  @override
  Widget build(BuildContext context) {
    final parts = code.split('-');
    return _Glass(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      borderColor: _g.withOpacity(0.30),
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
        child: Column(children: [
          const Text('Code de jumelage',
            style: TextStyle(
              color: _muted, fontSize: 11.5,
              fontWeight: FontWeight.w600, letterSpacing: 0.6)),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < parts.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _g.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _g.withOpacity(0.25)),
                  ),
                  child: Text(parts[i], style: const TextStyle(
                    color: _g, fontSize: 30,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace', letterSpacing: 3)),
                ),
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
    );
  }
}

// ── Bot starting banner ───────────────────────────────────────────────────────

class _StartingBanner extends StatelessWidget {
  final String message;
  const _StartingBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      opacity: 0.05,
      borderColor: _g.withOpacity(0.20),
      child: Row(children: [
        SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2, color: _g.withOpacity(0.8))),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
            style: const TextStyle(color: _g, fontSize: 13))),
      ]),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      opacity: 0.05,
      borderColor: const Color(0xFFE53935).withOpacity(0.40),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
          color: Color(0xFFEF5350), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
            style: const TextStyle(color: Color(0xFFEF9A9A), fontSize: 13))),
      ]),
    );
  }
}

// ── Loading view ──────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String message;
  final Color color;
  const _LoadingView({required this.message, this.color = _muted});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: _g, strokeWidth: 2.5)
          .animate(onPlay: (c) => c.repeat())
          .rotate(duration: 800.ms),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(color: color, fontSize: 13),
          textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Success view ──────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      borderColor: _g.withOpacity(0.35),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _g.withOpacity(0.12),
            border: Border.all(color: _g.withOpacity(0.4), width: 1.5),
          ),
          child: const Icon(Icons.check_rounded, color: _g, size: 34),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 16),
        const Text('Connecté !',
          style: TextStyle(color: _g, fontSize: 18, fontWeight: FontWeight.w800))
          .animate(delay: 150.ms).fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 6),
        Text('WhatsApp lié avec succès',
          style: TextStyle(color: _muted, fontSize: 13))
          .animate(delay: 200.ms).fadeIn(),
      ]),
    );
  }
}

// ── Countdown bar ─────────────────────────────────────────────────────────────

class _CountdownBar extends StatelessWidget {
  final int expiresIn;
  const _CountdownBar({required this.expiresIn});

  @override
  Widget build(BuildContext context) {
    final ratio = (expiresIn / 60).clamp(0.0, 1.0);
    final color = expiresIn > 20 ? _g : (expiresIn > 10 ? Colors.orange : Colors.red);
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 3,
          backgroundColor: Colors.white.withOpacity(0.06),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
      const SizedBox(height: 6),
      Text('QR expire dans ${expiresIn}s',
        style: TextStyle(color: _muted.withOpacity(0.5), fontSize: 11.5)),
    ]);
  }
}

// ── Platform badge ────────────────────────────────────────────────────────────

class _PlatformBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle, color: _g),
        ),
        const SizedBox(width: 6),
        Icon(PlatformService.isWeb ? Icons.language_rounded
          : Icons.phone_android_rounded,
          size: 13, color: _muted),
        const SizedBox(width: 5),
        Text('Bot local · ${PlatformService.platformLabel}',
          style: const TextStyle(color: _muted, fontSize: 12)),
      ]),
    );
  }
}

// ── Instructions ─────────────────────────────────────────────────────────────

class _Instructions extends StatelessWidget {
  final bool isQr;
  const _Instructions({required this.isQr});

  @override
  Widget build(BuildContext context) {
    final steps = isQr
      ? const [
          'Ouvrez WhatsApp sur votre téléphone',
          'Appuyez sur les 3 points → Appareils liés',
          'Appuyez sur "Lier un appareil"',
          'Scannez le QR Code affiché',
        ]
      : const [
          'Ouvrez WhatsApp sur votre téléphone',
          'Appuyez sur les 3 points → Appareils liés',
          '"Lier un appareil" → continuer sans QR',
          'Entrez le code à 8 chiffres affiché',
        ];

    return _Glass(
      radius: 18,
      padding: const EdgeInsets.all(18),
      opacity: 0.04,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 3, height: 16,
            decoration: BoxDecoration(
              color: _g,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text('Comment faire',
            style: TextStyle(color: _ink, fontSize: 13,
              fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        for (int i = 0; i < steps.length; i++) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _g.withOpacity(0.12),
                border: Border.all(color: _g.withOpacity(0.25)),
              ),
              alignment: Alignment.center,
              child: Text('${i + 1}',
                style: const TextStyle(
                  color: _g, fontSize: 11,
                  fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(steps[i],
                  style: TextStyle(color: _muted, fontSize: 13, height: 1.4)),
              ),
            ),
          ]),
          if (i < steps.length - 1) const SizedBox(height: 10),
        ],
      ]),
    );
  }
}