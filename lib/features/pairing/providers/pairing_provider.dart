import 'dart:async';
    import 'package:flutter_riverpod/flutter_riverpod.dart';
    import '../../../presentation/providers/auth_providers.dart';
    import '../../../services/api_service.dart';
    import '../../../core/services/supabase_service.dart';
    import '../../../core/services/log_service.dart';

    enum PairingStatus { idle, loading, botStarting, waitingQr, waitingCode, connected, error }

    class PairingState {
      final PairingStatus status;
      final String? qrString;
      final String? pairingCode;
      final String? error;
      final int qrExpiresIn;
      final String? startingMessage;
      final String? whatsappJid;
      final String? whatsappPhone;

      const PairingState({
        this.status = PairingStatus.idle,
        this.qrString,
        this.pairingCode,
        this.error,
        this.qrExpiresIn = 60,
        this.startingMessage,
        this.whatsappJid,
        this.whatsappPhone,
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
        String? startingMessage,
        bool clearStartingMessage = false,
        String? whatsappJid,
        String? whatsappPhone,
      }) =>
          PairingState(
            status: status ?? this.status,
            qrString: clearQr ? null : (qrString ?? this.qrString),
            pairingCode: clearCode ? null : (pairingCode ?? this.pairingCode),
            error: clearError ? null : (error ?? this.error),
            qrExpiresIn: qrExpiresIn ?? this.qrExpiresIn,
            startingMessage: clearStartingMessage
                ? null
                : (startingMessage ?? this.startingMessage),
            whatsappJid: whatsappJid ?? this.whatsappJid,
            whatsappPhone: whatsappPhone ?? this.whatsappPhone,
          );
    }

    class PairingNotifier extends Notifier<PairingState> {
      Timer? _qrTimer;
      Timer? _statusTimer;
      Timer? _retryTimer;
      bool _disposed = false;
      int _pairRetries = 0;
      String? _pendingPhone;
      static const int _maxPairRetries = 10;

      @override
      PairingState build() {
        ref.onDispose(() {
          _disposed = true;
          _qrTimer?.cancel();
          _statusTimer?.cancel();
          _retryTimer?.cancel();
        });
        return const PairingState();
      }

      ApiService get _api => ref.read(apiServiceProvider);

      /// Appelé dès que WhatsApp est connecté.
      /// 1) Marque le setup done (navigation vers /home).
      /// 2) Enregistre le device sur Supabase (device_id, RAM, model, etc.).
      Future<void> _onConnected(String jid, String phone) async {
        await ref.read(authProvider.notifier).markSetupDone();
        try {
          await SupabaseService.registerDevice(
            whatsappJid:   jid.isNotEmpty   ? jid   : phone,
            whatsappPhone: phone,
          );
          LogService.info('PairingProvider', 'Device enregistré sur Supabase ✅ ($phone)');
        } catch (e) {
          LogService.warn('PairingProvider', 'Supabase registerDevice: $e');
        }
      }

      Future<void> checkStatus() async {
        state = state.copyWith(status: PairingStatus.loading, clearError: true);
        try {
          final data = await _api.getInstanceStatus();
          if (data['instance']?['connected'] == true) {
            _stopTimers();
            final rawPhone = (data['instance']?['phone'] as String?) ?? '';
            final phone = rawPhone.replaceAll('@s.whatsapp.net', '').replaceAll(RegExp(r':.*'), '');
            state = state.copyWith(
              status: PairingStatus.connected,
              whatsappJid: rawPhone,
              whatsappPhone: phone,
            );
            await _onConnected(rawPhone, phone);
          } else {
            state = state.copyWith(status: PairingStatus.idle);
          }
        } catch (_) {
          state = state.copyWith(status: PairingStatus.idle);
        }
      }

      void startQrPolling() {
        _stopTimers();
        _retryTimer = Timer(const Duration(seconds: 2), () {
          if (_disposed) return;
          _fetchQr();
          _qrTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchQr());
          _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollConnection());
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
            await _onConnected('', state.whatsappPhone ?? '');
            return;
          }
          if (data['qr'] != null) {
            _qrTimer?.cancel();
            _qrTimer = Timer.periodic(const Duration(seconds: 25), (_) => _fetchQr());
            state = state.copyWith(
              status: PairingStatus.waitingQr,
              qrString: data['qr'] as String,
              qrExpiresIn: (data['expiresInSeconds'] as int?) ?? 60,
              clearError: true,
              clearStartingMessage: true,
            );
          } else {
            if (state.status != PairingStatus.waitingQr) {
              state = state.copyWith(
                status: PairingStatus.botStarting,
                startingMessage: 'Demarrage du bot...',
                clearError: true,
              );
            }
          }
        } catch (_) {
          if (state.status != PairingStatus.waitingQr) {
            state = state.copyWith(
              status: PairingStatus.botStarting,
              startingMessage: 'Demarrage du bot...',
              clearError: true,
            );
          }
        }
      }

      Future<void> requestPairingCode(String phone) async {
        _pairRetries = 0;
        _pendingPhone = phone;
        _stopTimers();
        state = state.copyWith(
            status: PairingStatus.loading,
            clearError: true,
            clearCode: true,
            clearStartingMessage: true);
        await _tryPairingCode(phone);
      }

      Future<void> _tryPairingCode(String phone) async {
        if (_disposed) return;
        try {
          final data = await _api.requestPairingCode(phone);
          if (data['connected'] == true) {
            state = state.copyWith(
              status: PairingStatus.connected,
              whatsappPhone: phone,
            );
            await _onConnected('', phone);
            return;
          }
          if (data['code'] != null) {
            state = state.copyWith(
              status: PairingStatus.waitingCode,
              pairingCode: data['code'] as String,
              clearStartingMessage: true,
            );
            _statusTimer = Timer.periodic(
                const Duration(seconds: 3), (_) => _pollConnection());
            return;
          }
          final msg = data['message'] as String? ?? '';
          final errCode = data['error'] as String? ?? '';
          final isStarting = msg.toLowerCase().contains('starting') ||
              errCode.contains('BOT_NOT_STARTED');
          if (isStarting && _pairRetries < _maxPairRetries) {
            _pairRetries++;
            state = state.copyWith(
              status: PairingStatus.botStarting,
              startingMessage: 'Bot en demarrage... ($_pairRetries/$_maxPairRetries)',
              clearError: true,
            );
            _retryTimer = Timer(
                const Duration(seconds: 3), () => _tryPairingCode(phone));
          } else {
            state = state.copyWith(
              status: PairingStatus.error,
              error: msg.isNotEmpty ? msg : 'Erreur lors de la generation du code.',
            );
          }
        } catch (e) {
          final msg = e.toString();
          final isConnRefused = msg.contains('Connection refused') ||
              msg.contains('SocketException') ||
              msg.contains('ECONNREFUSED');
          if (isConnRefused && _pairRetries < _maxPairRetries) {
            _pairRetries++;
            state = state.copyWith(
              status: PairingStatus.botStarting,
              startingMessage: 'Demarrage du bot... $_pairRetries/$_maxPairRetries',
              clearError: true,
            );
            _retryTimer = Timer(
                const Duration(seconds: 3), () => _tryPairingCode(phone));
          } else {
            state = state.copyWith(
              status: PairingStatus.error,
              error: 'Impossible de joindre le bot. Patientez et reessayez.',
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
            final rawPhone = (data['instance']?['phone'] as String?) ?? '';
            final phone = rawPhone.replaceAll('@s.whatsapp.net', '').replaceAll(RegExp(r':.*'), '');
            state = state.copyWith(
              status: PairingStatus.connected,
              whatsappJid: rawPhone,
              whatsappPhone: phone,
            );
            await _onConnected(rawPhone, phone);
          }
        } catch (_) {}
      }

      void reset() {
        _stopTimers();
        _pairRetries = 0;
        _pendingPhone = null;
        state = const PairingState();
      }

      Future<void> resetBot() async {
        _stopTimers();
        _pairRetries = 0;
        _pendingPhone = null;
        state = const PairingState(
          status: PairingStatus.botStarting,
          startingMessage: 'Reinitialisation...',
        );
        try {
          await _api.resetBot();
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 2));
        if (_disposed) return;
        state = const PairingState();
        startQrPolling();
      }

      void _stopTimers() {
        _qrTimer?.cancel();
        _statusTimer?.cancel();
        _retryTimer?.cancel();
        _qrTimer = null;
        _statusTimer = null;
        _retryTimer = null;
      }
    }

    final pairingProvider =
        NotifierProvider<PairingNotifier, PairingState>(PairingNotifier.new);
    