import 'dart:async';
import 'dart:convert' show LineSplitter;
import 'dart:io' show File, Process;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/api_service.dart';
import '../../../core/services/bot_service.dart';
import '../../../core/services/log_service.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _g      = Color(0xFF25D366);
const _gd     = Color(0xFF128C7E);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF6B7280);
const _border = Color(0xFF1E2530);
const _card   = Color(0xFF0F1117);
const _card2  = Color(0xFF13161F);
const _bg     = Color(0xFF090B10);
const _red    = Color(0xFFFF5B5B);
const _orange = Color(0xFFFF9F43);
const _blue   = Color(0xFF54A0FF);
const _purple = Color(0xFFA29BFE);
const _cyan   = Color(0xFF00CEC9);

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

  // ── Chargement status + logs ───────────────────────────────────────────────
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

  // ── Infos matérielles du téléphone ────────────────────────────────────────
  Future<void> _loadDeviceInfo() async {
    if (kIsWeb) return;
    try {
      final di = DeviceInfoPlugin();
      final info = await di.androidInfo;
      if (mounted) {
        setState(() {
          _deviceInfo = {
            'model':    '${info.brand} ${info.model}',
            'brand':    info.brand,
            'cpu':      info.hardware,
            'cores':    _getCpuCores(),
            'abi':      info.supportedAbis.isNotEmpty ? info.supportedAbis.first : '?',
            'ram':      '...',
            'android':  info.version.release,
            'sdk':      info.version.sdkInt.toString(),
            'board':    info.board,
            'device':   info.device,
          };
        });
        // Chargement RAM et stockage en parallèle
        await Future.wait([
          _loadRamFromMemInfo(setState),
          _loadRomInfo(setState),
        ]);
      }
    } catch (e) {
      LogService.warn(_TAG, 'deviceInfo: $e');
    }
  }

  // ── RAM via /proc/meminfo (pas de permissions requises) ───────────────────
  Future<void> _loadRamFromMemInfo(Function(void Function()) setS) async {
    if (kIsWeb) return;
    try {
      final lines = _readFileSync('/proc/meminfo').split('\n');
      int? totalKb, availKb;
      for (final line in lines) {
        if (line.startsWith('MemTotal:')) {
          totalKb = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
        } else if (line.startsWith('MemAvailable:')) {
          availKb = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
        }
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
      // Lit /proc/cpuinfo disponible sur Android/Linux
      // ignore: avoid_slow_async_io
      final lines = const LineSplitter().convert(
        _readFileSync('/proc/cpuinfo'));
      final count = lines.where((l) => l.startsWith('processor')).length;
      return count > 0 ? '$count cœurs' : '?';
    } catch (_) {
      return '?';
    }
  }

  String _readFileSync(String filePath) {
    try {
      return File(filePath).readAsStringSync();
    } catch (_) { return ''; }
  }

  // ── Stockage via commande 'df' (Android/Linux, pas de permissions) ──────────
  Future<void> _loadRomInfo(Function(void Function()) setS) async {
    if (kIsWeb) return;
    try {
      final result = await Process.run('df', ['-k', '/storage/emulated/0']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).trim().split('\n');
        // Dernière ligne = données (sauter l'en-tête)
        if (lines.length >= 2) {
          final parts = lines.last.trim().split(RegExp(r'\s+'));
          // Format : Filesystem 1K-blocks Used Available Use% Mount
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

  // ── Actions bot ────────────────────────────────────────────────────────────
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  // ── Logs helpers ──────────────────────────────────────────────────────────
  String get _logsText => _logs.map((l) {
    final time = _parseTime(l['time'] as String? ?? '');
    final lvl  = (l['level'] as String? ?? 'INFO').toUpperCase().padRight(5);
    final msg  = l['msg'] as String? ?? '';
    return '[$time] $lvl $msg';
  }).join('\n');

  String _parseTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';
    } catch (_) { return '--:--:--'; }
  }

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: _logsText));
    _showSnack('Logs copiés ✓', _g);
  }

  Future<void> _downloadLogs() async {
    try {
      if (kIsWeb) {
        // Sur web : copie dans le presse-papier uniquement
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
    final connected  = _status['status'] == 'online';
    final phone      = (_status['phoneNumber'] as String? ?? '').replaceAll('@s.whatsapp.net', '');
    final name       = _status['name'] as String? ?? 'Wabot';
    final uptime     = (_status['uptime'] as num?)?.toInt() ?? 0;
    final ram        = (_status['ramUsage'] as num?)?.toInt() ?? 0;
    final node       = _status['node'] as String? ?? '';
    final picUrl     = _status['profilePicUrl'] as String? ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _g,
        backgroundColor: _card,
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
          children: [

            // ── En-tête ──────────────────────────────────────────────────
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Bot',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                        color: _ink, letterSpacing: -0.8)),
                const SizedBox(height: 3),
                Row(children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: connected ? _g : _red,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: (connected ? _g : _red).withOpacity(0.35 + 0.3 * _pulse.value),
                          blurRadius: 8, spreadRadius: 1,
                        )],
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(connected ? 'En ligne' : 'Hors ligne',
                      style: TextStyle(color: connected ? _g : _red, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ])),
              _loadingStatus
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _g))
                  : _IconBtn(icon: Icons.refresh_rounded, onTap: _loadAll),
            ]),

            const SizedBox(height: 20),

            // ── Carte profil WhatsApp ─────────────────────────────────────
            _ProfileCard(
              connected: connected,
              name: name,
              phone: phone,
              picUrl: picUrl,
              uptime: _fmt(uptime),
              ram: _fmtRam(ram),
              node: node,
              pulse: _pulse,
            ),

            const SizedBox(height: 20),

            // ── Contrôles ─────────────────────────────────────────────────
            _SectionLabel(label: 'Contrôles'),
            const SizedBox(height: 10),
            _ControlsBox(
              loading: _actionLoading,
              onRestart: () => _action('restart', () async {
                final api = ref.read(apiServiceProvider);
                await api.restartBot();
                _showSnack('Redémarrage en cours…', _blue);
              }),
              onDisconnect: () => _action('reset', () async {
                final api = ref.read(apiServiceProvider);
                await api.resetBot();
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
            ),

            const SizedBox(height: 24),

            // ── Logs en direct ────────────────────────────────────────────
            Row(children: [
              const _SectionLabel(label: 'Logs en direct'),
              const Spacer(),
              _IconBtn(
                icon: Icons.fullscreen_rounded,
                tooltip: 'Plein écran',
                onTap: _openFullscreenLogs,
              ),
              const SizedBox(width: 6),
              _IconBtn(
                icon: Icons.copy_rounded,
                tooltip: 'Copier',
                onTap: _logs.isEmpty ? null : _copyLogs,
              ),
              const SizedBox(width: 6),
              _IconBtn(
                icon: Icons.file_download_outlined,
                tooltip: 'Télécharger',
                onTap: _logs.isEmpty ? null : _downloadLogs,
              ),
            ]),
            const SizedBox(height: 10),

            Container(
              height: 280,
              decoration: BoxDecoration(
                color: const Color(0xFF060709),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.receipt_long_outlined, color: _muted, size: 32),
                        SizedBox(height: 8),
                        Text('Aucun log disponible',
                            style: TextStyle(color: _muted, fontSize: 13)),
                      ]))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _logs.length,
                        reverse: true,
                        itemBuilder: (_, i) {
                          final log = _logs[_logs.length - 1 - i];
                          return _LogLine(log: log);
                        },
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // ── Ressources appareil ───────────────────────────────────────
            const _SectionLabel(label: 'Ressources appareil'),
            const SizedBox(height: 10),
            _DeviceInfoBox(info: _deviceInfo),

          ],
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _muted, letterSpacing: 0.8));
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
          color: _card2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _border),
        ),
        child: Icon(icon, color: onTap == null ? _muted.withOpacity(0.4) : _muted, size: 16),
      ),
    ),
  );
}

