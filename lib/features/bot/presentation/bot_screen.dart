import 'dart:async';
import 'dart:convert' show LineSplitter;
import 'dart:io' show File, Process;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/api_service.dart';
import '../../../core/services/bot_service.dart';
import '../../../core/services/log_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg     = Color(0xFF060709);
const _card   = Color(0xFF0C0F14);
const _card2  = Color(0xFF111620);
const _brdr   = Color(0xFF181E2C);
const _g      = Color(0xFF25D366);
const _gd     = Color(0xFF1AAD4B);
const _ink    = Color(0xFFF2F3F5);
const _sub    = Color(0xFF8A94A8);
const _muted  = Color(0xFF3D4455);
const _red    = Color(0xFFFF5B5B);
const _orange = Color(0xFFFF9D4A);
const _blue   = Color(0xFF4A9EFF);
const _purple = Color(0xFF7C6FF7);
const _cyan   = Color(0xFF20D9C0);

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
  bool _paused = false;
  Map<String, dynamic> _deviceInfo = {};

  static const _TAG = 'BotScreen';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _loadAll();
    _loadDeviceInfo();
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
        api.getLogs(limit: 80),
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

  Future<void> _loadDeviceInfo() async {
    if (kIsWeb) return;
    try {
      final di = DeviceInfoPlugin();
      final info = await di.androidInfo;
      if (mounted) {
        setState(() {
          _deviceInfo = {
            'model':   '${info.brand} ${info.model}',
            'brand':   info.brand,
            'cpu':     info.hardware,
            'cores':   _getCpuCores(),
            'abi':     info.supportedAbis.isNotEmpty ? info.supportedAbis.first : '?',
            'ram':     '...',
            'android': info.version.release,
            'sdk':     info.version.sdkInt.toString(),
            'board':   info.board,
            'device':  info.device,
          };
        });
        await Future.wait([
          _loadRamFromMemInfo(setState),
          _loadRomInfo(setState),
        ]);
      }
    } catch (e) {
      LogService.warn(_TAG, 'deviceInfo: $e');
    }
  }

  Future<void> _loadRamFromMemInfo(Function(void Function()) setS) async {
    if (kIsWeb) return;
    try {
      final lines = _readFileSync('/proc/meminfo').split('\n');
      int? totalKb, availKb;
      for (final line in lines) {
        if (line.startsWith('MemTotal:'))
          totalKb = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
        else if (line.startsWith('MemAvailable:'))
          availKb = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
        if (totalKb != null && availKb != null) break;
      }
      if (totalKb != null && totalKb > 0 && mounted) {
        final totalGb = (totalKb / 1048576).toStringAsFixed(1);
        final usedStr = availKb != null
            ? '${((totalKb - availKb) / 1048576).toStringAsFixed(1)} / $totalGb GB'
            : '$totalGb GB';
        setS(() => _deviceInfo['ram'] = usedStr);
      } else if (mounted) {
        setS(() => _deviceInfo['ram'] = '?');
      }
    } catch (_) {
      if (mounted) setS(() => _deviceInfo['ram'] = '?');
    }
  }

  String _getCpuCores() {
    if (kIsWeb) return '?';
    try {
      final lines = const LineSplitter().convert(_readFileSync('/proc/cpuinfo'));
      final count = lines.where((l) => l.startsWith('processor')).length;
      return count > 0 ? '$count cœurs' : '?';
    } catch (_) { return '?'; }
  }

  String _readFileSync(String filePath) {
    try { return File(filePath).readAsStringSync(); } catch (_) { return ''; }
  }

  Future<void> _loadRomInfo(Function(void Function()) setS) async {
    if (kIsWeb) return;
    try {
      final result = await Process.run('df', ['-k', '/storage/emulated/0']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).trim().split('\n');
        if (lines.length >= 2) {
          final parts = lines.last.trim().split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final totalKb = int.tryParse(parts[1]) ?? 0;
            final availKb = int.tryParse(parts[3]) ?? 0;
            if (totalKb > 0 && mounted) {
              setS(() {
                _deviceInfo['rom']  = '${(totalKb / 1048576).toStringAsFixed(0)} GB';
                _deviceInfo['free'] = '${(availKb / 1048576).toStringAsFixed(1)} GB libre';
              });
              return;
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setS(() {
        _deviceInfo['rom']  = '—';
        _deviceInfo['free'] = '—';
      });
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
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  String get _logsText => _logs.map((l) {
    final time = _parseTime(l['time'] as String? ?? '');
    final lvl  = (l['level'] as String? ?? 'INFO').toUpperCase().padRight(5);
    final msg  = l['msg'] as String? ?? '';
    return '[$time] $lvl $msg';
  }).join('\n');

  String _parseTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:'
             '${dt.minute.toString().padLeft(2,'0')}:'
             '${dt.second.toString().padLeft(2,'0')}';
    } catch (_) { return '--:--:--'; }
  }

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: _logsText));
    _showSnack('Logs copiés ✓', _g);
  }

  Future<void> _downloadLogs() async {
    try {
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: _logsText));
        _showSnack('Logs copiés (téléchargement indispo sur web) ✓', _g);
        return;
      }
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/wabot_logs_${DateTime.now().millisecondsSinceEpoch}.txt';
      await File(path).writeAsString(_logsText);
      await Share.shareXFiles([XFile(path)], text: 'Wabot Logs');
    } catch (e) {
      _showSnack('Erreur export: $e', _red);
    }
  }

  void _openFullscreenLogs() {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FullscreenLogsPage(logs: _logs),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final connected = _status['status'] == 'online';
    final phone     = (_status['phoneNumber'] as String? ?? '').replaceAll('@s.whatsapp.net', '');
    final name      = _status['name'] as String? ?? 'Wabot';
    final uptime    = (_status['uptime'] as num?)?.toInt() ?? 0;
    final ram       = (_status['ramUsage'] as num?)?.toInt() ?? 0;
    final node      = _status['node'] as String? ?? '';
    final picUrl    = _status['profilePicUrl'] as String? ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _g,
        backgroundColor: _card,
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [

            // ── Header ────────────────────────────────────────────────────
            _BotHeader(connected: connected, loading: _loadingStatus,
                pulse: _pulse, onRefresh: _loadAll)
                .animate().fadeIn(duration: 200.ms),

            const SizedBox(height: 16),

            // ── Profil ────────────────────────────────────────────────────
            _ProfileCard(
              connected: connected, name: name, phone: phone,
              picUrl: picUrl, uptime: _fmt(uptime),
              ram: _fmtRam(ram), node: node, pulse: _pulse,
            ).animate().fadeIn(duration: 300.ms, delay: 40.ms)
                .slideY(begin: 0.03, curve: Curves.easeOut),

            const SizedBox(height: 20),

            // ── Contrôles ─────────────────────────────────────────────────
            Row(children: [
              const _SecLabel(label: 'Contrôles'),
              const Spacer(),
              if (_actionLoading)
                const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _g)),
            ]).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 10),
            _ControlsBox(
              loading: _actionLoading, paused: _paused,
              onPauseToggle: () => _action('pause', () async {
                final api = ref.read(apiServiceProvider);
                final nowPaused = !_paused;
                final ok = nowPaused ? await api.pauseBot() : await api.resumeBot();
                if (ok) {
                  setState(() => _paused = nowPaused);
                  _showSnack(nowPaused
                      ? '⏸ Bot mis en pause'
                      : '▶ Bot repris',
                      nowPaused ? _orange : _g);
                }
              }),
              onRestart: () => _action('restart', () async {
                await ref.read(apiServiceProvider).restartBot();
                _showSnack('Redémarrage en cours…', _blue);
              }),
              onDisconnect: () => _action('reset', () async {
                await ref.read(apiServiceProvider).resetBot();
                _showSnack('Session réinitialisée — nouveau QR requis', _orange);
              }),
              onRelaunch: () => _action('relancer', () async {
                BotService.resetStartedFlag();
                await BotService.startIfNeeded();
                _showSnack('Bot relancé ✓', _g);
              }),
              onRefresh: () => _action('refresh', () async {
                await _loadAll();
                _showSnack('Statut actualisé ✓', _cyan);
              }),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

            const SizedBox(height: 24),

            // ── Logs en direct ────────────────────────────────────────────
            Row(children: [
              const _SecLabel(label: 'Logs en direct'),
              const Spacer(),
              _IconBtn(icon: Icons.fullscreen_rounded, tooltip: 'Plein écran',
                  onTap: _openFullscreenLogs),
              const SizedBox(width: 6),
              _IconBtn(icon: Icons.copy_rounded, tooltip: 'Copier',
                  onTap: _logs.isEmpty ? null : _copyLogs),
              const SizedBox(width: 6),
              _IconBtn(icon: Icons.file_download_outlined, tooltip: 'Télécharger',
                  onTap: _logs.isEmpty ? null : _downloadLogs),
            ]).animate().fadeIn(delay: 140.ms),
            const SizedBox(height: 10),
            _TerminalBox(logs: _logs)
                .animate().fadeIn(duration: 300.ms, delay: 160.ms),

            const SizedBox(height: 24),

            // ── Ressources appareil ───────────────────────────────────────
            const _SecLabel(label: 'Ressources appareil')
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 10),
            _DeviceInfoBox(info: _deviceInfo)
                .animate().fadeIn(duration: 300.ms, delay: 220.ms),

          ],
        ),
      ),
    );
  }
}

