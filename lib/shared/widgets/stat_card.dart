import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int animationIndex;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.valueColor,
    this.trailing,
    this.onTap,
    this.animationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? AppColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 60 * animationIndex))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  final bool showDot;

  const StatusBadge({super.key, required this.status, this.showDot = true});

  Color get _color => switch (status.toLowerCase()) {
        'online' || 'connected' => AppColors.online,
        'connecting' => AppColors.idle,
        'offline' || 'disconnected' => AppColors.offline,
        'error' => AppColors.error,
        _ => AppColors.offline,
      };

  String get _label => switch (status.toLowerCase()) {
        'online' || 'connected' => 'Online',
        'connecting' => 'Connecting...',
        'offline' || 'disconnected' => 'Offline',
        'error' => 'Error',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ).animate(onPlay: (c) => c.repeat()).custom(
                  duration: 2.seconds,
                  builder: (_, value, child) => Opacity(
                    opacity: status == 'connecting' ? (value < 0.5 ? value * 2 : (1 - value) * 2) : 1,
                    child: child,
                  ),
                ),
            const SizedBox(width: 6),
          ],
          Text(
            _label,
            style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class MetricProgress extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final String unit;
  final Color? color;

  const MetricProgress({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.unit,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    final c = color ?? _colorForPercent(percent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            Text(
              '${value.toStringAsFixed(0)}$unit / ${max.toStringAsFixed(0)}$unit',
              style: theme.textTheme.labelSmall?.copyWith(color: c),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: AppColors.surfaceElevated,
            valueColor: AlwaysStoppedAnimation(c),
            minHeight: 6,
          ),
        ).animate().custom(
              duration: 800.ms,
              curve: Curves.easeOut,
              builder: (_, value, child) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent * value,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation(c),
                  minHeight: 6,
                ),
              ),
            ),
      ],
    );
  }

  Color _colorForPercent(double p) {
    if (p < 0.6) return AppColors.online;
    if (p < 0.8) return AppColors.idle;
    return AppColors.error;
  }
}
