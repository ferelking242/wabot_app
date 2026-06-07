import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  final LogLevel level;
  final String tag;
  final String message;
  final DateTime time;
  final String? stackTrace;

  const LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    required this.time,
    this.stackTrace,
  });

  String get levelStr => level.name.toUpperCase().padRight(5);

  String toLine() {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    final base = '[$h:$m:$s.$ms] [$levelStr] [$tag] $message';
    if (stackTrace != null) return '$base\n  $stackTrace';
    return base;
  }
}

class LogService {
  LogService._();

  static final LogService instance = LogService._();

  final _buffer = <LogEntry>[];
  static const _maxBuffer = 500;
  File? _logFile;
  bool _initialized = false;

  static LogService get I => instance;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      await logDir.create(recursive: true);
      _logFile = File('${logDir.path}/wabot.log');
      // Rotation : si le fichier fait plus de 2 Mo, on archive
      if (_logFile!.existsSync() && _logFile!.lengthSync() > 2 * 1024 * 1024) {
        await _logFile!.rename('${logDir.path}/wabot_old.log');
        _logFile = File('${logDir.path}/wabot.log');
      }
      _initialized = true;
      i('LogService', 'LogService initialisé — ${_logFile!.path}');
    } catch (e) {
      debugPrint('[LogService] Init error: $e');
    }
  }

  void _write(LogLevel lvl, String tag, String msg, {String? stack}) {
    final entry = LogEntry(
      level: lvl, tag: tag, message: msg,
      time: DateTime.now(), stackTrace: stack,
    );
    _buffer.add(entry);
    if (_buffer.length > _maxBuffer) _buffer.removeAt(0);
    final line = entry.toLine();
    debugPrint(line);
    if (_logFile != null) {
      try {
        _logFile!.writeAsStringSync('$line\n', mode: FileMode.append, flush: false);
      } catch (_) {}
    }
  }

  void d(String tag, String msg) => _write(LogLevel.debug, tag, msg);
  void i(String tag, String msg) => _write(LogLevel.info,  tag, msg);
  void w(String tag, String msg) => _write(LogLevel.warn,  tag, msg);
  void e(String tag, String msg, {Object? error, StackTrace? stack}) {
    final stackStr = stack != null ? stack.toString().split('\n').take(5).join(' | ') : null;
    final errStr   = error != null ? ' | $error' : '';
    _write(LogLevel.error, tag, '$msg$errStr', stack: stackStr);
  }

  List<LogEntry> get recent => List.unmodifiable(_buffer);

  List<LogEntry> get errors => _buffer.where((e) => e.level == LogLevel.error).toList();

  Future<String?> get logFilePath async {
    if (_logFile?.existsSync() == true) return _logFile!.path;
    return null;
  }

  Future<void> exportLogs() async {
    try {
      if (_logFile == null) {
        // Créer un fichier temporaire avec le buffer mémoire
        final dir = await getTemporaryDirectory();
        final tmp = File('${dir.path}/wabot_export.log');
        await tmp.writeAsString(_buffer.map((e) => e.toLine()).join('\n'));
        await Share.shareXFiles([XFile(tmp.path)], subject: 'Wabot Logs');
      } else {
        await Share.shareXFiles([XFile(_logFile!.path)], subject: 'Wabot Logs');
      }
    } catch (err) {
      debugPrint('[LogService] Export error: $err');
    }
  }

  Future<void> clearLogs() async {
    _buffer.clear();
    try { await _logFile?.writeAsString(''); } catch (_) {}
    i('LogService', 'Logs effacés');
  }

  // Accès global statique pour tout le code
  static void debug(String tag, String msg)                        => instance.d(tag, msg);
  static void info (String tag, String msg)                        => instance.i(tag, msg);
  static void warn (String tag, String msg)                        => instance.w(tag, msg);
  static void error(String tag, String msg, {Object? err, StackTrace? stack}) =>
      instance.e(tag, msg, error: err, stack: stack);
}