// ─── Bot Header ───────────────────────────────────────────────────────────────
class _BotHeader extends StatelessWidget {
  final bool connected, loading;
  final AnimationController pulse;
  final Future<void> Function() onRefresh;
  const _BotHeader({required this.connected, required this.loading,
      required this.pulse, required this.onRefresh});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Bot', style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900,
          color: _ink, letterSpacing: -0.8)),
      const SizedBox(height: 4),
      Row(children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (_, __) => Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: connected ? _g : _red,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: (connected ? _g : _red)
                    .withOpacity(0.3 + 0.35 * pulse.value),
                blurRadius: 7 + 5 * pulse.value,
              )],
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(connected ? 'En ligne' : 'Hors ligne',
            style: TextStyle(
                color: connected ? _g : _red,
                fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ])),
    if (loading)
      const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _g))
    else
      _IconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
  ]);
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SecLabel extends StatelessWidget {
  final String label;
  const _SecLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label, style: const TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700,
      color: _sub, letterSpacing: 0.5));
}

// ─── Icon button ──────────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  const _IconBtn({required this.icon, this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? '',
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: _card2, borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _brdr),
        ),
        child: Icon(icon,
            color: onTap == null ? _muted.withOpacity(0.4) : _sub, size: 16),
      ),
    ),
  );
}

