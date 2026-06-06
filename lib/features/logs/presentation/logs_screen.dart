import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../../../services/api_service.dart';

  const _g      = Color(0xFF25D366);
  const _ink    = Color(0xFFF2F3F5);
  const _muted  = Color(0xFF8A9199);
  const _bg     = Color(0xFF0D0E11);

  class LogsScreen extends ConsumerStatefulWidget {
    const LogsScreen({super.key});
    @override
    ConsumerState<LogsScreen> createState() => _LogsScreenState();
  }

  class _LogsScreenState extends ConsumerState<LogsScreen> {
    List<Map<String, dynamic>> _logs = [];
    bool _loading = true;

    @override
    void initState() {
      super.initState();
      _load();
    }

    Future<void> _load() async {
      setState(() => _loading = true);
      try {
        final api = ref.read(apiServiceProvider);
        final data = await api.getLogs(limit: 200);
        if (mounted) setState(() { _logs = data; _loading = false; });
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: _bg,
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
            child: Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Logs d'activitÃ©",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
                SizedBox(height: 2),
                Text('Messages et commandes reÃ§us par le bot',
                  style: TextStyle(color: _muted, fontSize: 12)),
              ])),
              IconButton(icon: const Icon(Icons.refresh_rounded, color: _muted), onPressed: _load),
            ]),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: _g))
              : _logs.isEmpty
                ? _EmptyState()
                : RefreshIndicator(
                    color: _g,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _logs.length,
                      itemBuilder: (_, i) => _LogRow(log: _logs[i]),
                    ),
                  ),
          ),
        ]),
      );
    }
  }

  class _LogRow extends StatelessWidget {
    final Map<String, dynamic> log;
    const _LogRow({required this.log});

    Color get _c {
      switch ((log['level'] as String? ?? '').toUpperCase()) {
        case 'ERROR':   return const Color(0xFFFF6B6B);
        case 'WARN':    return const Color(0xFFF59E0B);
        case 'SUCCESS': return Color(0xFF25D366);
        default:        return const Color(0xFF57B6FF);
      }
    }

    String get _time {
      try {
        final dt = DateTime.parse(log['timestamp'] as String? ?? '').toLocal();
        return '${dt.hour.toString().padLeft(2,"0")}:${dt.minute.toString().padLeft(2,"0")}:${dt.second.toString().padLeft(2,"0")}';
      } catch (_) { return '--:--:--'; }
    }

    @override
    Widget build(BuildContext context) {
      final lvl = (log['level'] as String? ?? 'INFO').toUpperCase();
      final msg = log['message'] as String? ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF080A0C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1A1C20)),
          ),
          child: Row(children: [
            Text(_time, style: const TextStyle(fontSize: 10, color: Color(0xFF4A5568), fontFamily: 'monospace')),
            const SizedBox(width: 8),
            Container(
              width: 52, alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(color: _c.withOpacity(.12), borderRadius: BorderRadius.circular(4)),
              child: Text(lvl.length > 7 ? lvl.substring(0, 7) : lvl,
                style: TextStyle(fontSize: 9, color: _c, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            Expanded(child: Text(msg,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFD1D5DB), fontFamily: 'monospace'),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );
    }
  }

  class _EmptyState extends StatelessWidget {
    @override
    Widget build(BuildContext context) => Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 52, color: const Color(0xFF8A9199).withOpacity(.4)),
        const SizedBox(height: 14),
        const Text("Aucun log pour l'instant", style: TextStyle(color: Color(0xFF8A9199), fontSize: 14)),
        const SizedBox(height: 6),
        const Text('Envoyez .ping ou .help dans WhatsApp pour tester',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF5E636E), fontSize: 12)),
      ]),
    );
  }
  