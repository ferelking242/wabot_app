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

  @override
  PairingState build() {
    ref.onDispose(() {
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
    _fetchQr();
    _qrTimer = Timer.periodic(const Duration(seconds: 25), (_) => _fetchQr());
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollConnection());
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
    } catch (e) {
      if (state.qrString == null) {
        state = state.copyWith(
          error: 'Impossible de charger le QR. Vérifiez la connexion au serveur.',
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
        state = state.copyWith(
          status: PairingStatus.error,
          error: (data['message'] as String?) ?? 'Erreur lors de la génération du code.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: PairingStatus.error,
        error: 'Erreur réseau: vérifiez l\'URL du serveur.',
      );
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
