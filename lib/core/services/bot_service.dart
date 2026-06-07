import 'dart:io';
import 'package:flutter/services.dart';
import 'platform_service.dart';
import 'log_service.dart';

class BotService {
  static const _channel = MethodChannel('com.aivos.wabot/bot_engine');
  static const _events  = EventChannel('com.aivos.wabot/bot_events');
  static const _TAG     = 'BotService';

  static bool _started = false;

  static Future<void> startIfNeeded() async {
    if (!PlatformService.runsLocalBot) return;
    if (!Platform.isAndroid) return;
    if (_started) return;

    try {
      final dataDir = _dataDir;
      LogService.info(_TAG, 'Démarrage du bot embedded...');
      final result = await _channel.invokeMethod<bool>('startBot', {'dataDir': dataDir});
      if (result == true) {
        _started = true;
        LogService.info(_TAG, 'Bot démarré avec succès ✅');
        // Démarrer le ForegroundService pour garder le process en vie
        await _startForegroundService();
      }
    } on PlatformException catch (e) {
      LogService.error(_TAG, 'Echec démarrage: ${e.message}', err: e);
    } catch (e, s) {
      LogService.error(_TAG, 'Erreur inattendue: $e', err: e, stack: s);
    }
  }

  static Future<void> _startForegroundService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } catch (_) {}
  }

  static Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }

  static String get _dataDir => '/data/data/com.aivos.wabot.app/files/wabot';

  static Stream<Map<String, dynamic>> get nodeMessages =>
      _events.receiveBroadcastStream().map((event) =>
          Map<String, dynamic>.from(event as Map));

  static bool get isStarted => _started;

  /// Remet à zéro le flag pour permettre un redémarrage forcé
  static void resetStartedFlag() => _started = false;
}