// ─── Profile card ─────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final bool connected;
  final String name, phone, picUrl, uptime, ram, node;
  final AnimationController pulse;

  const _ProfileCard({
    required this.connected, required this.name, required this.phone,
    required this.picUrl, required this.uptime, required this.ram,
    required this.node, required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final ac = connected ? _g : _red;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: connected
              ? [const Color(0xFF081410), const Color(0xFF060C09), _bg]
              : [const Color(0xFF130808), const Color(0xFF0D0505), _bg],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ac.withOpacity(0.22), width: 1.2),
        boxShadow: [BoxShadow(
          color: ac.withOpacity(0.08), blurRadius: 24, spreadRadius: -4)],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(children: [
            // Avatar
            SizedBox(width: 64, height: 64, child: Stack(children: [
              AnimatedBuilder(
                animation: pulse,
                builder: (_, __) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: ac.withOpacity(0.18 + 0.18 * pulse.value),
                      blurRadius: 12 + 8 * pulse.value,
                    )],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [ac, ac.withOpacity(0.35), ac]),
                ),
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: _card),
                  child: ClipOval(
                    child: picUrl.isNotEmpty
                        ? Image.network(picUrl, fit: BoxFit.cover,
                            width: 59, height: 59,
                            errorBuilder: (_, __, ___) =>
                                _AvatarIcon(color: ac))
                        : _AvatarIcon(color: ac),
                  ),
                ),
              ),
              Positioned(
                bottom: 1, right: 1,
                child: AnimatedBuilder(
                  animation: pulse,
                  builder: (_, __) => Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: ac, shape: BoxShape.circle,
                      border: Border.all(color: _card, width: 2.5),
                      boxShadow: [BoxShadow(
                        color: ac.withOpacity(0.65 * pulse.value),
                        blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            ])),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
                  overflow: TextOverflow.ellipsis),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('+$phone', style: const TextStyle(
                    color: _sub, fontSize: 12, fontFamily: 'monospace')),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: ac.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ac.withOpacity(0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 5, height: 5,
                        decoration: BoxDecoration(
                            color: ac, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(connected ? 'EN LIGNE' : 'HORS LIGNE',
                        style: TextStyle(color: ac, fontSize: 9.5,
                            fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ]),
                ),
              ]),
            ])),
          ]),
        ),

        Container(height: 1, color: ac.withOpacity(0.1)),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Row(children: [
            _StatChip(icon: Icons.timer_outlined, label: 'Uptime',
                value: uptime, color: _blue),
            const SizedBox(width: 8),
            _StatChip(icon: Icons.memory_outlined, label: 'RAM',
                value: ram, color: _orange),
            const SizedBox(width: 8),
            _StatChip(icon: Icons.code_rounded, label: 'Node',
                value: node.isEmpty ? '--' : node, color: _purple),
          ]),
        ),
      ]),
    );
  }
}

