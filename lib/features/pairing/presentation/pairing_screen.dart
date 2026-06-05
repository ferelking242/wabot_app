import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../providers/pairing_provider.dart';
import '../../auth/presentation/splash_screen.dart' show WabotLogoWidget;

const _g     = Color(0xFF25D366);
const _gd    = Color(0xFF128C7E);
const _bg    = Color(0xFF0A0C0F);
const _card  = Color(0xFF111316);
const _card2 = Color(0xFF0D0E11);
const _bord  = Color(0xFF1E2128);
const _ink   = Color(0xFFF2F3F5);
const _muted = Color(0xFF8A9199);

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
      // Check if already connected first
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
    // Navigate when connected
    ref.listen(pairingProvider, (_, next) {
      if (next.status == PairingStatus.connected && mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) context.go('/home');
        });
      }
    });

    final st = ref.watch(pairingProvider);
    final key = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        // Hex background
        Positioned.fill(child: CustomPaint(painter: _HexPainter())),
        // Top accent line
        Positioned(top: 0, left: 0, right: 0,
          child: Container(height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_gd, _g, Color(0xFF34E07E)])))),
        // Main content
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(children: [
                  const WabotLogoWidget(size: 60, radius: 16, iconSize: 28)
                    .animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 14),
                  const Text('Connecter WhatsApp',
                    style: TextStyle(color: _ink, fontSize: 22,
                      fontWeight: FontWeight.w800, letterSpacing: -0.3))
                    .animate(delay: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 4),
                  Text('Liez votre compte WhatsApp au bot ${AppConfig.appName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 13))
                    .animate(delay: 150.ms).fadeIn(),

                  // API key info
                  if (key != null) ...[
                    const SizedBox(height: 8),
                    _KeyBadge(apiKey: key)
                      .animate(delay: 200.ms).fadeIn(),
                  ],

                  const SizedBox(height: 24),

                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: _card, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _bord)),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: _g.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _g.withOpacity(0.35))),
                      labelColor: _g,
                      unselectedLabelColor: _muted,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      tabs: const [
                        Tab(icon: Icon(Icons.qr_code_rounded, size: 16), text: 'QR Code'),
                        Tab(icon: Icon(Icons.pin_outlined, size: 16), text: 'Code Pairing'),
                      ],
                    ),
                  ).animate(delay: 250.ms).fadeIn(),

                  const SizedBox(height: 20),

                  // Tab content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _tab.index == 0
                      ? _QrTab(key: const ValueKey('qr'), state: st)
                      : _CodeTab(key: const ValueKey('code'), ctrl: _phoneCtrl, state: st),
                  ).animate(delay: 300.ms).fadeIn(),

                  const SizedBox(height: 16),

                  // Error banner
                  if (st.error != null)
                    _ErrorBanner(message: st.error!)
                      .animate().fadeIn().shake(),

                  const SizedBox(height: 16),

                  // Instructions
                  _Instructions(isQr: _tab.index == 0)
                    .animate(delay: 350.ms).fadeIn(),

                  const SizedBox(height: 20),

                  // Skip / logout
                  TextButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).signOut();
                    },
                    child: Text('Changer de serveur',
                      style: TextStyle(color: _muted.withOpacity(0.7), fontSize: 12)),
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

// ── QR tab ─────────────────────────────────────────────────────────────────────

class _QrTab extends StatelessWidget {
  final PairingState state;
  const _QrTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.status == PairingStatus.connected) return const _SuccessView();

    if (state.qrString == null) {
      return const _LoadingView(message: 'Génération du QR code…');
    }

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: _g.withOpacity(0.25), blurRadius: 28, spreadRadius: 2),
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12),
          ],
        ),
        child: QrImageView(
          data: state.qrString!,
          version: QrVersions.auto,
          size: 220,
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
      const SizedBox(height: 14),
      _CountdownBar(expiresIn: state.qrExpiresIn),
    ]);
  }
}

