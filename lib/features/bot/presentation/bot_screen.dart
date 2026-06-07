import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import '../../../core/services/bot_service.dart';
import '../../../core/services/log_service.dart';

const _g      = Color(0xFF25D366);
const _gd     = Color(0xFF128C7E);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _border = Color(0xFF1E2128);
const _card   = Color(0xFF111316);
const _bg     = Color(0xFF0D0E11);
const _red    = Color(0xFFFF6B6B);
const _orange = Color(0xFFE67E22);
const _blue   = Color(0xFF57B6FF);

class BotScreen extends ConsumerStatefulWidget {
  const BotScreen({super.key});
  @override
  ConsumerState<BotScreen> createState() => _BotScreenState();
}

class _BotScreenState extends ConsumerState<BotScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _timer;
  Map<String, dynamic> _status = {};
  List<Map<String, dynamic>> _logs = [];
  bool _loadingStatus = true;
  bool _actionLoading = false;

  static const _TAG = 'BotScreen';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _loadAll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadAll());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final api = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.getBotStatus(),
        api.getLogs(limit: 50),
      ]);
      if (mounted) {
        setState(() {
          _status = results[0] as Map<String, dynamic>;
          _logs   = (results[1] as List).cast<Map<String, dynamic>>();
          _loadingStatus = false;
        });
      }
    } catch (e) {
      LogService.error(_TAG, 'Erreur chargement: $e');
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _action(String label, Future<void> Function() fn) async {
    setState(() => _actionLoading = true);
    LogService.info(_TAG, 'Action: $label');
    try {
      await fn();
      await Future.delayed(const Duration(seconds: 2));
      await _loadAll();
    } catch (e) {
      LogService.error(_TAG, 'Action $label échouée: $e');
      if (mounted) _showSnack('Erreur : $e', _red);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
    ));
  }

  String _fmt(int s) {
    if (s <= 0) return '--';
    final h = s ~/ 3600, m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m ${s % 60}s';
  }

  String _fmtRam(int bytes) {
    if (bytes <= 0) return '--';
    return '${(bytes / 1024 / 1024).toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final connected = _status['status'] == 'online';
    final phone     = (_status['phoneNumber'] as String? ?? '').replaceAll('@s.whatsapp.net', '');
    final name      = _status['name']     as String? ?? 'Wabot';
    final uptime    = (_status['uptime']  as num?)?.toInt() ?? 0;
    final ram       = (_status['ramUsage'] as num?)?.toInt() ?? 0;
    final node      = _status['node']     as String? ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _g,
        backgroundColor: _card,
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [

            // ── En-tête ────────────────────────────────────────────────────
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Contrôle Bot',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                        color: _ink, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Row(children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: connected ? _g : _red,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: (connected ? _g : _red).withOpacity(0.4 + 0.3 * _pulse.value),
                          blurRadius: 6,
                        )],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(connected ? 'Connecté — $name' : 'Hors ligne',
                      style: TextStyle(color: connected ? _g : _red, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ])),
              if (_loadingStatus)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _g))
              else
                GestureDetector(
                  onTap: _loadAll,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border)),
                    child: const Icon(Icons.refresh_rounded, color: _muted, size: 18),
                  ),
                ),
            ]),

            const SizedBox(height: 20),

            // ── Carte statut ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: connected
                      ? [const Color(0xFF0F2419), const Color(0xFF0A1A10)]
                      : [const Color(0xFF1A0A0A), const Color(0xFF110707)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: connected ? _g.withOpacity(0.3) : _red.withOpacity(0.3)),
              ),
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: (connected ? _g : _red).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(connected ? Icons.smart_toy : Icons.smart_toy_outlined,
                        color: connected ? _g : _red, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
                    if (phone.isNotEmpty)
                      Text('+$phone', style: const TextStyle(color: _muted, fontSize: 13)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (connected ? _g : _red).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(connected ? 'EN LIGNE' : 'HORS LIGNE',
                        style: TextStyle(color: connected ? _g : _red, fontSize: 10,
                            fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  _StatChip(icon: Icons.timer_outlined, label: 'Uptime', value: _fmt(uptime), color: _blue),
                  const SizedBox(width: 8),
                  _StatChip(icon: Icons.memory_outlined, label: 'RAM', value: _fmtRam(ram), color: _orange),
                  const SizedBox(width: 8),
                  _StatChip(icon: Icons.code_outlined, label: 'Node', value: node.isEmpty ? '--' : node, color: _muted),
                ]),
              ]),
            ),

            const SizedBox(height: 16),

            // ── Boutons de contrôle ────────────────────────────────────────
            const Text('Contrôles',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _muted, letterSpacing: 0.5)),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: _CtrlBtn(
                icon: Icons.restart_alt_rounded,
                label: 'Redémarrer',
                color: _blue,
                loading: _actionLoading,
                onTap: () => _action('restart', () async {
                  final api = ref.read(apiServiceProvider);
                  await api.restartBot();
                  _showSnack('Bot en cours de redémarrage...', _blue);
                }),
              )),
              const SizedBox(width: 10),
              Expanded(child: _CtrlBtn(
                icon: Icons.stop_circle_outlined,
                label: 'Déconnecter',
                color: _red,
                loading: _actionLoading,
                onTap: () => _action('reset', () async {
                  final api = ref.read(apiServiceProvider);
                  await api.resetBot();
                  _showSnack('Session réinitialisée — nouveau QR requis', _orange);
                }),
              )),
              const SizedBox(width: 10),
              Expanded(child: _CtrlBtn(
                icon: Icons.refresh_rounded,
                label: 'Relancer',
                color: _g,
                loading: _actionLoading,
                onTap: () => _action('relancer', () async {
                  BotService.resetStartedFlag();
                  await BotService.startIfNeeded();
                  _showSnack('Bot relancé', _g);
                }),
              )),
            ]),

            const SizedBox(height: 20),

            // ── Logs temps réel ────────────────────────────────────────────
            Row(children: [
              const Expanded(
                child: Text('Logs en direct',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: _muted, letterSpacing: 0.5)),
              ),
              GestureDetector(
                onTap: () async {
                  await LogService.I.exportLogs();
                  LogService.info(_TAG, 'Logs exportés');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                  ),
                  child: const Row(children: [
                    Icon(Icons.file_upload_outlined, color: _muted, size: 14),
                    SizedBox(width: 4),
                    Text('Exporter', style: TextStyle(color: _muted, fontSize: 12)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            Container(
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF060708),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: _logs.isEmpty
                  ? const Center(child: Text('Aucun log', style: TextStyle(color: _muted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: _logs.length,
                      reverse: true,
                      itemBuilder: (_, i) {
                        final log = _logs[_logs.length - 1 - i];
                        return _LogLine(log: log);
                      },
                    ),
            ),
              // ── Ressources ────────────────────────────────────────────────────
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.folder_open_rounded,
                title: 'Ressources',
                children: [
                  _ResourceTile(
                    icon: Icons.storage_rounded,
                    label: 'Stockage interne',
                    value: '/data/data/com.aivos.wabot.app/files/wabot',
                  ),
                  _ResourceTile(
                    icon: Icons.sd_storage_rounded,
                    label: 'Stockage externe',
                    value: '/storage/emulated/0/wabot',
                  ),
                  _ResourceTile(
                    icon: Icons.description_rounded,
                    label: 'Log interne',
                    value: LogService.I.internalLogPath ?? 'non initialisé',
                  ),
                  _ResourceTile(
                    icon: Icons.description_outlined,
                    label: 'Log externe',
                    value: LogService.I.externalLogPath ?? 'non disponible',
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 1, color: Color(0x22ffffff)),
                  const SizedBox(height: 4),
                  _ResourceTile(
                    icon: Icons.code_rounded,
                    label: 'GitHub WABOT',
                    value: 'github.com/ferelking242/WABOT',
                    tappable: true,
                  ),
                  _ResourceTile(
                    icon: Icons.link_rounded,
                    label: 'GitHub App',
                    value: 'github.com/ferelking242/wabot_app',
                    tappable: true,
                  ),
                ],
              ),
  
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatChip({required this.icon, required this.label,
    required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 11,
          fontWeight: FontWeight.w700)),
      Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
    ]),
  ));
}

  class _SectionCard extends StatelessWidget {
    final IconData icon;
    final String title;
    final List<Widget> children;
    const _SectionCard({required this.icon, required this.title, required this.children});

    @override
    Widget build(BuildContext context) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF313145)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 15, color: const Color(0xFF7C7C99)),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Color(0xFF7C7C99), letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 10),
          ...children,
        ]),
      );
    }
  }

  class _ResourceTile extends StatelessWidget {
    final IconData icon;
    final String label;
    final String value;
    final bool tappable;
    const _ResourceTile({required this.icon, required this.label, required this.value, this.tappable = false});

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: const Color(0xFF5C5C7A)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF7C7C99))),
            GestureDetector(
              onTap: tappable ? () => Clipboard.setData(ClipboardData(text: value)) : null,
              child: Text(value,
                style: TextStyle(
                  fontSize: 11,
                  color: tappable ? const Color(0xFF7EB3FF) : const Color(0xFFB0B0CC),
                  fontFamily: 'monospace',
                  decoration: tappable ? TextDecoration.underline : null,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ),
          ])),
        ]),
      );
    }
  }
  

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.label, required this.color,
    required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: loading
          ? const Center(child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _muted)))
          : Column(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 11,
                  fontWeight: FontWeight.w700)),
            ]),
    ),
  );
}

class _LogLine extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogLine({required this.log});

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
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';
    } catch (_) { return '--:--:--'; }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_time, style: const TextStyle(fontSize: 10, color: Color(0xFF4A5568),
          fontFamily: 'monospace')),
      const SizedBox(width: 6),
      Text((log['level'] as String? ?? 'INFO').toUpperCase().padRight(5),
          style: TextStyle(fontSize: 10, color: _c, fontFamily: 'monospace',
              fontWeight: FontWeight.w700)),
      const SizedBox(width: 6),
      Expanded(child: Text(log['msg'] as String? ?? '',
          style: const TextStyle(fontSize: 11, color: _muted, fontFamily: 'monospace'),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]),
  );
}