// ─── Carte profil WhatsApp ────────────────────────────────────────────────────
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
    final accent = connected ? _g : _red;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: connected
              ? [const Color(0xFF0C1F12), const Color(0xFF091509)]
              : [const Color(0xFF1A0B0B), const Color(0xFF120808)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.25), width: 1.2),
      ),
      child: Column(children: [
        // ── Profil row ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Row(children: [
            // Avatar
            Stack(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.3), width: 2),
                ),
                child: picUrl.isNotEmpty
                    ? ClipOval(child: Image.network(picUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.smart_toy_rounded,
                            color: accent, size: 28)))
                    : Icon(Icons.smart_toy_rounded, color: accent, size: 28),
              ),
              Positioned(
                bottom: 2, right: 2,
                child: AnimatedBuilder(
                  animation: pulse,
                  builder: (_, __) => Container(
                    width: 13, height: 13,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0C1F12), width: 2),
                      boxShadow: [BoxShadow(
                        color: accent.withOpacity(0.5 * pulse.value),
                        blurRadius: 6,
                      )],
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
                  overflow: TextOverflow.ellipsis),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('+$phone',
                    style: const TextStyle(color: _muted, fontSize: 13,
                        fontFamily: 'monospace')),
              ],
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(connected ? '● EN LIGNE' : '○ HORS LIGNE',
                    style: TextStyle(color: accent, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
            ])),
          ]),
        ),

        // ── Divider ────────────────────────────────────────────────────
        Container(height: 1, color: accent.withOpacity(0.08)),

        // ── Stats ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Row(children: [
            _StatChip(icon: Icons.timer_outlined,  label: 'Uptime', value: uptime, color: _blue),
            const SizedBox(width: 8),
            _StatChip(icon: Icons.memory_outlined, label: 'RAM',    value: ram,    color: _orange),
            const SizedBox(width: 8),
            _StatChip(icon: Icons.code_rounded,    label: 'Node',
                value: node.isEmpty ? '--' : node, color: _purple),
          ]),
        ),
      ]),
    );
  }
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.18)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 12,
          fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 1),
      Text(label, style: const TextStyle(color: _muted, fontSize: 9,
          letterSpacing: 0.3)),
    ]),
  ));
}

