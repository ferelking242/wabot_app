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
const _green  = Color(0xFF25D366);
const _grey   = Color(0xFF4A5568);

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});
  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final ScrollController _scrollBot;
  late final ScrollController _scrollApp;
  List<Map<String, dynamic>> _apiLogs  = [];
  List<LogEntry>              _appLogs  = [];
  bool _loading   = true;
  bool _autoScroll = true;
  Timer? _timer;
  String _filterLevel = 'ALL';
  static const _TAG = 'LogsScreen';

  @override
  void initState() {
    super.initState();
    _tab       = TabController(length: 2, vsync: this);
    _scrollBot = ScrollController();
    _scrollApp = ScrollController();
    _scrollBot.addListener(_onScrollBot);
    _scrollApp.addListener(_onScrollApp);
    LogService.I.addListener(_onNewAppLog);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadBotLogs());
  }

  @override
  void dispose() {
    _tab.dispose();
    _scrollBot.dispose();
    _scrollApp.dispose();
    LogService.I.removeListener(_onNewAppLog);
    _timer?.cancel();
    super.dispose();
  }

  void _onScrollBot() {
    if (_scrollBot.hasClients) {
      final atBottom = _scrollBot.offset >= _scrollBot.position.maxScrollExtent - 60;
      if (atBottom != _autoScroll) setState(() => _autoScroll = atBottom);
    }
  }

  void _onScrollApp() {
    if (_scrollApp.hasClients) {
      final atBottom = _scrollApp.offset >= _scrollApp.position.maxScrollExtent - 60;
      if (atBottom != _autoScroll) setState(() => _autoScroll = atBottom);
    }
  }

  void _onNewAppLog() {
    if (!mounted) return;
    setState(() {
      _appLogs = LogService.I.recent.reversed.toList();
    });
    if (_autoScroll && _tab.index == 1) _scrollToBottom(_scrollApp);
  }

  void _scrollToBottom(ScrollController ctrl) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ctrl.hasClients) {
        ctrl.animateTo(
          ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _load() async {
    await _loadBotLogs();
    if (mounted) setState(() {
      _appLogs = LogService.I.recent.reversed.toList();
      _loading  = false;
    });
    if (_autoScroll) {
      _scrollToBottom(_scrollBot);
      _scrollToBottom(_scrollApp);
    }
  }

  Future<void> _loadBotLogs() async {
    try {
      final api  = ref.read(apiServiceProvider);
      final data = await api.getLogs(limit: 300);
      if (mounted) {
        setState(() => _apiLogs = data);
        if (_autoScroll && _tab.index == 0) _scrollToBottom(_scrollBot);
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

  Color _levelColor(String lvl) {
    switch (lvl.toUpperCase().trim()) {
      case 'ERROR': return _red;
      case 'WARN':  return _orange;
      case 'CMD':   return _green;
      case 'OK':    return _green;
      default:      return _blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final errCount  = LogService.I.errorCount;
    final warnCount = LogService.I.warnCount;

    // Compter CMD dans bot logs
    final cmdCount = _apiLogs.where((l) =>
        (l['level'] as String? ?? '').toUpperCase().trim() == 'CMD').length;

    final levels = ['ALL', 'CMD', 'ERROR', 'WARN', 'INFO'];
    final filteredApi = _filterLevel == 'ALL'
        ? _apiLogs
        : _apiLogs.where((l) =>
            (l['level'] as String? ?? '').toUpperCase().trim() == _filterLevel).toList();
    final filteredApp = _filterLevel == 'ALL' || _filterLevel == 'CMD'
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
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Logs', style: TextStyle(fontSize: 24,
                  fontWeight: FontWeight.w900, color: _ink, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Row(children: [
                const Text('Activité en temps réel',
                    style: TextStyle(color: _muted, fontSize: 12)),
                if (errCount > 0) ...[
                  const SizedBox(width: 8),
                  _Badge(count: errCount, color: _red),
                ],
                if (warnCount > 0) ...[
                  const SizedBox(width: 4),
                  _Badge(count: warnCount, color: _orange),
                ],
                if (cmdCount > 0) ...[
                  const SizedBox(width: 4),
                  _Badge(count: cmdCount, color: _green, label: 'CMD'),
                ],
              ]),
            ])),
            // Bouton scroll bas
            if (!_autoScroll)
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded, color: _g, size: 20),
                onPressed: () {
                  setState(() => _autoScroll = true);
                  _scrollToBottom(_tab.index == 0 ? _scrollBot : _scrollApp);
                },
                tooltip: 'Aller en bas',
              ),
            IconButton(icon: const Icon(Icons.file_upload_outlined, color: _muted),
                onPressed: _export, tooltip: 'Exporter'),
            IconButton(icon: const Icon(Icons.delete_outline, color: _muted),
                onPressed: _clear, tooltip: 'Vider'),
            IconButton(icon: const Icon(Icons.refresh_rounded, color: _muted),
                onPressed: _load),
          ]),
        ),

        // ── Filtres niveau ────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: levels.map((lvl) {
              final sel   = lvl == _filterLevel;
              final color = _levelColor(lvl == 'ALL' ? 'INFO' : lvl);
              final chip  = lvl == 'ALL' ? _muted : color;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filterLevel = lvl),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? chip.withOpacity(0.15) : _card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? chip.withOpacity(0.5) : _border),
                    ),
                    child: Text(lvl,
                        style: TextStyle(color: sel ? chip : _muted, fontSize: 12,
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
              Tab(text: 'Bot (${filteredApi.length})'),
              Tab(text: 'App (${filteredApp.length})'),
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
                    // Bot logs (Node.js via API)
                    filteredApi.isEmpty
                        ? _EmptyState(level: _filterLevel)
                        : ListView.builder(
                            controller: _scrollBot,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filteredApi.length,
                            itemBuilder: (_, i) => _ApiLogRow(log: filteredApi[i]),
                          ),
                    // App logs (Flutter)
                    filteredApp.isEmpty
                        ? _EmptyState(level: _filterLevel)
                        : ListView.builder(
                            controller: _scrollApp,
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

// ── Badge compteur ────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  final String? label;
  const _Badge({required this.count, required this.color, this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.18),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label != null ? '$label $count' : '$count',
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

// ── Ligne log Bot (Node.js) ───────────────────────────────────────────────────
class _ApiLogRow extends StatelessWidget {
  final Map<String, dynamic> log;
  const _ApiLogRow({required this.log});

  String get _rawLevel => (log['level'] as String? ?? 'INFO').toUpperCase().trim();

  Color get _c {
    switch (_rawLevel) {
      case 'ERROR': return _red;
      case 'WARN':  return _orange;
      case 'CMD':   return _green;
      case 'OK':    return _green;
      default:      return _blue;
    }
  }

  String get _icon {
    switch (_rawLevel) {
      case 'ERROR': return '✖';
      case 'WARN':  return '⚠';
      case 'CMD':   return '▶';
      case 'OK':    return '✓';
      default:      return 'ℹ';
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
    final lvl = _rawLevel.length > 5 ? _rawLevel.substring(0, 5) : _rawLevel;
    final msg = log['msg'] as String? ?? '';
    final isCmd = _rawLevel == 'CMD';
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isCmd ? _green.withOpacity(0.04) : const Color(0xFF080A0C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCmd ? _green.withOpacity(0.25) : const Color(0xFF1A1C20),
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Heure
          Text(_time, style: const TextStyle(
              fontSize: 10, color: _grey, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          // Icône + badge niveau
          Container(
            width: 52, alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_icon, style: TextStyle(fontSize: 9, color: _c)),
              const SizedBox(width: 3),
              Text(lvl, style: TextStyle(
                  fontSize: 9, color: _c, fontWeight: FontWeight.w800,
                  letterSpacing: 0.3)),
            ]),
          ),
          const SizedBox(width: 8),
          // Message
          Expanded(child: Text(msg,
              style: TextStyle(
                fontSize: 12,
                color: isCmd ? _ink : _muted,
                fontFamily: 'monospace',
                fontWeight: isCmd ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 4, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

// ── Ligne log App (Flutter) ───────────────────────────────────────────────────
class _AppLogRow extends StatelessWidget {
  final LogEntry entry;
  const _AppLogRow({required this.entry});

  Color get _c {
    switch (entry.level) {
      case LogLevel.error: return _red;
      case LogLevel.warn:  return _orange;
      case LogLevel.debug: return _grey;
      default:             return _blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF080A0C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1A1C20)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Heure
          Text(entry.timeShort, style: const TextStyle(
              fontSize: 10, color: _grey, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          // Icône + badge niveau
          Container(
            width: 52, alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(entry.levelIcon, style: TextStyle(fontSize: 9, color: _c)),
              const SizedBox(width: 3),
              Text(entry.levelStr.trim().substring(
                      0, entry.levelStr.trim().length > 4 ? 4 : entry.levelStr.trim().length),
                  style: TextStyle(
                      fontSize: 9, color: _c,
                      fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            ]),
          ),
          const SizedBox(width: 4),
          // Tag
          Text('[${entry.tag}]',
              style: const TextStyle(
                  fontSize: 9, color: _grey, fontFamily: 'monospace')),
          const SizedBox(width: 4),
          // Message
          Expanded(child: Text(entry.message,
              style: const TextStyle(fontSize: 12, color: _muted, fontFamily: 'monospace'),
              maxLines: 3, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String level;
  const _EmptyState({required this.level});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.receipt_long_outlined, color: _muted, size: 40),
      const SizedBox(height: 12),
      Text(level == 'ALL' ? 'Aucun log' : 'Aucun log [$level]',
          style: const TextStyle(color: _muted, fontSize: 14)),
    ],
  ));
}
