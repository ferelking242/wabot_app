import 'package:flutter/foundation.dart';

/// Determines bot connectivity based on the current platform.
///
/// Android / Windows / macOS / Linux → bot runs embedded (localhost)
/// iOS / Web                         → bot runs on Aivos Central server
abstract final class PlatformService {
  static const String aivosCentralUrl = 'https://api.aivos.app';
  static const String localBotUrl     = 'http://localhost:3001';
  static const String localBotWsUrl   = 'ws://localhost:3001';
  static const String centralWsUrl    = 'wss://api.aivos.app';

  // Internal key used when talking to the embedded local bot.
  // wabot accepts this key when the request comes from localhost.
  static const String localApiKey = 'wabot_embedded_v1';

  static bool get isWeb => kIsWeb;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// True on platforms where the Node.js bot runs inside the app.
  static bool get runsLocalBot {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) return false;
    return true; // Android, Windows, macOS, Linux
  }

  static String get botApiUrl =>
      runsLocalBot ? localBotUrl : aivosCentralUrl;

  static String get botWsUrl =>
      runsLocalBot ? localBotWsUrl : centralWsUrl;

  static String get botApiKey =>
      runsLocalBot ? localApiKey : '';

  static String get platformLabel {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return 'Android';
      case TargetPlatform.iOS:     return 'iOS';
      case TargetPlatform.windows: return 'Windows';
      case TargetPlatform.macOS:   return 'macOS';
      case TargetPlatform.linux:   return 'Linux';
      default:                     return 'Unknown';
    }
  }
}