class _AvatarIcon extends StatelessWidget {
  final Color color;
  const _AvatarIcon({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 59, height: 59, color: color.withOpacity(0.1),
    child: Icon(Icons.smart_toy_rounded, color: color, size: 26),
  );
}

// ─── Stat chip ────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatChip({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: color.withOpacity(0.18)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(color: color, fontSize: 12,
          fontWeight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 1),
      Text(label, style: TextStyle(
          color: color.withOpacity(0.55), fontSize: 9, letterSpacing: 0.3)),
    ]),
  ));
}

// ─── Controls Box ─────────────────────────────────────────────────────────────
class _ControlsBox extends StatelessWidget {
  final bool loading, paused;
  final VoidCallback onRestart, onDisconnect, onRelaunch, onRefresh, onPauseToggle;

  const _ControlsBox({
    required this.loading, required this.paused,
    required this.onRestart, required this.onDisconnect,
    required this.onRelaunch, required this.onRefresh,
    required this.onPauseToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brdr),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Pause/Resume full-width
        _PauseBtn(paused: paused, loading: loading, onTap: onPauseToggle),
        const SizedBox(height: 10),
        // 2×2 grid
        Row(children: [
          Expanded(child: _CtrlBtn(icon: Icons.restart_alt_rounded,
              label: 'Redémarrer', sublabel: 'Reconnect',
              color: _blue, loading: loading, onTap: onRestart)),
          const SizedBox(width: 10),
          Expanded(child: _CtrlBtn(icon: Icons.logout_rounded,
              label: 'Déconnecter', sublabel: 'Nouveau QR',
              color: _red, loading: loading, onTap: onDisconnect)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _CtrlBtn(icon: Icons.play_circle_outline_rounded,
              label: 'Relancer', sublabel: 'Start bot',
              color: _g, loading: loading, onTap: onRelaunch)),
          const SizedBox(width: 10),
          Expanded(child: _CtrlBtn(icon: Icons.sync_rounded,
              label: 'Actualiser', sublabel: 'Refresh',
              color: _cyan, loading: loading, onTap: onRefresh)),
        ]),
      ]),
    );
  }
}

