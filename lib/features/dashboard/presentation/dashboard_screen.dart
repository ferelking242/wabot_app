import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../theme/app_colors.dart';
import 'providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(botStatusProvider);
    final metricsAsync = ref.watch(metricsProvider);
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          await ref.read(botStatusProvider.notifier).refresh();
          await ref.read(metricsProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Dashboard',
                subtitle: 'Monitor your bot in real-time',
                actions: [
                  statusAsync.whenOrNull(
                    data: (s) => StatusBadge(status: s.status),
                  ) ?? const SizedBox.shrink(),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () => ref.read(botStatusProvider.notifier).refresh(),
                  ),
                ],
              ),
            ),
            // Stat cards grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              sliver: SliverToBoxAdapter(
                child: statusAsync.when(
                  data: (status) => _StatsGrid(status: status, isMobile: isMobile),
                  loading: () => _StatsGridSkeleton(isMobile: isMobile),
                  error: (_, __) => _ErrorBanner(onRetry: () => ref.read(botStatusProvider.notifier).refresh()),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            // Charts
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              sliver: SliverToBoxAdapter(
                child: metricsAsync.when(
                  data: (metrics) => _ChartsRow(metrics: metrics, isMobile: isMobile),
                  loading: () => const _ChartSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            // System metrics
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              sliver: SliverToBoxAdapter(
                child: statusAsync.whenOrNull(
                  data: (s) => _SystemMetrics(status: s),
                ) ?? const SizedBox.shrink(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final dynamic status;
  final bool isMobile;

  const _StatsGrid({required this.status, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final cols = isMobile ? 2 : 4;
    final stats = [
      _StatData('Groups', '${status.groupsCount}', Icons.groups_outlined, AppColors.info, '${status.sessionsCount} sessions'),
      _StatData('Messages', _fmt(status.messagesTotal), Icons.message_outlined, AppColors.accent, '${status.messagesPerMin}/min'),
      _StatData('Uptime', status.uptimeFormatted, Icons.access_time_outlined, AppColors.online, 'v${status.version}'),
      _StatData('Latency', '${status.wsLatency}ms', Icons.speed_outlined, AppColors.idle, 'WebSocket'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 1.3 : 1.6,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => StatCard(
        label: stats[i].label,
        value: stats[i].value,
        subtitle: stats[i].subtitle,
        icon: stats[i].icon,
        iconColor: stats[i].color,
        animationIndex: i,
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _StatData {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  _StatData(this.label, this.value, this.icon, this.color, [this.subtitle]);
}

class _ChartsRow extends StatelessWidget {
  final Map<String, dynamic> metrics;
  final bool isMobile;

  const _ChartsRow({required this.metrics, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daily = (metrics['dailyActivity'] as List? ?? []).cast<Map<String, dynamic>>();
    final cpuH = (metrics['cpuHistory'] as List? ?? []).cast<Map<String, dynamic>>();

    return isMobile
        ? Column(
            children: [
              _MessagesChart(data: daily, theme: theme),
              const SizedBox(height: 12),
              _CpuChart(data: cpuH, theme: theme),
            ],
          )
        : Row(
            children: [
              Expanded(child: _MessagesChart(data: daily, theme: theme)),
              const SizedBox(width: 12),
              Expanded(child: _CpuChart(data: cpuH, theme: theme)),
            ],
          );
  }
}

class _MessagesChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final ThemeData theme;

  const _MessagesChart({required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Messages (7 days)', style: theme.textTheme.titleSmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: data.asMap().entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: (e.value['messages'] as num?)?.toDouble() ?? 0,
                      color: AppColors.accent,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                )).toList(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.surfaceBorder, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }
}

class _CpuChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final ThemeData theme;

  const _CpuChart({required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CPU Usage (%)', style: theme.textTheme.titleSmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) => FlSpot(
                      e.key.toDouble(),
                      (e.value['value'] as num?)?.toDouble() ?? 0,
                    )).toList(),
                    isCurved: true,
                    color: AppColors.info,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.info.withOpacity(0.08),
                    ),
                  ),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.surfaceBorder, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
}

class _SystemMetrics extends StatelessWidget {
  final dynamic status;
  const _SystemMetrics({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System Resources', style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          MetricProgress(label: 'RAM', value: status.ramUsage, max: status.ramTotal, unit: ' MB'),
          const SizedBox(height: 16),
          MetricProgress(label: 'CPU', value: status.cpuUsage, max: 100, unit: '%', color: AppColors.info),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  final bool isMobile;
  const _StatsGridSkeleton({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 1.3 : 1.6,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => _SkeletonBox(radius: 12, height: double.infinity),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double radius, height;
  const _SkeletonBox({required this.radius, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: AppColors.surfaceHover);
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SkeletonBox(radius: 12, height: 220)),
        const SizedBox(width: 12),
        Expanded(child: _SkeletonBox(radius: 12, height: 220)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          const Expanded(child: Text('Could not connect to bot. Running in demo mode.', style: TextStyle(color: AppColors.error))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
