import 'dart:io';
  import 'package:flutter/services.dart';
  import 'platform_service.dart';
  import 'log_service.dart';

  class BotService {
    static const _channel = MethodChannel('com.aivos.wabot/bot_engine');
    static const _TAG     = 'BotService';

    static bool _started = false;

    static Future<void> startIfNeeded() async {
      if (!PlatformService.runsLocalBot) return;
      if (!Platform.isAndroid) return;
      if (_started) return;

      try {
        LogService.info(_TAG, 'Démarrage du bot embedded...');
        final result = await _channel.invokeMethod<bool>('startBot', {'dataDir': _dataDir});
        if (result == true) {
          _started = true;
          LogService.info(_TAG, 'Bot démarré ✅');
          await _startForegroundService();
        }
      } on PlatformException catch (e) {
        LogService.error(_TAG, 'Echec démarrage: ${e.message}', err: e);
      } catch (e, s) {
        LogService.error(_TAG, 'Erreur: $e', err: e, stack: s);
      }
    }

    /// Appelé depuis OnboardingScreen dès que MANAGE_EXTERNAL_STORAGE est accordé.
    /// Crée /storage/emulated/0/wabot/ et initialise les logs externes.
    static Future<void> onExternalStorageGranted() async {
      try {
        const root = LogService.externalRoot;
        final dir = Directory(root);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
          LogService.info(_TAG, 'Dossier $root créé ✅');
        }
        // Sous-dossiers standards
        for (final sub in ['logs', 'auth_state', 'media', 'exports']) {
          Directory('$root/$sub').createSync(recursive: true);
        }
        // Init logs externes dans LogService
        await LogService.I.initExternalStorage();
      } catch (e) {
        LogService.warn(_TAG, 'onExternalStorageGranted: $e');
      }
    }

    static Future<void> _startForegroundService() async {
      try { await _channel.invokeMethod('startForegroundService'); } catch (_) {}
    }

    static Future<void> stopForegroundService() async {
      try { await _channel.invokeMethod('stopForegroundService'); } catch (_) {}
    }

    static String get _dataDir => '/data/data/com.aivos.wabot.app/files/wabot';

    static bool get isStarted => _started;

    static void resetStartedFlag() => _started = false;
  }
  