// ─── Pause button ─────────────────────────────────────────────────────────────
class _PauseBtn extends StatelessWidget {
  final bool paused, loading;
  final VoidCallback? onTap;
  const _PauseBtn({required this.paused, required this.loading, this.onTap});
  @override
  Widget build(BuildContext context) {
    final col = paused ? _g : _orange;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [col.withOpacity(0.14), col.withOpacity(0.07)],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: col.withOpacity(0.4), width: 1.2),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(paused ? Icons.play_circle_rounded : Icons.pause_circle_rounded,
              color: col, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            Text(paused ? 'Reprendre le bot' : 'Mettre en pause',
                style: TextStyle(color: col, fontSize: 13,
                    fontWeight: FontWeight.w800)),
            Text(paused
                    ? 'Bot en pause — reprendre les messages'
                    : 'Suspendre temporairement la réception',
                style: TextStyle(color: col.withOpacity(0.55), fontSize: 9.5)),
          ])),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: col.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: col.withOpacity(0.4)),
            ),
            child: Text(paused ? 'EN PAUSE' : 'ACTIF',
                style: TextStyle(color: col, fontSize: 9,
                    fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ]),
      ),
    );
  }
}

// ─── Control button ───────────────────────────────────────────────────────────
class _CtrlBtn extends StatefulWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.label,
      required this.sublabel, required this.color,
      required this.loading, required this.onTap});
  @override
  State<_CtrlBtn> createState() => _CtrlBtnState();
}

class _CtrlBtnState extends State<_CtrlBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp:   (_) => setState(() => _pressed = false),
    onTapCancel: () => setState(() => _pressed = false),
    onTap: widget.loading ? null : widget.onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _pressed
            ? widget.color.withOpacity(0.2)
            : widget.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
            color: widget.color.withOpacity(_pressed ? 0.5 : 0.2),
            width: 1.2),
        boxShadow: _pressed ? [BoxShadow(
          color: widget.color.withOpacity(0.15),
          blurRadius: 8)] : [],
      ),
      child: widget.loading
          ? Center(child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: widget.color)))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, color: widget.color, size: 18),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                Text(widget.label, style: TextStyle(
                    color: widget.color, fontSize: 12,
                    fontWeight: FontWeight.w700)),
                Text(widget.sublabel, style: TextStyle(
                    color: widget.color.withOpacity(0.55), fontSize: 9)),
              ]),
            ]),
    ),
  );
}

// ─── Terminal box ─────────────────────────────────────────────────────────────
class _TerminalBox extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const _TerminalBox({required this.logs});

  @override
  Widget build(BuildContext context) => Container(
    height: 290,
    decoration: BoxDecoration(
      color: const Color(0xFF040507),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _brdr),
      boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(children: [
      // Terminal chrome bar
      Container(
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0C11),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(bottom: BorderSide(color: _brdr)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Container(width: 9, height: 9,
              decoration: BoxDecoration(
                  color: _red.withOpacity(0.7), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Container(width: 9, height: 9,
              decoration: BoxDecoration(
                  color: _orange.withOpacity(0.7), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Container(width: 9, height: 9,
              decoration: BoxDecoration(
                  color: _g.withOpacity(0.7), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text('wabot@node ~ logs', style: TextStyle(
              color: _sub.withOpacity(0.5), fontSize: 10,
              fontFamily: 'monospace')),
          const Spacer(),
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
                color: _g.withOpacity(0.8), shape: BoxShape.circle),
          ),
        ]),
      ),
      // Log content
      Expanded(
        child: logs.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_outlined, color: _muted, size: 30),
                const SizedBox(height: 8),
                Text('En attente de logs…', style: TextStyle(
                    color: _muted, fontSize: 12, fontFamily: 'monospace')),
              ]))
            : ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: logs.length,
                  reverse: true,
                  itemBuilder: (_, i) {
                    final log = logs[logs.length - 1 - i];
                    return _LogLine(log: log);
                  },
                ),
              ),
      ),
    ]),
  );
}

