import 'dart:io';
  import 'package:device_info_plus/device_info_plus.dart';
  import 'package:flutter/foundation.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:package_info_plus/package_info_plus.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';

  const _supabaseUrl = 'https://nublrlyhdbeoqimntdrl.supabase.co';
  const _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im51YmxybHloZGJlb3FpbW50ZHJsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxMTM5MzYsImV4cCI6MjA5MzY4OTkzNn0'
      '.YHbAa1We4qfyvc2bcQzQEu0fabK0I6ifQRtIe43Y2nU';

  class SupabaseService {
    static bool _initialized = false;

    static Future<void> initialize() async {
      if (_initialized) return;
      await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
      _initialized = true;
    }

    static SupabaseClient get client => Supabase.instance.client;

    static Future<Map<String, dynamic>> collectDeviceInfo() async {
      final info = <String, dynamic>{};
      try {
        final pkg = await PackageInfo.fromPlatform();
        info['app_version'] = pkg.version;
        info['app_build']   = pkg.buildNumber;
        info['platform']    = defaultTargetPlatform.name;

        final plugin = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final android = await plugin.androidInfo;
          info['device_id']           = android.id;
          info['device_name']         = android.device;
          info['device_model']        = android.model;
          info['device_brand']        = android.brand;
          info['device_manufacturer'] = android.manufacturer;
          info['device_os']           = 'Android';
          info['device_os_version']   = android.version.release;
          info['device_sdk_int']      = android.version.sdkInt;
        } else if (Platform.isIOS) {
          final ios = await plugin.iosInfo;
          info['device_id']         = ios.identifierForVendor ?? '';
          info['device_name']       = ios.name;
          info['device_model']      = ios.model;
          info['device_brand']      = 'Apple';
          info['device_os']         = 'iOS';
          info['device_os_version'] = ios.systemVersion;
        }
      } catch (e) {
        debugPrint('SupabaseService.collectDeviceInfo error: $e');
      }
      return info;
    }

    static Future<String?> registerDevice({
      required String whatsappJid,
      required String whatsappPhone,
      Map<String, dynamic>? extraInfo,
    }) async {
      try {
        await initialize();
        final deviceInfo = await collectDeviceInfo();
        final row = <String, dynamic>{
          ...deviceInfo,
          if (extraInfo != null) ...extraInfo,
          'whatsapp_jid':   whatsappJid,
          'whatsapp_phone': whatsappPhone,
          'last_seen':      DateTime.now().toIso8601String(),
          'bot_status':     'connected',
        };

        final response = await client
            .from('wabot_devices')
            .upsert(row, onConflict: 'device_id')
            .select('id')
            .maybeSingle();

        return response?['id'] as String?;
      } catch (e) {
        debugPrint('SupabaseService.registerDevice error: $e');
        return null;
      }
    }

    static Future<AuthResponse?> createAccount(String email, String password) async {
      try {
        await initialize();
        return await client.auth.signUp(email: email, password: password);
      } catch (e) {
        debugPrint('SupabaseService.createAccount error: $e');
        return null;
      }
    }

    static Future<AuthResponse?> signIn(String email, String password) async {
      try {
        await initialize();
        return await client.auth.signInWithPassword(email: email, password: password);
      } catch (e) {
        debugPrint('SupabaseService.signIn error: $e');
        return null;
      }
    }

    static Future<void> linkAccount({
      required String deviceRecordId,
      required String userId,
      required String email,
    }) async {
      try {
        await initialize();
        await client.from('wabot_devices').update({
          'user_id': userId,
          'email':   email,
        }).eq('id', deviceRecordId);
      } catch (e) {
        debugPrint('SupabaseService.linkAccount error: $e');
      }
    }
  }

  final supabaseServiceProvider = Provider<SupabaseService>((_) => SupabaseService());
  