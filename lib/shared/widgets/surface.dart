import 'package:flutter/material.dart';

class WabotSurface {
  WabotSurface._();
  static const _card   = Color(0xFF111316);
  static const _border = Color(0xFF1E2128);
  static const _green  = Color(0xFF25D366);

  static BoxDecoration card({double radius = 16, Color? borderColor}) => BoxDecoration(
    color: _card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? _border, width: 1.2),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(.28), blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -3),
      BoxShadow(color: _green.withOpacity(.04), blurRadius: 4, offset: const Offset(0, 2)),
    ],
  );

  static BoxDecoration accent({required Color color, double radius = 14}) => BoxDecoration(
    gradient: LinearGradient(
      colors: [Color.lerp(const Color(0xFF111316), color, .14)!, Color.lerp(const Color(0xFF111316), color, .26)!],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: color.withOpacity(.35), width: 1.2),
    boxShadow: [BoxShadow(color: color.withOpacity(.18), blurRadius: 14, offset: const Offset(0, 5), spreadRadius: -2)],
  );

  static BoxDecoration subtle({double radius = 12}) => BoxDecoration(
    color: const Color(0xFF0D0E11),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _border, width: 1.1),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 8, offset: const Offset(0, 3), spreadRadius: -1)],
  );

  static BoxDecoration inner({double radius = 10}) => BoxDecoration(
    color: const Color(0xFF0D0E11),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _border),
  );
}
typedef ScolarisSurface = WabotSurface;
