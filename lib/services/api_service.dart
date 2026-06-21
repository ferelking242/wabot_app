import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/services/platform_service.dart';

class ApiService {
  late final Dio _dio;

  ApiService({required String baseUrl, String? apiKey}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.apiTimeout),
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey.isNotEmpty) 'X-API-Key': apiKey,
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: true,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final key = PlatformService.botApiKey;
        if (key.isNotEmpty) options.headers['X-API-Key'] = key;
        handler.next(options);
      },
      onError: (error, handler) {
        final message = error.response?.data?['message'] ?? error.message ?? 'Unknown error';
        handler.next(DioException(
          requestOptions: error.requestOptions,
          error: message,
          type: error.type,
          response: error.response,
        ));
      },
    ));
  }

  void updateBaseUrl(String url) => _dio.options.baseUrl = url;
  void updateApiKey(String key) => _dio.options.headers['X-API-Key'] = key;

  // ── Instance / Connection ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getInstanceStatus() async {
    try {
      final res = await _dio.get(AppConstants.apiStatus);
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return {'instance': <String, dynamic>{'connected': false}};
    }
  }

  Future<Map<String, dynamic>> getQrCode() async {
    try {
      final res = await _dio.get(AppConstants.apiQr);
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{'connected': false, 'qr': null};
    }
  }

  Future<Map<String, dynamic>> requestPairingCode(String phone) async {
    final res = await _dio.post(AppConstants.apiPair, data: {'phone': phone});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reconnect() async {
    try {
      final res = await _dio.post('/api/v1/instance/reconnect');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{'success': false};
    }
  }

  // ── Bot info & profile ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getBotInfo() async {
    try {
      final res = await _dio.get(AppConstants.apiInfo);
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> getBotStatus() async {
    try {
      final res = await _dio.get(AppConstants.apiStatus);
      final d    = res.data as Map<String, dynamic>;
      final inst = d['instance'] as Map<String, dynamic>? ?? {};
      final proc = d['process']  as Map<String, dynamic>? ?? {};
      final mem  = proc['memory'] as Map<String, dynamic>? ?? {};
      return {
        'status':        inst['connected'] == true ? 'online' : 'offline',
        'uptime':        proc['uptime'] ?? 0,
        'phoneNumber':   inst['phone']  ?? '',
        'name':          inst['name']   ?? 'Wabot',
        'profilePicUrl': inst['profilePicUrl'] ?? inst['picture'] ?? '',
        'sessionsCount': 1,
        'groupsCount':   0,
        'messagesTotal': 0,
        'messagesPerMin': 0,
        'ramUsage':  _parseRam(mem['heapUsed']),
        'ramTotal':  _parseRam(mem['rss']),
        'cpuUsage':  0.0,
        'wsLatency': 0,
        'lastSeen':  DateTime.now().toIso8601String(),
        'version':   AppConstants.appVersion,
        'node':      proc['node'] ?? '',
      };
    } catch (_) {
      return {
        'status': 'offline', 'uptime': 0, 'phoneNumber': '', 'name': 'Wabot',
        'profilePicUrl': '',
        'sessionsCount': 0, 'groupsCount': 0, 'messagesTotal': 0, 'messagesPerMin': 0,
        'ramUsage': 0, 'ramTotal': 0, 'cpuUsage': 0.0, 'wsLatency': 0,
        'lastSeen': DateTime.now().toIso8601String(), 'version': AppConstants.appVersion,
      };
    }
  }

  int _parseRam(dynamic val) {
    if (val == null) return 0;
    if (val is int) {
      if (val > 10 * 1024 * 1024) return val ~/ (1024 * 1024); // bytes → MB
      if (val > 10 * 1024) return val ~/ 1024;                 // KB → MB
      return val;
    }
    final s = val.toString().trim();
    if (s.isEmpty) return 0;
    final num = int.tryParse(s.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    // Raw bytes (> 10 MB threshold)
    if (num > 10 * 1024 * 1024) return num ~/ (1024 * 1024);
    // Raw KB (> 10 MB threshold, no 'MB' in string)
    if (num > 10 * 1024 && !s.toUpperCase().contains('MB')) return num ~/ 1024;
    return num; // Already MB
  }

  // ── Groups ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getGroups() async {
    try {
      final res  = await _dio.get(AppConstants.apiGroups);
      final data = res.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map && data['groups'] is List) {
        return (data['groups'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Messages / Chats ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecentMessages({int limit = 50}) async {
    try {
      final res  = await _dio.get(AppConstants.apiMessages,
          queryParameters: {'limit': limit});
      final data = res.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map && data['messages'] is List) {
        return (data['messages'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getChats({int page = 1}) async {
    try {
      final res  = await _dio.get('/api/v1/groups',
          queryParameters: {'page': page, 'limit': AppConstants.pageSize});
      final list = res.data as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Logs ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLogs({int limit = 100}) async {
    try {
      final res  = await _dio.get(AppConstants.apiLogs,
          queryParameters: {'limit': limit});
      final data = res.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map && data['logs'] is List) {
        return (data['logs'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Analytics ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMetrics() async {
    try {
      final res = await _dio.get('/api/v1/metrics');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return _mockMetrics();
    }
  }

  Future<Map<String, dynamic>> getAnalytics({String period = '7d'}) async {
    try {
      final res = await _dio.get('/api/v1/analytics',
          queryParameters: {'period': period});
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return _mockAnalytics();
    }
  }

  // ── Sessions ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSessions() async {
    try {
      final status = await getInstanceStatus();
      final inst   = status['instance'] as Map<String, dynamic>? ?? {};
      if (inst['connected'] == true) {
        return [{
          'id': 'main',
          'name': inst['name'] ?? 'Main Session',
          'phoneNumber': inst['phone'] ?? '',
          'status': 'connected',
          'platform': inst['platform'] ?? 'WhatsApp',
          'connectedAt': DateTime.now().toIso8601String(),
        }];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Bot control ──────────────────────────────────────────────────────────

  Future<bool> restartBot() async {
    try {
      await _dio.post('/api/v1/instance/reconnect');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetBot() async {
    try { await _dio.post('/api/v1/instance/reset'); } catch (_) {}
  }

  Future<bool> stopBot() async => false;

  Future<bool> pauseBot() async {
    try {
      await _dio.post('/api/v1/instance/presence', data: {'type': 'unavailable'});
      return true;
    } catch (_) { return false; }
  }

  Future<bool> resumeBot() async {
    try {
      await _dio.post('/api/v1/instance/presence', data: {'type': 'available'});
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deleteSession(String sessionId) async {
    try {
      await _dio.delete('/api/v1/sessions/$sessionId');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> exportSession() async {
    try {
      final resp = await _dio.get('/api/v1/session/export');
      return (resp.data as Map<String, dynamic>?) ?? {};
    } on DioException catch (e) {
      return {'success': false, 'error': e.response?.data?['error'] ?? e.message};
    }
  }

  Future<Map<String, dynamic>> getQueueStats() async {
    try {
      final res = await _dio.get('/api/v1/instance/queue');
      return (res.data as Map<String, dynamic>?) ?? {};
    } catch (_) {
      return {};
    }
  }

  // ── Mock fallbacks (metrics / analytics only) ────────────────────────────

  Map<String, dynamic> _mockMetrics() => {
    'messagesPerMin': 0,
    'activeChats': 0,
    'commandsToday': 0,
    'errorsToday': 0,
    'cpuHistory':      List.generate(12, (i) => {'time': i, 'value': 0}),
    'ramHistory':      List.generate(12, (i) => {'time': i, 'value': 0}),
    'messagesHistory': List.generate(7,  (i) => {'day': i, 'count': 0}),
  };

  // ── Bot update ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> checkForUpdate() async {
    try {
      final res = await _dio.get(AppConstants.apiUpdateCheck);
      return res.data as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {'success': false, 'error': 'Impossible de joindre le bot'};
    }
  }

  Future<Map<String, dynamic>> getUpdateStatus() async {
    try {
      final res = await _dio.get(AppConstants.apiUpdateStatus);
      final d = res.data as Map<String, dynamic>? ?? {};
      return d['update'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<bool> triggerUpdate(String sha) async {
    try {
      await _dio.post(AppConstants.apiUpdateApply, data: {'sha': sha});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> checkBundleUpdate() async {
    try {
      final res = await _dio.get('/api/v1/update/check-bundle');
      return res.data as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {'success': false, 'error': 'Impossible de joindre le bot'};
    }
  }

  Future<bool> applyBundleUpdate(String? sha) async {
    try {
      await _dio.post(
        '/api/v1/update/apply-bundle',
        data: {'sha': sha ?? ''},
        options: Options(receiveTimeout: const Duration(minutes: 2)),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _mockAnalytics() => {
    'period': '7d',
    'totalMessages': 0, 'totalCommands': 0,
    'totalGroups': 0,   'totalUsers': 0,
    'messagesGrowth': 0.0, 'commandsGrowth': 0.0,
    'topCommands': <Map<String, dynamic>>[],
    'dailyActivity': List.generate(7, (i) => {
      'day': DateTime.now().subtract(Duration(days: 6 - i)).toIso8601String(),
      'messages': 0, 'commands': 0,
    }),
  };
}

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    baseUrl: PlatformService.botApiUrl,
    apiKey:  PlatformService.botApiKey,
  );
});