// ─── Controls Box ─────────────────────────────────────────────────────────────
class _ControlsBox extends StatelessWidget {
  final bool loading;
  final VoidCallback onRestart, onDisconnect, onRelaunch, onRefresh;

  const _ControlsBox({
    required this.loading, required this.onRestart,
    required this.onDisconnect, required this.onRelaunch, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        // ── Ligne 1 : Redémarrer + Déconnecter ─────────────────────────
        Row(children: [
          Expanded(child: _CtrlBtn(
            icon: Icons.restart_alt_rounded,
            label: 'Redémarrer',
            sublabel: 'Reconnect',
            color: _blue,
            loading: loading,
            onTap: onRestart,
          )),
          const SizedBox(width: 10),
          Expanded(child: _CtrlBtn(
            icon: Icons.logout_rounded,
            label: 'Déconnecter',
            sublabel: 'Nouveau QR',
            color: _red,
            loading: loading,
            onTap: onDisconnect,
          )),
        ]),
        const SizedBox(height: 10),
        // ── Ligne 2 : Relancer + Actualiser ────────────────────────────
        Row(children: [
          Expanded(child: _CtrlBtn(
            icon: Icons.play_circle_outline_rounded,
            label: 'Relancer',
            sublabel: 'Start bot',
            color: _g,
            loading: loading,
            onTap: onRelaunch,
          )),
          const SizedBox(width: 10),
          Expanded(child: _CtrlBtn(
            icon: Icons.sync_rounded,
            label: 'Actualiser',
            sublabel: 'Refresh',
            color: _cyan,
            loading: loading,
            onTap: onRefresh,
          )),
        ]),
      ]),
    );
  }
}

