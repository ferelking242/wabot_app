class BotStatus {
  final String status;
  final int uptime;
  final String phoneNumber;
  final String name;
  final int sessionsCount;
  final int groupsCount;
  final int messagesTotal;
  final int messagesPerMin;
  final double ramUsage;
  final double ramTotal;
  final double cpuUsage;
  final int wsLatency;
  final DateTime lastSeen;
  final String version;

  const BotStatus({
    required this.status,
    required this.uptime,
    required this.phoneNumber,
    required this.name,
    required this.sessionsCount,
    required this.groupsCount,
    required this.messagesTotal,
    required this.messagesPerMin,
    required this.ramUsage,
    required this.ramTotal,
    required this.cpuUsage,
    required this.wsLatency,
    required this.lastSeen,
    required this.version,
  });

  bool get isOnline => status == 'online';
  bool get isConnecting => status == 'connecting';
  double get ramPercent => ramTotal > 0 ? (ramUsage / ramTotal) * 100 : 0;

  String get uptimeFormatted {
    final d = Duration(seconds: uptime);
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final mins = d.inMinutes.remainder(60);
    if (days > 0) return '${days}d ${hours}h ${mins}m';
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  factory BotStatus.fromJson(Map<String, dynamic> json) => BotStatus(
        status: json['status'] as String? ?? 'offline',
        uptime: (json['uptime'] as num?)?.toInt() ?? 0,
        phoneNumber: json['phoneNumber'] as String? ?? '',
        name: json['name'] as String? ?? 'Wabot',
        sessionsCount: (json['sessionsCount'] as num?)?.toInt() ?? 0,
        groupsCount: (json['groupsCount'] as num?)?.toInt() ?? 0,
        messagesTotal: (json['messagesTotal'] as num?)?.toInt() ?? 0,
        messagesPerMin: (json['messagesPerMin'] as num?)?.toInt() ?? 0,
        ramUsage: (json['ramUsage'] as num?)?.toDouble() ?? 0,
        ramTotal: (json['ramTotal'] as num?)?.toDouble() ?? 512,
        cpuUsage: (json['cpuUsage'] as num?)?.toDouble() ?? 0,
        wsLatency: (json['wsLatency'] as num?)?.toInt() ?? 0,
        lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ?? DateTime.now(),
        version: json['version'] as String? ?? '0.0',
      );

  static BotStatus get empty => BotStatus(
        status: 'offline',
        uptime: 0,
        phoneNumber: '',
        name: 'Wabot',
        sessionsCount: 0,
        groupsCount: 0,
        messagesTotal: 0,
        messagesPerMin: 0,
        ramUsage: 0,
        ramTotal: 512,
        cpuUsage: 0,
        wsLatency: 0,
        lastSeen: DateTime.now(),
        version: '0.0',
      );
}

class LogEntry {
  final String level;
  final String message;
  final DateTime timestamp;

  const LogEntry({required this.level, required this.message, required this.timestamp});

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        level: json['level'] as String? ?? 'info',
        message: json['message'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

class ChatPreview {
  final String id;
  final String name;
  final bool isGroup;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final int participants;

  const ChatPreview({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.participants,
  });

  factory ChatPreview.fromJson(Map<String, dynamic> json) => ChatPreview(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        isGroup: json['isGroup'] as bool? ?? false,
        lastMessage: json['lastMessage'] as String? ?? '',
        lastMessageTime: DateTime.tryParse(json['lastMessageTime'] as String? ?? '') ?? DateTime.now(),
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
        participants: (json['participants'] as num?)?.toInt() ?? 2,
      );
}
