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

    String get levelStr {
      switch (level) {
        case LogLevel.error: return 'ERROR';
        case LogLevel.warn:  return 'WARN ';
        case LogLevel.info:  return 'INFO ';
        case LogLevel.debug: return 'DEBUG';
      }
    }

    String get levelIcon {
      switch (level) {
        case LogLevel.error: return '✖';
        case LogLevel.warn:  return '⚠';
        case LogLevel.info:  return 'ℹ';
        case LogLevel.debug: return '·';
      }
    }

    String toLine() {
      final y   = time.year.toString();
      final mo  = time.month.toString().padLeft(2, '0');
      final d   = time.day.toString().padLeft(2, '0');
      final h   = time.hour.toString().padLeft(2, '0');
      final m   = time.minute.toString().padLeft(2, '0');
      final s   = time.second.toString().padLeft(2, '0');
      final ms  = time.millisecond.toString().padLeft(3, '0');
      final base = '$y-$mo-$d $h:$m:$s.$ms [$levelStr] [$tag] $message';
      if (stackTrace != null) return '$base\n  $stackTrace';
      return base;
    }

    /// Format court pour l'affichage en UI : HH:MM:SS
    String get timeShort {
      final h  = time.hour.toString().padLeft(2, '0');
      final m  = time.minute.toString().padLeft(2, '0');
      final s  = time.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
  }

  class LogService {
    LogService._();
    static final LogService instance = LogService._();
    static LogService get I => instance;

    final _buffer = <LogEntry>[];
    static const _maxBuffer = 1000;

    File? _internalLogFile;  // /data/data/.../files/wabot/logs/wabot.log
    File? _externalLogFile;  // /storage/emulated/0/wabot/logs/wabot.log
    bool  _initialized = false;

    // Listeners pour rafraîchissement temps réel
    final _listeners = <void Function()>[];
    void addListener(void Function() cb)    => _listeners.add(cb);
    void removeListener(void Function() cb) => _listeners.remove(cb);
    void _notify() { for (final cb in _listeners) { try { cb(); } catch (_) {} } }

    static const String externalRoot = '/storage/emulated/0/wabot';

    Future<void> init() async {
      if (_initialized) return;
      try {
        final appDir = await getApplicationDocumentsDirectory();
        _internalLogFile = await _openLogFile('${appDir.path}/logs');
        await _tryInitExternalLog();
        _initialized = true;
        i('LogService', 'Initialisé — interne: ${_internalLogFile?.path}');
        if (_externalLogFile != null) {
          i('LogService', 'Log externe: ${_externalLogFile!.path}');
        }
      } catch (e) {
        debugPrint('[LogService] Init error: $e');
      }
    }

    Future<void> initExternalStorage() async {
      try {
        final root = Directory(externalRoot);
        if (!root.existsSync()) {
          root.createSync(recursive: true);
          i('LogService', 'Dossier /wabot créé à la racine du stockage');
        }
        await _tryInitExternalLog();
      } catch (e) {
        w('LogService', 'initExternalStorage: $e');
      }
    }

    Future<void> _tryInitExternalLog() async {
      try {
        final extLogDir = Directory('$externalRoot/logs');
        if (!extLogDir.existsSync()) extLogDir.createSync(recursive: true);
        _externalLogFile = await _openLogFile(extLogDir.path);
      } catch (_) {}
    }

    Future<File?> _openLogFile(String dirPath) async {
      try {
        final dir = Directory(dirPath);
        await dir.create(recursive: true);
        final f = File('${dir.path}/wabot.log');
        // Rotation si > 5 Mo
        if (f.existsSync() && f.lengthSync() > 5 * 1024 * 1024) {
          await f.rename('${dir.path}/wabot_old.log');
          return File('${dir.path}/wabot.log');
        }
        return f;
      } catch (_) { return null; }
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
      _appendLine(_internalLogFile, '$line\n');
      _appendLine(_externalLogFile, '$line\n');
      _notify();
    }

    void _appendLine(File? f, String line) {
      if (f == null) return;
      try { f.writeAsStringSync(line, mode: FileMode.append, flush: false); }
      catch (_) {}
    }

    void d(String tag, String msg)                           => _write(LogLevel.debug, tag, msg);
    void i(String tag, String msg)                           => _write(LogLevel.info,  tag, msg);
    void w(String tag, String msg)                           => _write(LogLevel.warn,  tag, msg);
    void e(String tag, String msg, {Object? error, StackTrace? stack}) {
      final stackStr = stack?.toString().split('\n').take(6).join(' | ');
      final errStr   = error != null ? ' | $error' : '';
      _write(LogLevel.error, tag, '$msg$errStr', stack: stackStr);
    }

    List<LogEntry> get recent => List.unmodifiable(_buffer);
    List<LogEntry> get errors => _buffer.where((e) => e.level == LogLevel.error).toList();
    int get errorCount        => _buffer.where((e) => e.level == LogLevel.error).length;
    int get warnCount         => _buffer.where((e) => e.level == LogLevel.warn).length;

    String? get internalLogPath  => _internalLogFile?.existsSync() == true ? _internalLogFile!.path : null;
    String? get externalLogPath  => _externalLogFile?.existsSync() == true ? _externalLogFile!.path : null;

    Future<void> exportLogs() async {
      try {
        final files = <XFile>[];
        if (_internalLogFile?.existsSync() == true) files.add(XFile(_internalLogFile!.path));
        if (_externalLogFile?.existsSync() == true) files.add(XFile(_externalLogFile!.path));
        if (files.isEmpty) {
          final dir = await getTemporaryDirectory();
          final tmp = File('${dir.path}/wabot_export.log');
          await tmp.writeAsString(_buffer.map((e) => e.toLine()).join('\n'));
          files.add(XFile(tmp.path));
        }
        await Share.shareXFiles(files, subject: 'Wabot Logs');
      } catch (err) {
        debugPrint('[LogService] Export error: $err');
      }
    }

    Future<void> clearLogs() async {
      _buffer.clear();
      try { await _internalLogFile?.writeAsString(''); } catch (_) {}
      try { await _externalLogFile?.writeAsString(''); } catch (_) {}
      i('LogService', 'Logs effacés');
    }

    static void debug(String tag, String msg)                                       => instance.d(tag, msg);
    static void info (String tag, String msg)                                       => instance.i(tag, msg);
    static void warn (String tag, String msg)                                       => instance.w(tag, msg);
    static void error(String tag, String msg, {Object? err, StackTrace? stack})    =>
        instance.e(tag, msg, error: err, stack: stack);
  }
