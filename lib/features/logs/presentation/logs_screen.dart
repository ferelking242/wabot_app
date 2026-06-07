import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import '../../../core/services/log_service.dart';

const _g      = Color(0xFF25D366);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _border = Color(0xFF1E2128);
const _card   = Color(0xFF111316);
const _bg     = Color(0xFF0D0E11);
const _red    = Color(0xFFFF6B6B);
const _orange = Color(0xFFF59E0B);
const _blue   = Color(0xFF57B6FF);

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});
  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Map<String, dynamic>> _apiLogs  = [];
  List<LogEntry>              _appLogs  = [];
  bool _loading = true;
  Timer? _timer;
  String _filterLevel = 'ALL';
  static const _TAG = 'LogsScreen';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _tab.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getLogs(limit: 200);
      if (mounted) {
        setState(() {
          _apiLogs  = data;
          _appLogs  = LogService.I.recent.reversed.toList();
          _loading  = false;
        });
      }
    } catch (e) {
      LogService.error(_TAG, 'Erreur chargement logs: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    LogService.info(_TAG, 'Export logs demandé');
    await LogService.I.exportLogs();
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Vider les logs', style: TextStyle(color: _ink)),
        content: const Text('Effacer tous les logs locaux ?',
            style: TextStyle(color: _muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(color: _muted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Vider', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (confirmed == true) {
      await LogService.I.clearLogs();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = ['ALL', 'ERROR', 'WARN', 'INFO'];
    final filteredApi = _filterLevel == 'ALL'
        ? _apiLogs
        : _apiLogs.where((l) =>
            (l['level'] as String? ?? '').toUpperCase() == _filterLevel).toList();
    final filteredApp = _filterLevel == 'ALL'
        ? _appLogs
        : _appLogs.where((l) =>
            l.level.name.toUpperCase() == _filterLevel).toList();

    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [

        // ── En-tête ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Logs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                  color: _ink, letterSpacing: -0.5)),
              SizedBox(height: 2),
              Text('Activité en temps réel',
                  style: TextStyle(color: _muted, fontSize: 12)),
            ])),
            IconButton(icon: const Icon(Icons.file_upload_outlined, color: _muted), onPressed: _export,
                tooltip: 'Exporter'),
            IconButton(icon: const Icon(Icons.delete_outline, color: _muted), onPressed: _clear,
                tooltip: 'Vider'),
            IconButton(icon: const Icon(Icons.refresh_rounded, color: _muted), onPressed: _load),
          ]),
        ),

        // ── Filtres niveau ────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: levels.map((lvl) {
              final sel = lvl == _filterLevel;
              final color = lvl == 'ERROR' ? _red : lvl == 'WARN' ? _orange : lvl == 'INFO' ? _blue : _muted;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filterLevel = lvl),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? color.withOpacity(0.15) : _card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? color.withOpacity(0.5) : _border),
                    ),
                    child: Text(lvl,
                        style: TextStyle(color: sel ? color : _muted, fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Tabs ──────────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: _g.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: _g,
            unselectedLabelColor: _muted,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Bot (${_apiLogs.length})'),
              Tab(text: 'App (${_appLogs.length})'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Contenu ───────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _g))
              : TabBarView(
                  controller: _tab,
                  children: [
                    // Bot logs (API)
                    filteredApi.isEmpty
                        ? _EmptyState(level: _filterLevel)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filteredApi.length,
                            itemBuilder: (_, i) => _ApiLogRow(log: filteredApi[i]),
                          ),
                    // App logs (Flutter)
                    filteredApp.isEmpty
                        ? _EmptyState(level: _filterLevel)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filteredApp.length,
                            itemBuilder: (_, i) => _AppLogRow(entry: filteredApp[i]),
                          ),
                  ],
                ),
        ),
      ]),
    );
  }
}

class _ApiLogRow extends StatelessWidget {
  final Map<String, dynamic> log;
  const _ApiLogRow({required this.log});

  Color get _c {
    switch ((log['level'] as String? ?? '').toUpperCase()) {
      case 'ERROR': return _red;
      case 'WARN':  return _orange;
      default:      return _blue;
    }
  }

  String get _time {
    try {
      final dt = DateTime.parse(log['time'] as String? ?? '').toLocal();
      return '${dt.hour.toString().padLeft(2,"0")}:${dt.minute.toString().padLeft(2,"0")}:${dt.second.toString().padLeft(2,"0")}';
    } catch (_) { return '--:--:--'; }
  }

  @override
  Widget build(BuildContext context) {
    final lvl = (log['level'] as String? ?? 'INFO').toUpperCase();
    final msg = log['msg'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF080A0C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1A1C20)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_time, style: const TextStyle(fontSize: 10, color: Color(0xFF4A5568), fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Container(
            width: 48, alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _c.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(lvl.substring(0, lvl.length > 4 ? 4 : lvl.length),
                style: TextStyle(fontSize: 9, color: _c, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg,
              style: const TextStyle(fontSize: 12, color: _muted, fontFamily: 'monospace'),
              maxLines: 3, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

class _AppLogRow extends StatelessWidget {
  final LogEntry entry;
  const _AppLogRow({required this.entry});

  Color get _c {
    switch (entry.level) {
      case LogLevel.error: return _red;
      case LogLevel.warn:  return _orange;
      case LogLevel.debug: return _muted;
      default:             return _blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final h  = entry.time.hour.toString().padLeft(2,'0');
    final m  = entry.time.minute.toString().padLeft(2,'0');
    final s  = entry.time.second.toString().padLeft(2,'0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF080A0C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1A1C20)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$h:$m:$s', style: const TextStyle(fontSize: 10, color: Color(0xFF4A5568), fontFamily: 'monospace')),
          const SizedBox(width: 8),
          Container(
            width: 48, alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _c.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(entry.levelStr.trim().substring(0, entry.levelStr.trim().length > 4 ? 4 : entry.levelStr.trim().length),
                style: TextStyle(fontSize: 9, color: _c, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Text('[${entry.tag}]',
                style: const TextStyle(fontSize: 9, color: Color(0xFF4A5568), fontFamily: 'monospace')),
          ),
          Expanded(child: Text(entry.message,
              style: const TextStyle(fontSize: 12, color: _muted, fontFamily: 'monospace'),
              maxLines: 3, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String level;
  const _EmptyState({required this.level});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.receipt_long_outlined, color: _muted, size: 40),
      const SizedBox(height: 12),
      Text(level == 'ALL' ? 'Aucun log' : 'Aucun log de niveau $level',
          style: const TextStyle(color: _muted, fontSize: 14)),
    ],
  ));
}
