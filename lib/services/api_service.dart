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
        // Always use platform-determined key (no user input needed)
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

  // Ã¢ÂÂÃ¢ÂÂ Instance / Connection Ã¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂ

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

  // Ã¢ÂÂÃ¢ÂÂ Dashboard Ã¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂ

  Future<Map<String, dynamic>> getBotStatus() async {
    try {
      final res = await _dio.get(AppConstants.apiStatus);
      final d = res.data as Map<String, dynamic>;
      final inst = d['instance'] as Map<String, dynamic>? ?? {};
      final proc = d['process'] as Map<String, dynamic>? ?? {};
      final mem  = proc['memory'] as Map<String, dynamic>? ?? {};
      return {
        'status': inst['connected'] == true ? 'online' : 'offline',
        'uptime': proc['uptime'] ?? 0,
        'phoneNumber': inst['phone'] ?? '',
        'name': inst['name'] ?? 'Wabot',
        'sessionsCount': 1,
        'groupsCount': 0,
        'messagesTotal': 0,
        'messagesPerMin': 0,
        'ramUsage': _parseRam(mem['heapUsed']),
        'ramTotal': _parseRam(mem['rss']),
        'cpuUsage': 0.0,
        'wsLatency': 0,
        'lastSeen': DateTime.now().toIso8601String(),
        'version': AppConstants.appVersion,
        'node': proc['node'] ?? '',
      };
    } catch (_) {
      return _mockBotStatus();
    }
  }

  int _parseRam(dynamic val) {
    if (val == null) return 0;
    return int.tryParse(val.toString().replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  }

  Future<Map<String, dynamic>> getMetrics() async {
    try {
      final res = await _dio.get('/api/v1/metrics');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return _mockMetrics();
    }
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    try {
      final status = await getInstanceStatus();
      final inst = status['instance'] as Map<String, dynamic>? ?? {};
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
      return _mockSessions();
    }
  }

  Future<List<Map<String, dynamic>>> getChats({int page = 1}) async {
    try {
      final res = await _dio.get('/api/v1/groups',
        queryParameters: {'page': page, 'limit': AppConstants.pageSize});
      final list = res.data as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return _mockChats();
    }
  }

  Future<List<Map<String, dynamic>>> getLogs({int limit = 100}) async {
    try {
      final res = await _dio.get(AppConstants.apiLogs, queryParameters: {'limit': limit});
      final data = res.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map && data['logs'] is List) {
        return (data['logs'] as List).cast<Map<String, dynamic>>();
      }
      return _mockLogs();
    } catch (_) {
      return _mockLogs();
    }
  }

  Future<Map<String, dynamic>> getAnalytics({String period = '7d'}) async {
    try {
      final res = await _dio.get('/api/v1/analytics', queryParameters: {'period': period});
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return _mockAnalytics();
    }
  }

  Future<bool> restartBot() async {
      try {
        await _dio.post('/api/v1/instance/reconnect');
        return true;
      } catch (_) {
        return false;
      }
    }

    Future<void> resetBot() async {
      try {
        await _dio.post('/api/v1/instance/reset');
      } catch (_) {}
    }

    Future<bool> stopBot() async => false;

  Future<bool> deleteSession(String sessionId) async {
    try {
      await _dio.delete('/api/v1/sessions/$sessionId');
      return true;
    } catch (_) {
      return false;
    }
  }

  // Ã¢ÂÂÃ¢ÂÂ Mock fallbacks (offline / demo mode) Ã¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂÃ¢ÂÂ

  Map<String, dynamic> _mockBotStatus() => {
    'status': 'offline',
    'uptime': 0,
    'phoneNumber': '',
    'name': 'Wabot',
    'sessionsCount': 0,
    'groupsCount': 0,
    'messagesTotal': 0,
    'messagesPerMin': 0,
    'ramUsage': 0,
    'ramTotal': 512,
    'cpuUsage': 0.0,
    'wsLatency': 0,
    'lastSeen': DateTime.now().toIso8601String(),
    'version': AppConstants.appVersion,
  };

  Map<String, dynamic> _mockMetrics() => {
    'messagesPerMin': 12,
    'activeChats': 34,
    'commandsToday': 842,
    'errorsToday': 3,
    'cpuHistory': List.generate(12, (i) => {'time': i, 'value': 10 + (i * 3 % 30)}),
    'ramHistory': List.generate(12, (i) => {'time': i, 'value': 180 + (i * 7 % 80)}),
    'messagesHistory': List.generate(7, (i) => {'day': i, 'count': 800 + (i * 200)}),
  };

  List<Map<String, dynamic>> _mockSessions() => [
    {
      'id': 'session_1',
      'name': 'Main Session',
      'phoneNumber': '+242064235945',
      'status': 'connected',
      'platform': 'WhatsApp Web',
      'connectedAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    },
  ];

  List<Map<String, dynamic>> _mockChats() => List.generate(15, (i) => {
    'id': 'chat_$i',
    'name': 'Chat ${i + 1}',
    'isGroup': i % 3 == 0,
    'lastMessage': 'Last message preview...',
    'lastMessageTime': DateTime.now().subtract(Duration(minutes: i * 5)).toIso8601String(),
    'unreadCount': i % 4,
    'participants': i % 3 == 0 ? (10 + i) : 2,
  });

  List<Map<String, dynamic>> _mockLogs() => [
    {'level': 'info', 'message': 'Ã¢ÂÂ Bot connected to WhatsApp', 'timestamp': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String()},
    {'level': 'info', 'message': 'Processing message from +242...', 'timestamp': DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String()},
    {'level': 'warn', 'message': 'Rate limit approaching for group XYZ', 'timestamp': DateTime.now().toIso8601String()},
    {'level': 'success', 'message': 'Command .help executed successfully', 'timestamp': DateTime.now().toIso8601String()},
  ];

  Map<String, dynamic> _mockAnalytics() => {
    'period': '7d',
    'totalMessages': 18430,
    'totalCommands': 5892,
    'totalGroups': 47,
    'totalUsers': 1240,
    'messagesGrowth': 12.5,
    'commandsGrowth': 8.2,
    'topCommands': [
      {'command': '.help', 'count': 1240},
      {'command': '.tag', 'count': 892},
      {'command': '.sticker', 'count': 634},
      {'command': '.play', 'count': 521},
      {'command': '.joke', 'count': 408},
    ],
    'dailyActivity': List.generate(7, (i) => {
      'day': DateTime.now().subtract(Duration(days: 6 - i)).toIso8601String(),
      'messages': 800 + (i * 200),
      'commands': 300 + (i * 80),
    }),
  };
}

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    baseUrl: PlatformService.botApiUrl,
    apiKey:  PlatformService.botApiKey,
  );
});