// ─── Log line ─────────────────────────────────────────────────────────────────
class _LogLine extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogLine({required this.log});

  Color get _c {
    switch ((log['level'] as String? ?? '').toUpperCase()) {
      case 'ERROR': return _red;
      case 'WARN':  return _orange;
      case 'CMD':   return _purple;
      case 'OK':    return _g;
      default:      return _blue;
    }
  }

  String get _time {
    try {
      final dt = DateTime.parse(log['time'] as String? ?? '').toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:'
             '${dt.minute.toString().padLeft(2,'0')}:'
             '${dt.second.toString().padLeft(2,'0')}';
    } catch (_) { return '--:--:--'; }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3.5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_time, style: const TextStyle(
          fontSize: 10, color: Color(0xFF2E3547), fontFamily: 'monospace')),
      const SizedBox(width: 7),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: _c.withOpacity(0.14),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text((log['level'] as String? ?? 'INFO').toUpperCase()
                .substring(0, (log['level'] as String? ?? 'INFO').length.clamp(0, 4)),
            style: TextStyle(fontSize: 9, color: _c,
                fontFamily: 'monospace', fontWeight: FontWeight.w900)),
      ),
      const SizedBox(width: 7),
      Expanded(child: Text(log['msg'] as String? ?? '',
          style: const TextStyle(fontSize: 11, color: Color(0xFF8896AA),
              fontFamily: 'monospace', height: 1.35),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─── Device info box ──────────────────────────────────────────────────────────
class _DeviceInfoBox extends StatelessWidget {
  final Map<String, dynamic> info;
  const _DeviceInfoBox({required this.info});

  @override
  Widget build(BuildContext context) {
    if (info.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _brdr),
        ),
        child: const Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _g))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brdr),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smartphone_rounded, color: _purple, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(info['model'] as String? ?? 'Appareil Android',
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: _ink),
                  overflow: TextOverflow.ellipsis),
              Text('Android ${info['android'] ?? '?'} · SDK ${info['sdk'] ?? '?'}',
                  style: const TextStyle(fontSize: 11, color: _sub)),
            ])),
          ]),
        ),
        Divider(height: 1, color: _brdr),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              _DeviceTile(icon: Icons.developer_board_rounded, label: 'CPU',
                  value: info['cpu'] as String? ?? '?', color: _blue),
              const SizedBox(width: 8),
              _DeviceTile(icon: Icons.grid_view_rounded, label: 'Cœurs CPU',
                  value: info['cores'] as String? ?? '?', color: _blue),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _DeviceTile(icon: Icons.memory_rounded, label: 'RAM',
                  value: info['ram'] as String? ?? '?', color: _g),
              const SizedBox(width: 8),
              _DeviceTile(icon: Icons.storage_rounded, label: 'ROM',
                  value: info['rom'] as String? ?? '?', color: _orange),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _DeviceTile(icon: Icons.folder_open_rounded, label: 'Libre',
                  value: info['free'] as String? ?? '?', color: _cyan),
              const SizedBox(width: 8),
              _DeviceTile(icon: Icons.architecture_rounded, label: 'ABI',
                  value: info['abi'] as String? ?? '?', color: _purple),
            ]),
            const SizedBox(height: 8),
            _DeviceTileWide(icon: Icons.developer_board_outlined,
                label: 'Board / Device',
                value: '${info['board'] ?? '?'} / ${info['device'] ?? '?'}'),
          ]),
        ),
      ]),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _DeviceTile({required this.icon, required this.label,
      required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(label, style: const TextStyle(
            fontSize: 9, color: _muted, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
            fontSize: 12, color: color, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
      ])),
    ]),
  ));
}

class _DeviceTileWide extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DeviceTileWide({required this.icon, required this.label,
      required this.value});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _muted.withOpacity(0.05),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: _brdr),
    ),
    child: Row(children: [
      Icon(icon, color: _sub, size: 14),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
            fontSize: 9, color: _muted, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(
            fontSize: 11, color: _ink, fontFamily: 'monospace'),
            overflow: TextOverflow.ellipsis),
      ]),
    ]),
  );
}