// ── Code tab ───────────────────────────────────────────────────────────────────

class _CodeTab extends ConsumerWidget {
  final TextEditingController ctrl;
  final PairingState state;
  const _CodeTab({super.key, required this.ctrl, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.status == PairingStatus.connected) return const _SuccessView();
    if (state.pairingCode != null) return _CodeDisplay(code: state.pairingCode!, state: state);

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _bord)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Numéro WhatsApp',
            style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: _ink, fontSize: 16, letterSpacing: 1),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\+\s\-]'))],
            decoration: InputDecoration(
              hintText: '+242 06 123 4567',
              hintStyle: TextStyle(color: _muted.withOpacity(0.4), letterSpacing: 0),
              filled: true, fillColor: _card2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _bord)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _bord)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _g, width: 1.5)),
              prefixIcon: const Icon(Icons.phone_outlined, size: 17, color: _muted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            onSubmitted: (_) => _submit(ref),
          ),
          const SizedBox(height: 8),
          Text('Format international sans +, ex: 2420612345678',
            style: TextStyle(color: _muted.withOpacity(0.6), fontSize: 11)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 46,
            child: ElevatedButton(
              onPressed: state.status == PairingStatus.loading ? null : () => _submit(ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: _g, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0),
              child: state.status == PairingStatus.loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.key_rounded, size: 17),
                    SizedBox(width: 8),
                    Text('Obtenir le code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ]),
            ),
          ),
        ]),
      ),
    ]);
  }

  void _submit(WidgetRef ref) {
    final phone = ctrl.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length >= 7) {
      ref.read(pairingProvider.notifier).requestPairingCode(phone);
    }
  }
}

// ── Code display ───────────────────────────────────────────────────────────────

class _CodeDisplay extends StatelessWidget {
  final String code;
  final PairingState state;
  const _CodeDisplay({required this.code, required this.state});

  @override
  Widget build(BuildContext context) {
    final parts = code.split('-');
    return Column(children: [
      Text('Entrez ce code dans WhatsApp',
        style: TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code copié !'), duration: Duration(seconds: 2)));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _g.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: _g.withOpacity(0.15), blurRadius: 24),
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
            ]),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < parts.length; i++) ...[
                  Text(parts[i], style: const TextStyle(
                    color: _g, fontSize: 34, fontWeight: FontWeight.w900,
                    fontFamily: 'monospace', letterSpacing: 4)),
                  if (i < parts.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('–', style: TextStyle(
                        color: _muted.withOpacity(0.5), fontSize: 28, fontWeight: FontWeight.w200))),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.copy_rounded, size: 12, color: _muted.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text('Appuyer pour copier', style: TextStyle(color: _muted.withOpacity(0.5), fontSize: 11)),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      if (state.status == PairingStatus.loading || state.status == PairingStatus.waitingCode)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 13, height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: _g.withOpacity(0.7))),
          const SizedBox(width: 8),
          Text('En attente de connexion WhatsApp…',
            style: TextStyle(color: _muted, fontSize: 12)),
        ]).animate(onPlay: (c) => c.repeat()).shimmer(color: _g.withOpacity(0.2)),
    ]);
  }
}

// ── Countdown bar ──────────────────────────────────────────────────────────────

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
    final color = pct > 0.5 ? _g : pct > 0.25 ? const Color(0xFFFAA61A) : const Color(0xFFED4245);
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, minHeight: 5,
          backgroundColor: _bord, color: color)),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.refresh_rounded, size: 11, color: _muted.withOpacity(0.5)),
        const SizedBox(width: 4),
        Text('Expire dans ${_rem}s  ·  Se rafraîchit automatiquement',
          style: TextStyle(color: _muted.withOpacity(0.6), fontSize: 11)),
      ]),
    ]);
  }
}

