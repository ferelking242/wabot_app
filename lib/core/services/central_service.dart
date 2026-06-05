import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform_service.dart';

/// Registers this device with the Aivos Central server (background, silent).
/// If the server is unreachable, everything fails silently.
class CentralService {
  static const _kUserId  = 'aivos_user_id';
  static const _kToken   = 'aivos_token';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: PlatformService.aivosCentralUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'Content-Type': 'application/json'},
  ));

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Register or re-register this device. Saves user_id + token locally.
  Future<void> register({String? phone}) async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final existing = prefs.getString(_kUserId);

      final res = await _dio.post('/v1/devices/register', data: {
        'phone':    phone,
        'platform': PlatformService.platformLabel,
        'version':  '1.0.0',
        if (existing != null) 'user_id': existing,
      });

      final data = res.data as Map<String, dynamic>? ?? {};
      if (data['user_id'] != null) {
        await prefs.setString(_kUserId, data['user_id'] as String);
      }
      if (data['token'] != null) {
        await prefs.setString(_kToken, data['token'] as String);
      }
    } catch (_) {
      // Server not deployed yet — silent fail
    }
  }

  /// Fire-and-forget analytics event.
  void trackEvent(String name, [Map<String, dynamic>? props]) {
    _sendEvent(name, props ?? {});
  }

  /// Send a heartbeat so the admin panel shows the device as "online".
  Future<void> heartbeat() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final userId = prefs.getString(_kUserId);
      final token  = prefs.getString(_kToken);
      if (userId == null || token == null) return;

      await _dio.post('/v1/devices/heartbeat',
        data: {'user_id': userId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _sendEvent(String name, Map<String, dynamic> props) async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final userId = prefs.getString(_kUserId);
      final token  = prefs.getString(_kToken);

      await _dio.post('/v1/analytics/event',
        data: {
          'event':      name,
          'user_id':    userId,
          'platform':   PlatformService.platformLabel,
          'properties': props,
          'ts':         DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        }),
      );
    } catch (_) {}
  }
}

final centralService = CentralService();
