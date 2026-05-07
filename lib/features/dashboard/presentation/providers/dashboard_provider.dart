import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/bot_status.dart';
import '../../../../core/constants/app_constants.dart';

final botStatusProvider = AsyncNotifierProvider<BotStatusNotifier, BotStatus>(BotStatusNotifier.new);

class BotStatusNotifier extends AsyncNotifier<BotStatus> {
  Timer? _timer;

  @override
  Future<BotStatus> build() async {
    _startPolling();
    ref.onDispose(() => _timer?.cancel());
    return _fetch();
  }

  Future<BotStatus> _fetch() async {
    final api = ref.read(apiServiceProvider);
    final data = await api.getBotStatus();
    return BotStatus.fromJson(data);
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: AppConstants.dashboardRefreshInterval),
      (_) async {
        try {
          final status = await _fetch();
          state = AsyncData(status);
        } catch (_) {}
      },
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final metricsProvider = AsyncNotifierProvider<MetricsNotifier, Map<String, dynamic>>(MetricsNotifier.new);

class MetricsNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    return ref.read(apiServiceProvider).getMetrics();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(apiServiceProvider).getMetrics());
  }
}