// ── Success ────────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView();
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(height: 20),
      Container(
        width: 84, height: 84,
        decoration: BoxDecoration(
          color: _g.withOpacity(0.12), shape: BoxShape.circle,
          border: Border.all(color: _g.withOpacity(0.4), width: 2)),
        child: const Icon(Icons.check_rounded, color: _g, size: 46))
        .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
      const SizedBox(height: 18),
      const Text('WhatsApp Connecté !',
        style: TextStyle(color: _g, fontSize: 20, fontWeight: FontWeight.w800))
        .animate(delay: 200.ms).fadeIn(),
      const SizedBox(height: 6),
      Text('Redirection vers le dashboard…',
        style: TextStyle(color: _muted, fontSize: 13))
        .animate(delay: 300.ms).fadeIn(),
      const SizedBox(height: 20),
    ]);
  }
}

// ── Loading ────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({required this.message});
  @override
  Widget build(BuildContext context) => SizedBox(height: 260,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(width: 30, height: 30,
        child: CircularProgressIndicator(color: _g, strokeWidth: 2.5)),
      const SizedBox(height: 16),
      Text(message, style: const TextStyle(color: _muted, fontSize: 13)),
    ]));
}

// ── Error banner ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFED4245).withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFED4245).withOpacity(0.25))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: Color(0xFFED4245), size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message,
        style: const TextStyle(color: Color(0xFFED4245), fontSize: 12))),
    ]));
}

// ── API Key badge ──────────────────────────────────────────────────────────────

class _KeyBadge extends StatelessWidget {
  final String apiKey;
  const _KeyBadge({required this.apiKey});
  @override
  Widget build(BuildContext context) {
    final display = apiKey.length > 16
      ? '${apiKey.substring(0, 8)}…${apiKey.substring(apiKey.length - 6)}'
      : apiKey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _g.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _g.withOpacity(0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.vpn_key_rounded, size: 11, color: _g.withOpacity(0.7)),
        const SizedBox(width: 5),
        Text(display, style: TextStyle(color: _g.withOpacity(0.8), fontSize: 11, fontFamily: 'monospace')),
      ]));
  }
}

// ── Instructions ───────────────────────────────────────────────────────────────

class _Instructions extends StatelessWidget {
  final bool isQr;
  const _Instructions({required this.isQr});

  @override
  Widget build(BuildContext context) {
    final steps = isQr
      ? ['Ouvrez WhatsApp sur votre téléphone',
         'Paramètres → Appareils liés',
         '"Lier un appareil"',
         'Scannez le QR code ci-dessus']
      : ['Ouvrez WhatsApp sur votre téléphone',
         'Paramètres → Appareils liés',
         '"Lier un appareil" → continuer sans QR',
         'Entrez le code à 8 chiffres affiché'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _g.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _g.withOpacity(0.12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 13, color: _g.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text('Comment faire', style: TextStyle(color: _g.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 17, height: 17,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: _g.withOpacity(0.15), shape: BoxShape.circle),
                  child: Text('${i + 1}',
                    style: const TextStyle(color: _g, fontSize: 9, fontWeight: FontWeight.w900))),
                const SizedBox(width: 8),
                Expanded(child: Text(steps[i],
                  style: TextStyle(color: _muted.withOpacity(0.85), fontSize: 12))),
              ])),
        ],
      ));
  }
}

// ── Hex background ─────────────────────────────────────────────────────────────

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.018)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    const r = 22.0;
    final dx = r * math.sqrt(3);
    final dy = r * 1.5;
    for (double y = -r; y < size.height + dy; y += dy) {
      for (double x = -dx; x < size.width + dx; x += dx) {
        final off = ((y / dy).floor() % 2 == 0) ? 0.0 : dx / 2;
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = math.pi / 180 * (60 * i - 30);
          final pt = Offset(x + off + r * math.cos(a), y + r * math.sin(a));
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        canvas.drawPath(path, p);
      }
    }
  }

  @override bool shouldRepaint(_) => false;
}
