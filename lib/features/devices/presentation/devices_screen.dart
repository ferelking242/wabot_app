import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

final sessionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => ref.read(apiServiceProvider).getSessions());

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Devices',
              subtitle: 'Manage WhatsApp sessions',
              actions: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code, size: 16),
                  label: const Text('Link Device'),
                  onPressed: () => context.go(AppConstants.routePair),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            sliver: sessionsAsync.when(
              data: (sessions) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _SessionCard(session: sessions[i], index: i, ref: ref),
                  childCount: sessions.length,
                ),
              ),
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Container(
                    height: 100,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)),
                  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: AppColors.surfaceHover),
                  childCount: 2,
                ),
              ),
              error: (_, __) => SliverToBoxAdapter(
                child: Center(child: Text('Could not load sessions', style: theme.textTheme.bodyMedium)),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final int index;
  final WidgetRef ref;

  const _SessionCard({required this.session, required this.index, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = session['status'] as String? ?? 'offline';
    final connectedAt = DateTime.tryParse(session['connectedAt'] as String? ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentBorder),
            ),
            child: const Icon(Icons.phone_android, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(session['name'] as String? ?? 'Session', style: theme.textTheme.titleSmall),
                    const SizedBox(width: 8),
                    StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  session['phoneNumber'] as String? ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
                const SizedBox(height: 2),
                Text(
                  'Connected ${timeago.format(connectedAt)}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
            onSelected: (v) async {
              if (v == 'delete') {
                final api = ref.read(apiServiceProvider);
                await api.deleteSession(session['id'] as String);
                ref.invalidate(sessionsProvider);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'reconnect', child: Text('Reconnect')),
              const PopupMenuItem(value: 'delete', child: Text('Remove', style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: 80 * index))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.05, end: 0, duration: 300.ms);
  }
}
