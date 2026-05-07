import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';
import '../core/constants/app_constants.dart';

class ApiService {
  late final Dio _dio;

  ApiService({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.apiTimeout),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: true,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        // Transform errors to readable messages
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

  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  Future<Map<String, dynamic>> getBotStatus() async {
    try {
      final res = await _dio.get('/api/status');
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return _mockBotStatus();
    }
  }

  Future<Map<String, dynamic>> getMetrics() async {
    try {
      final res = await _dio.get('/api/metrics');
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return _mockMetrics();
    }
  }

  Future<String?> getPairingCode() async {
    try {
      final res = await _dio.post('/api/pairing/code');
      return res.data['code'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    try {
      final res = await _dio.get('/api/sessions');
      return List<Map<String, dynamic>>.from(res.data as List);
    } catch (e) {
      return _mockSessions();
    }
  }

  Future<List<Map<String, dynamic>>> getChats({int page = 1}) async {
    try {
      final res = await _dio.get('/api/chats', queryParameters: {'page': page, 'limit': AppConstants.pageSize});
      return List<Map<String, dynamic>>.from(res.data['chats'] as List);
    } catch (e) {
      return _mockChats();
    }
  }

  Future<List<Map<String, dynamic>>> getLogs({int limit = 100}) async {
    try {
      final res = await _dio.get('/api/logs', queryParameters: {'limit': limit});
      return List<Map<String, dynamic>>.from(res.data as List);
    } catch (e) {
      return _mockLogs();
    }
  }

  Future<Map<String, dynamic>> getAnalytics({String period = '7d'}) async {
    try {
      final res = await _dio.get('/api/analytics', queryParameters: {'period': period});
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return _mockAnalytics();
    }
  }

  Future<bool> restartBot() async {
    try {
      await _dio.post('/api/bot/restart');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> stopBot() async {
    try {
      await _dio.post('/api/bot/stop');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    try {
      await _dio.delete('/api/sessions/$sessionId');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Mock data for offline/demo mode
  Map<String, dynamic> _mockBotStatus() => {
    'status': 'online',
    'uptime': 86400,
    'phoneNumber': '+242064235945',
    'name': 'WaBot',
    'sessionsCount': 1,
    'groupsCount': 47,
    'messagesTotal': 18430,
    'messagesPerMin': 12,
    'ramUsage': 245,
    'ramTotal': 512,
    'cpuUsage': 18.5,
    'wsLatency': 42,
    'lastSeen': DateTime.now().toIso8601String(),
    'version': '4.3',
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
    {'level': 'info', 'message': '✅ Bot connected to WhatsApp', 'timestamp': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String()},
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
  final url = StorageService.getString(AppConstants.keyApiUrl) ?? AppConstants.defaultApiUrl;
  return ApiService(baseUrl: url);
});
