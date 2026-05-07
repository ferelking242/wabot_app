import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import '../../../shared/models/bot_status.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

final _logsProvider = AsyncNotifierProvider<LogsNotifier, List<LogEntry>>(LogsNotifier.new);

class LogsNotifier extends AsyncNotifier<List<LogEntry>> {
  Timer? _timer;

  @override
  Future<List<LogEntry>> build() async {
    _startPolling();
    ref.onDispose(() => _timer?.cancel());
    return _fetch();
  }

  Future<List<LogEntry>> _fetch() async {
    final api = ref.read(apiServiceProvider);
    final raw = await api.getLogs(limit: AppConstants.maxLogLines);
    return raw.map(LogEntry.fromJson).toList().reversed.toList();
  }

  void _startPolling() {
    _timer = Timer.periodic(
      const Duration(milliseconds: AppConstants.logsRefreshInterval * 5),
      (_) async {
        try {
          final logs = await _fetch();
          state = AsyncData(logs);
        } catch (_) {}
      },
    );
  }

  Future<void> refresh() async => state = await AsyncValue.guard(_fetch);
}

final _logFilterProvider = StateProvider<String?>((ref) => null);
final _searchProvider = StateProvider<String>((ref) => '');

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _autoScroll = true;

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(_logsProvider);
    final filter = ref.watch(_logFilterProvider);
    final search = ref.watch(_searchProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          PageHeader(
            title: 'Logs',
            subtitle: 'Live bot activity stream',
            actions: [
              _FilterChip(label: 'All', value: null, selected: filter == null),
              const SizedBox(width: 6),
              _FilterChip(label: 'Info', value: 'info', selected: filter == 'info'),
              const SizedBox(width: 6),
              _FilterChip(label: 'Warn', value: 'warn', selected: filter == 'warn'),
              const SizedBox(width: 6),
              _FilterChip(label: 'Error', value: 'error', selected: filter == 'error'),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.pause, size: 18),
                tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () => ref.read(_logsProvider.notifier).refresh(),
              ),
            ],
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          // Terminal
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0B0D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: logsAsync.when(
                  data: (logs) {
                    final filtered = logs.where((l) {
                      if (filter != null && l.level != filter) return false;
                      if (search.isNotEmpty && !l.message.toLowerCase().contains(search.toLowerCase())) return false;
                      return true;
                    }).toList();

                    if (_autoScroll) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                        }
                      });
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _LogLine(entry: filtered[i], index: i),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
                  error: (_, __) => const Center(child: Text('No logs available', style: TextStyle(color: AppColors.textTertiary))),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

class _LogLine extends StatelessWidget {
  final LogEntry entry;
  final int index;

  const _LogLine({required this.entry, required this.index});

  Color get _color => switch (entry.level) {
        'error' => AppColors.logError,
        'warn' => AppColors.logWarn,
        'success' => AppColors.logSuccess,
        'info' => AppColors.logInfo,
        _ => AppColors.logDebug,
      };

  String get _prefix => switch (entry.level) {
        'error' => 'ERR',
        'warn' => 'WRN',
        'success' => 'SUC',
        'info' => 'INF',
        _ => 'DBG',
      };

  @override
  Widget build(BuildContext context) {
    final time = '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => Clipboard.setData(ClipboardData(text: '[$time] [${entry.level.toUpperCase()}] ${entry.message}')),
      hoverColor: Colors.white.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(time, style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'monospace', fontSize: 11)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(_prefix, style: TextStyle(color: _color, fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.message,
                style: TextStyle(color: _color.withOpacity(0.9), fontFamily: 'monospace', fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends ConsumerWidget {
  final String label;
  final String? value;
  final bool selected;

  const _FilterChip({required this.label, required this.value, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(_logFilterProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? AppColors.accentBorder : AppColors.surfaceBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