// ─── Ctrl button ──────────────────────────────────────────────────────────────
class _CtrlBtn extends StatefulWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.label, required this.sublabel,
    required this.color, required this.loading, required this.onTap});

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.color.withOpacity(_pressed ? 0.5 : 0.2), width: 1.2),
      ),
      child: widget.loading
          ? Center(child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: widget.color)))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, color: widget.color, size: 18),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                Text(widget.label,
                    style: TextStyle(color: widget.color, fontSize: 12,
                        fontWeight: FontWeight.w700)),
                Text(widget.sublabel,
                    style: TextStyle(color: widget.color.withOpacity(0.55), fontSize: 9)),
              ]),
            ]),
    ),
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
      Text(_time,
          style: const TextStyle(fontSize: 10, color: Color(0xFF3A4255),
              fontFamily: 'monospace')),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: _c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text((log['level'] as String? ?? 'INFO').toUpperCase().substring(0, 4),
            style: TextStyle(fontSize: 9, color: _c, fontFamily: 'monospace',
                fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 6),
      Expanded(child: Text(log['msg'] as String? ?? '',
          style: const TextStyle(fontSize: 11, color: Color(0xFF9AA5B4),
              fontFamily: 'monospace'),
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
          color: _card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: const Center(
          child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _g)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        // ── Header ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.smartphone_rounded, color: _purple, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info['model'] as String? ?? 'Appareil Android',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                  overflow: TextOverflow.ellipsis),
              Text('Android ${info['android'] ?? '?'} · SDK ${info['sdk'] ?? '?'}',
                  style: const TextStyle(fontSize: 11, color: _muted)),
            ])),
          ]),
        ),

        Container(height: 1, color: _border),

        // ── Grille infos ───────────────────────────────────────────────
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
            _DeviceTileWide(icon: Icons.developer_board_outlined, label: 'Board / Device',
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
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: _muted, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, color: color,
            fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
      ])),
    ]),
  ));
}

class _DeviceTileWide extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DeviceTileWide({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _muted.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: Row(children: [
      Icon(icon, color: _muted, size: 15),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: _muted, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11, color: _ink,
            fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
      ]),
    ]),
  );
}

// ─── Page logs plein écran ────────────────────────────────────────────────────
class _FullscreenLogsPage extends StatefulWidget {
  final List<Map<String, dynamic>> logs;
  const _FullscreenLogsPage({required this.logs});
  @override
  State<_FullscreenLogsPage> createState() => _FullscreenLogsPageState();
}

class _FullscreenLogsPageState extends State<_FullscreenLogsPage> {
  String _filter = 'ALL';

  List<Map<String, dynamic>> get _filtered => _filter == 'ALL'
      ? widget.logs
      : widget.logs.where((l) =>
          (l['level'] as String? ?? '').toUpperCase() == _filter).toList();

  Color _lvlColor(String l) {
    switch (l.toUpperCase()) {
      case 'ERROR': return _red;
      case 'WARN':  return _orange;
      default:      return _blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060709),
      appBar: AppBar(
        backgroundColor: _card,
        foregroundColor: _ink,
        title: const Text('Logs en direct',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16, color: _muted),
            label: const Text('Copier', style: TextStyle(color: _muted, fontSize: 13)),
            onPressed: () async {
              final text = widget.logs.map((l) {
                final t = l['time'] as String? ?? '';
                final lvl = (l['level'] as String? ?? '').toUpperCase();
                return '[$t] $lvl ${l['msg'] ?? ''}';
              }).join('\n');
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Logs copiés ✓'), backgroundColor: _g,
                  behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2),
                ));
              }
            },
          ),
        ],
      ),
      body: Column(children: [
        // Filtres
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: ['ALL', 'INFO', 'WARN', 'ERROR'].map((lvl) {
              final sel = lvl == _filter;
              final col = _lvlColor(lvl);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = lvl),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? col.withOpacity(0.18) : _card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? col.withOpacity(0.5) : _border),
                    ),
                    child: Text(lvl,
                        style: TextStyle(color: sel ? col : _muted, fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Liste
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('Aucun log', style: TextStyle(color: _muted)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: _filtered.length,
                  reverse: true,
                  itemBuilder: (_, i) {
                    final log = _filtered[_filtered.length - 1 - i];
                    return _LogLine(log: log);
                  },
                ),
        ),
      ]),
    );
  }
}
