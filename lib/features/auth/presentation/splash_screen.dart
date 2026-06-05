import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';

const _g  = Color(0xFF25D366);
const _gd = Color(0xFF128C7E);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _S();
}
class _S extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _sc, _fa;
  @override void initState() {
    super.initState();
    _c  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _sc = Tween(begin: 0.72, end: 1.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0, .65, curve: Curves.easeOutBack)));
    _fa = Tween(begin: 0.0,  end: 1.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0, .5,  curve: Curves.easeOut)));
    _c.forward();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0A0C0F), Color(0xFF0F1923)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _Hex())),
          Positioned(top: 0, left: 0, right: 0, child: Container(height: 3,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [_gd, _g, Color(0xFF34E07E)])))),
          Center(child: AnimatedBuilder(animation: _c, builder: (_, __) =>
            FadeTransition(opacity: _fa, child: ScaleTransition(scale: _sc, child: Column(mainAxisSize: MainAxisSize.min, children: [
              _WabotLogo(size: 96, radius: 24, iconSize: 44),
              const SizedBox(height: 24),
              const Text(AppConfig.appName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 36, letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Text(AppConfig.appTagline, style: TextStyle(color: _g.withOpacity(.85), fontSize: 13, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              Text('by ${AppConfig.company}', style: TextStyle(color: Colors.white.withOpacity(.3), fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 48),
              SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white.withOpacity(.7), strokeWidth: 2.5)),
            ]))),
          )),
          Positioned(bottom: 28, left: 0, right: 0, child: FadeTransition(opacity: _fa, child: Center(
            child: Text('© ${DateTime.now().year} ${AppConfig.company} · v${AppConfig.appVersion}',
              style: TextStyle(color: Colors.white.withOpacity(.2), fontSize: 11)),
          ))),
        ]),
      ),
    );
  }
}

/// Wabot logo widget — tries image asset first, falls back to painted icon.
class _WabotLogo extends StatelessWidget {
  final double size, iconSize, radius;
  const _WabotLogo({required this.size, required this.iconSize, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_gd, _g], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: _g.withOpacity(.4), blurRadius: 36, spreadRadius: 4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/logo_transparent.png',
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(Icons.chat_rounded, size: iconSize, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Exposed for use in other widgets (sidebar, login).
class WabotLogoWidget extends StatelessWidget {
  final double size;
  final double? radius;
  final double? iconSize;
  const WabotLogoWidget({super.key, this.size = 40, this.radius, this.iconSize});

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * 0.25;
    final is_ = iconSize ?? size * 0.45;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_gd, _g], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(r),
        boxShadow: [BoxShadow(color: _g.withOpacity(.35), blurRadius: 12, spreadRadius: 1)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.asset(
          'assets/images/logo_transparent.png',
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(Icons.chat_rounded, size: is_, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _Hex extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(.025)..style = PaintingStyle.stroke..strokeWidth = .7;
    const r = 20.0;
    final dx = r * math.sqrt(3); final dy = r * 1.5;
    for (double y = -r; y < size.height + dy; y += dy) {
      for (double x = -dx; x < size.width + dx; x += dx) {
        final off = ((y / dy).floor() % 2 == 0) ? 0.0 : dx / 2;
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = math.pi / 180 * (60 * i - 30);
          final pt = Offset(x + off + r * math.cos(a), y + r * math.sin(a));
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        path.close(); canvas.drawPath(path, p);
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}
