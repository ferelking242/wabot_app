import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants/app_constants.dart';
import 'storage_service.dart';

enum WsState { disconnected, connecting, connected, error }

class WsMessage {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  WsMessage({required this.type, required this.data}) : timestamp = DateTime.now();

  factory WsMessage.fromJson(Map<String, dynamic> json) => WsMessage(
        type: json['type'] as String? ?? 'unknown',
        data: json['data'] as Map<String, dynamic>? ?? {},
      );
}

class WebSocketService extends Notifier<WsState> {
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  String? _wsUrl;

  final _messageController = StreamController<WsMessage>.broadcast();
  Stream<WsMessage> get messages => _messageController.stream;

  @override
  WsState build() => WsState.disconnected;

  void connect({String? url}) {
    _wsUrl = url ?? StorageService.getString(AppConstants.keyApiUrl)?.replaceFirst('http', 'ws') ?? AppConstants.defaultWsUrl;
    _connect();
  }

  void _connect() {
    if (state == WsState.connecting) return;
    state = WsState.connecting;

    try {
      _channel = WebSocketChannel.connect(Uri.parse('$_wsUrl/ws'));
      state = WsState.connected;
      _retryCount = 0;
      _startHeartbeat();

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _messageController.add(WsMessage.fromJson(json));
          } catch (_) {}
        },
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
      );
    } catch (e) {
      state = WsState.error;
      _scheduleReconnect();
    }
  }

  void _onDisconnected() {
    state = WsState.disconnected;
    _heartbeatTimer?.cancel();
    if (_retryCount < AppConstants.wsMaxRetries) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _retryCount++;
    final delay = Duration(milliseconds: AppConstants.wsReconnectDelay * _retryCount.clamp(1, 5));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.wsHeartbeatInterval),
      (_) => send({'type': 'ping'}),
    );
  }

  void send(Map<String, dynamic> data) {
    if (state == WsState.connected) {
      try {
        _channel?.sink.add(jsonEncode(data));
      } catch (_) {}
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    state = WsState.disconnected;
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
  }
}

final wsServiceProvider = NotifierProvider<WebSocketService, WsState>(WebSocketService.new);
