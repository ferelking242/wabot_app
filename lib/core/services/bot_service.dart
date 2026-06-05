import 'dart:io';

import 'package:flutter/services.dart';

import 'platform_service.dart';

class BotService {
  static const _channel = MethodChannel('com.aivos.wabot/bot_engine');
  static const _events  = EventChannel('com.aivos.wabot/bot_events');

  static bool _started = false;

  /// Starts the embedded Node.js bot if we're on Android (local bot platform).
  /// Safe to call multiple times — it's a no-op after the first call.
  static Future<void> startIfNeeded() async {
    if (!PlatformService.runsLocalBot) return;
    if (!Platform.isAndroid)           return;
    if (_started)                      return;

    try {
      final dataDir = await _getDataDir();
      final result  = await _channel.invokeMethod<bool>(
        'startBot',
        {'dataDir': dataDir},
      );
      if (result == true) {
        _started = true;
        debugPrint('[BotService] Embedded bot started');
      }
    } on PlatformException catch (e) {
      debugPrint('[BotService] Failed to start bot: ${e.message}');
    }
  }

  static Future<String> _getDataDir() async {
    // filesDir equivalent — Android internal storage
    return '/data/data/com.aivos.wabot.app/files/wabot';
  }

  /// Stream of messages coming from Node.js (via the bridge channel)
  static Stream<Map<String, dynamic>> get nodeMessages =>
      _events.receiveBroadcastStream().map((event) =>
          Map<String, dynamic>.from(event as Map));

  static bool get isStarted => _started;

  // ignore: avoid_print
  static void debugPrint(String msg) => print(msg);
}
