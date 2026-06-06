import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../services/api_service.dart';

enum PairingStatus { idle, loading, waitingQr, waitingCode, connected, error }

class PairingState {
  final PairingStatus status;
  final String? qrString;
  final String? pairingCode;
  final String? error;
  final int qrExpiresIn;

  const PairingState({
    this.status = PairingStatus.idle,
    this.qrString,
    this.pairingCode,
    this.error,
    this.qrExpiresIn = 60,
  });

  PairingState copyWith({
    PairingStatus? status,
    String? qrString,
    bool clearQr = false,
    String? pairingCode,
    bool clearCode = false,
    String? error,
    bool clearError = false,
    int? qrExpiresIn,
  }) =>
      PairingState(
        status: status ?? this.status,
        qrString: clearQr ? null : (qrString ?? this.qrString),
        pairingCode: clearCode ? null : (pairingCode ?? this.pairingCode),
        error: clearError ? null : (error ?? this.error),
        qrExpiresIn: qrExpiresIn ?? this.qrExpiresIn,
      );
}

class PairingNotifier extends Notifier<PairingState> {
  Timer? _qrTimer;
  Timer? _statusTimer;
  bool _disposed = false;

  @override
  PairingState build() {
    ref.onDispose(() {
      _disposed = true;
      _qrTimer?.cancel();
      _statusTimer?.cancel();
    });
    return const PairingState();
  }

  ApiService get _api => ref.read(apiServiceProvider);

  Future<void> checkStatus() async {
    state = state.copyWith(status: PairingStatus.loading, clearError: true);
    try {
      final data = await _api.getInstanceStatus();
      if (data['instance']?['connected'] == true) {
        _stopTimers();
        state = state.copyWith(status: PairingStatus.connected);
        await ref.read(authProvider.notifier).markSetupDone();
      } else {
        state = state.copyWith(status: PairingStatus.idle);
      }
    } catch (_) {
      state = state.copyWith(status: PairingStatus.idle);
    }
  }

  void startQrPolling() {
    _stopTimers();
    // Give the embedded Node.js bot ~2s to finish starting up before first request
    Future.delayed(const Duration(seconds: 2), () {
      if (_disposed) return;
      _fetchQr();
      _qrTimer   = Timer.periodic(const Duration(seconds: 25), (_) => _fetchQr());
      _statusTimer = Timer.periodic(const Duration(seconds: 3),  (_) => _pollConnection());
    });
  }

  void stopPolling() => _stopTimers();

  Future<void> _fetchQr() async {
    if (state.status == PairingStatus.connected) return;
    try {
      final data = await _api.getQrCode();
      if (data['connected'] == true) {
        _stopTimers();
        state = state.copyWith(status: PairingStatus.connected);
        await ref.read(authProvider.notifier).markSetupDone();
        return;
      }
      if (data['qr'] != null) {
        state = state.copyWith(
          status: PairingStatus.waitingQr,
          qrString: data['qr'] as String,
          qrExpiresIn: (data['expiresInSeconds'] as int?) ?? 60,
          clearError: true,
        );
      }
    } catch (_) {
      if (state.qrString == null) {
        state = state.copyWith(
          error: 'Bot en cours de démarrage… Patientez quelques secondes.',
        );
      }
    }
  }

  Future<void> requestPairingCode(String phone) async {
    state = state.copyWith(status: PairingStatus.loading, clearError: true, clearCode: true);
    _stopTimers();
    try {
      final data = await _api.requestPairingCode(phone);
      if (data['connected'] == true) {
        state = state.copyWith(status: PairingStatus.connected);
        await ref.read(authProvider.notifier).markSetupDone();
        return;
      }
      if (data['code'] != null) {
        state = state.copyWith(
          status: PairingStatus.waitingCode,
          pairingCode: data['code'] as String,
        );
        _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollConnection());
      } else {
        final msg = data['message'] as String?;
        if (msg == 'Bot still starting. Retry in a moment.') {
          state = state.copyWith(
            status: PairingStatus.error,
            error: 'Bot encore en démarrage — réessayez dans quelques secondes.',
          );
        } else {
          state = state.copyWith(
            status: PairingStatus.error,
            error: msg ?? 'Erreur lors de la génération du code.',
          );
        }
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Connection refused') || msg.contains('SocketException')) {
        state = state.copyWith(
          status: PairingStatus.error,
          error: 'Bot encore en démarrage — patientez quelques secondes puis réessayez.',
        );
      } else {
        state = state.copyWith(
          status: PairingStatus.error,
          error: 'Impossible de contacter le bot. Vérifiez qu\'il est démarré.',
        );
      }
    }
  }

  Future<void> _pollConnection() async {
    if (state.status == PairingStatus.connected) return;
    try {
      final data = await _api.getInstanceStatus();
      if (data['instance']?['connected'] == true) {
        _stopTimers();
        state = state.copyWith(status: PairingStatus.connected);
        await ref.read(authProvider.notifier).markSetupDone();
      }
    } catch (_) {}
  }

  void reset() {
    _stopTimers();
    state = const PairingState();
  }

  void _stopTimers() {
    _qrTimer?.cancel();
    _statusTimer?.cancel();
    _qrTimer = null;
    _statusTimer = null;
  }
}

final pairingProvider =
    NotifierProvider<PairingNotifier, PairingState>(PairingNotifier.new);
