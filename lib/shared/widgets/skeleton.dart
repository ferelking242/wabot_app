import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
export 'package:skeletonizer/skeletonizer.dart' show Skeletonizer;

const _base = Color(0xFF1E2128);
const _high = Color(0xFF2A2F3A);

class SkeletonBox extends StatelessWidget {
  final double width, height;
  final double radius;
  const SkeletonBox({super.key, required this.width, required this.height, this.radius = 8});
  @override
  Widget build(BuildContext context) => Skeletonizer(
    enabled: true,
    effect: const ShimmerEffect(baseColor: _base, highlightColor: _high),
    child: Container(width: width, height: height,
      decoration: BoxDecoration(color: _base, borderRadius: BorderRadius.circular(radius))),
  );
}

class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});
  @override
  Widget build(BuildContext context) => Skeletonizer(
    enabled: true,
    effect: const ShimmerEffect(baseColor: _base, highlightColor: _high),
    child: Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF111316), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: _base, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 12),
        Container(width: 60, height: 10, decoration: BoxDecoration(color: _base, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 6),
        Container(width: 40, height: 18, decoration: BoxDecoration(color: _base, borderRadius: BorderRadius.circular(4))),
      ])),
  );
}