// ─── Fullscreen logs page ─────────────────────────────────────────────────────
class _FullscreenLogsPage extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  const _FullscreenLogsPage({required this.logs});
  @override
  State<_FullscreenLogsPage> createState() => _FullscreenLogsPageState();
}

class _FullscreenLogsPageState extends State<_FullscreenLogsPage> {
  String _filter  = 'ALL';
  String _search  = '';
  bool   _showSearch = false;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  static const _filters = ['ALL', 'CMD', 'INFO', 'WARN', 'ERROR', 'OK'];

  Color _lvlColor(String l) {
    switch (l.toUpperCase()) {
      case 'ERROR': return _red;
      case 'WARN':  return _orange;
      case 'CMD':   return _purple;
      case 'OK':    return _g;
      default:      return _blue;
    }
  }

  bool _matchFilter(Map<String, dynamic> l) {
    if (_filter == 'ALL') return true;
    if (_filter == 'CMD') {
      final msg = (l['msg'] as String? ?? '').toLowerCase();
      return msg.contains('cmd') || msg.contains('command') || msg.startsWith('.');
    }
    if (_filter == 'OK') {
      final msg = (l['msg'] as String? ?? '').toLowerCase();
      return msg.contains('✓') || msg.contains('ok') || msg.contains('success');
    }
    return (l['level'] as String? ?? '').toUpperCase() == _filter;
  }

  List<Map<String, dynamic>> get _filtered {
    var list = widget.logs.where(_matchFilter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((l) =>
          (l['msg'] as String? ?? '').toLowerCase().contains(q) ||
          (l['level'] as String? ?? '').toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total  = widget.logs.length;
    final errors = widget.logs.where((l) =>
        (l['level'] as String? ?? '').toUpperCase() == 'ERROR').length;
    final warns  = widget.logs.where((l) =>
        (l['level'] as String? ?? '').toUpperCase() == 'WARN').length;

    return Scaffold(
      backgroundColor: const Color(0xFF060709),
      appBar: AppBar(
        backgroundColor: _card,
        foregroundColor: _ink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _showSearch
            ? TextField(
                controller: _searchCtrl, autofocus: true,
                style: const TextStyle(color: _ink, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher dans les logs…',
                  hintStyle: TextStyle(color: _sub, fontSize: 13),
                  border: InputBorder.none,
                  suffixIcon: _search.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() {
                            _search = '';
                            _searchCtrl.clear();
                          }),
                          child: const Icon(Icons.close_rounded,
                              color: _sub, size: 16))
                      : null,
                ),
                onChanged: (v) => setState(() => _search = v),
              )
            : RichText(text: TextSpan(
                text: 'Logs ',
                style: const TextStyle(fontWeight: FontWeight.w800,
                    fontSize: 16, color: _ink),
                children: [
                  TextSpan(text: '($total)',
                      style: TextStyle(color: _sub, fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  if (errors > 0)
                    TextSpan(text: '  $errors ERR',
                        style: const TextStyle(color: _red, fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  if (warns > 0)
                    TextSpan(text: '  $warns WARN',
                        style: const TextStyle(color: _orange, fontSize: 11,
                            fontWeight: FontWeight.w700)),
                ],
              )),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded,
                color: _sub, size: 20),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) { _search = ''; _searchCtrl.clear(); }
            }),
          ),
          IconButton(
            icon: const Icon(Icons.vertical_align_bottom_rounded,
                color: _sub, size: 20),
            tooltip: 'Bas',
            onPressed: () => _scrollCtrl.animateTo(0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut),
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 15, color: _sub),
            label: const Text('Copier',
                style: TextStyle(color: _sub, fontSize: 12)),
            onPressed: () async {
              final text = widget.logs.map((l) {
                final t   = l['time']  as String? ?? '';
                final lvl = (l['level'] as String? ?? '').toUpperCase();
                return '[$t] [$lvl] ${l['msg'] ?? ''}';
              }).join('\n');
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Logs copiés ✓'), backgroundColor: _g,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ));
              }
            },
          ),
        ],
      ),
      body: Column(children: [
        // Filter bar
        Container(
          color: _card.withOpacity(0.6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: _filters.map((lvl) {
                final sel = lvl == _filter;
                final col = _lvlColor(lvl);
                final cnt = lvl == 'ALL' ? total
                    : lvl == 'CMD' ? widget.logs.where((l) {
                        final m = (l['msg'] as String? ?? '').toLowerCase();
                        return m.contains('cmd') || m.contains('command') ||
                            m.startsWith('.');
                      }).length
                    : lvl == 'OK' ? widget.logs.where((l) {
                        final m = (l['msg'] as String? ?? '').toLowerCase();
                        return m.contains('✓') || m.contains('ok') ||
                            m.contains('success');
                      }).length
                    : widget.logs.where((l) =>
                        (l['level'] as String? ?? '').toUpperCase() == lvl)
                        .length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = lvl),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? col.withOpacity(0.18) : _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? col.withOpacity(0.5) : _brdr),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(lvl, style: TextStyle(
                            color: sel ? col : _sub,
                            fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: col.withOpacity(sel ? 0.2 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$cnt', style: TextStyle(
                              color: col.withOpacity(sel ? 1 : 0.5),
                              fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        if (_search.isNotEmpty)
          Container(
            color: const Color(0xFF060709),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              const Icon(Icons.search_rounded, color: _sub, size: 13),
              const SizedBox(width: 6),
              Text('${filtered.length} résultats pour "$_search"',
                  style: TextStyle(color: _sub, fontSize: 11)),
            ]),
          ),

        Expanded(
          child: filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined, color: _muted, size: 40),
                  const SizedBox(height: 12),
                  Text(_search.isNotEmpty
                      ? 'Aucun log ne correspond'
                      : 'Aucun log pour ce filtre',
                      style: TextStyle(color: _sub, fontSize: 13)),
                ]))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
                  itemCount: filtered.length,
                  reverse: true,
                  itemBuilder: (_, i) {
                    final log = filtered[filtered.length - 1 - i];
                    return _FullLogLine(log: log, lvlColor: _lvlColor);
                  },
                ),
        ),
      ]),
    );
  }
}

