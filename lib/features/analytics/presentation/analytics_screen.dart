import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../theme/app_colors.dart';

final analyticsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  return ref.read(apiServiceProvider).getAnalytics(period: period);
});

final periodProvider = StateProvider<String>((ref) => '7d');

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodProvider);
    final analyticsAsync = ref.watch(analyticsProvider(period));
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Analytics',
              subtitle: 'Bot performance & engagement',
              actions: [
                _PeriodSelector(period: period),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            sliver: analyticsAsync.when(
              data: (data) => SliverList(
                delegate: SliverChildListDelegate([
                  _SummaryCards(data: data, isMobile: isMobile),
                  const SizedBox(height: 20),
                  _ActivityChart(data: data),
                  const SizedBox(height: 20),
                  _TopCommandsChart(data: data),
                  const SizedBox(height: 40),
                ]),
              ),
              loading: () => SliverList(
                delegate: SliverChildListDelegate([
                  _SkeletonGrid(isMobile: isMobile),
                  const SizedBox(height: 20),
                  _SkeletonChart(),
                ]),
              ),
              error: (_, __) => SliverToBoxAdapter(
                child: Center(child: Text('Could not load analytics', style: const TextStyle(color: AppColors.textTertiary))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  final String period;
  const _PeriodSelector({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: '24h', label: Text('24h', style: TextStyle(fontSize: 12))),
        ButtonSegment(value: '7d', label: Text('7d', style: TextStyle(fontSize: 12))),
        ButtonSegment(value: '30d', label: Text('30d', style: TextStyle(fontSize: 12))),
      ],
      selected: {period},
      onSelectionChanged: (s) => ref.read(periodProvider.notifier).state = s.first,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 0)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMobile;
  const _SummaryCards({required this.data, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      _Item('Total Messages', _fmt(data['totalMessages']), Icons.message_outlined, AppColors.accent, '+${data['messagesGrowth']}%'),
      _Item('Commands Used', _fmt(data['totalCommands']), Icons.terminal_outlined, AppColors.info, '+${data['commandsGrowth']}%'),
      _Item('Groups', '${data['totalGroups'] ?? 0}', Icons.groups_outlined, AppColors.idle, null),
      _Item('Users Reached', _fmt(data['totalUsers']), Icons.people_outline, AppColors.error, null),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 1.4 : 1.8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: item.color, size: 20),
              const Spacer(),
              Text(item.value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(child: Text(item.label, style: theme.textTheme.bodySmall)),
                  if (item.growth != null)
                    Text(item.growth!, style: TextStyle(color: AppColors.online, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        )
            .animate(delay: Duration(milliseconds: 60 * i))
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.1, end: 0, duration: 300.ms);
      },
    );
  }

  String _fmt(dynamic n) {
    final v = (n as num?)?.toInt() ?? 0;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }
}

class _Item {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? growth;
  _Item(this.label, this.value, this.icon, this.color, this.growth);
}

class _ActivityChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ActivityChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daily = (data['dailyActivity'] as List? ?? []).cast<Map<String, dynamic>>();

    return Container(
      height: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Daily Activity', style: theme.textTheme.titleMedium),
              const Spacer(),
              _Legend(color: AppColors.accent, label: 'Messages'),
              const SizedBox(width: 16),
              _Legend(color: AppColors.info, label: 'Commands'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: daily.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['messages'] as num?)?.toDouble() ?? 0)).toList(),
                  isCurved: true,
                  color: AppColors.accent,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: AppColors.accent.withOpacity(0.07)),
                ),
                LineChartBarData(
                  spots: daily.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['commands'] as num?)?.toDouble() ?? 0)).toList(),
                  isCurved: true,
                  color: AppColors.info,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: AppColors.info.withOpacity(0.07)),
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
            )),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _TopCommandsChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TopCommandsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commands = (data['topCommands'] as List? ?? []).cast<Map<String, dynamic>>();
    if (commands.isEmpty) return const SizedBox.shrink();
    final maxCount = (commands.first['count'] as num?)?.toDouble() ?? 1;

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
          Text('Top Commands', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          ...commands.asMap().entries.map((e) {
            final cmd = e.value['command'] as String? ?? '';
            final count = (e.value['count'] as num?)?.toInt() ?? 0;
            final pct = count / maxCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(cmd, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: AppColors.accent)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: AppColors.surfaceElevated,
                        valueColor: AlwaysStoppedAnimation(AppColors.chartPalette[e.key % AppColors.chartPalette.length]),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text('$count', style: theme.textTheme.bodySmall, textAlign: TextAlign.right),
                  ),
                ],
              ),
            ).animate(delay: Duration(milliseconds: 60 * e.key)).fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
          }),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
}

class _SkeletonGrid extends StatelessWidget {
  final bool isMobile;
  const _SkeletonGrid({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: isMobile ? 1.4 : 1.8,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: AppColors.surfaceHover),
    );
  }
}

class _SkeletonChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: AppColors.surfaceHover);
  }
}