// ─── Full log line ────────────────────────────────────────────────────────────
class _FullLogLine extends StatelessWidget {
  final Map<String, dynamic> log;
  final Color Function(String) lvlColor;
  const _FullLogLine({required this.log, required this.lvlColor});

  @override
  Widget build(BuildContext context) {
    final lvl = (log['level'] as String? ?? 'INFO').toUpperCase();
    final msg = log['msg'] as String? ?? '';
    final t   = log['time'] as String? ?? '';
    final col = lvlColor(lvl);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: col.withOpacity(0.04),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: col.withOpacity(0.1)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: col.withOpacity(0.15),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            lvl.length > 4 ? '${lvl.substring(0, 4)}.' : lvl,
            textAlign: TextAlign.center,
            style: TextStyle(color: col, fontSize: 9,
                fontWeight: FontWeight.w900, letterSpacing: 0.3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(msg, style: const TextStyle(color: Color(0xFFDDE1E7),
              fontSize: 12.5, fontFamily: 'monospace', height: 1.4)),
          if (t.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(t, style: TextStyle(color: _sub, fontSize: 9.5)),
          ],
        ])),
        Icon(_lvlIcon(lvl), color: col.withOpacity(0.5), size: 12),
      ]),
    );
  }

  static IconData _lvlIcon(String lvl) {
    switch (lvl) {
      case 'ERROR': return Icons.error_outline_rounded;
      case 'WARN':  return Icons.warning_amber_rounded;
      case 'CMD':   return Icons.terminal_rounded;
      case 'OK':    return Icons.check_circle_outline_rounded;
      default:      return Icons.info_outline_rounded;
    }
  }
}
