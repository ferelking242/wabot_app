import 'dart:io' show File, Process;
import 'dart:convert' show LineSplitter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';

const _g      = Color(0xFF25D366);
const _gd     = Color(0xFF128C7E);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _border = Color(0xFF1E2128);
const _card   = Color(0xFF111316);
const _bg     = Color(0xFF0D0E11);
const _red    = Color(0xFFFF6B6B);
const _blue   = Color(0xFF57B6FF);
const _purple = Color(0xFF9B59B6);
const _orange = Color(0xFFE67E22);
const _teal   = Color(0xFF1ABC9C);
const _yellow = Color(0xFFF1C40F);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _botStatus;
  Map<String, dynamic>? _analytics;
  Map<String, dynamic>  _device = {};
  bool _loading = true;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _load();
    _loadDevice();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api     = ref.read(apiServiceProvider);
      final results = await Future.wait([
        api.getBotStatus(),
        api.getAnalytics(period: '7d'),
      ]);
      if (mounted) setState(() {
        _botStatus = results[0];
        _analytics = results[1];
        _loading   = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Infos téléphone (Android/Linux) ───────────────────────────────────────
  Future<void> _loadDevice() async {
    if (kIsWeb) return;
    try {
      await Future.wait([
        _loadRam(),
        _loadCpu(),
        _loadStorage(),
      ]);
    } catch (_) {}
  }

  Future<void> _loadRam() async {
    if (kIsWeb) return;
    try {
      final lines = _readFileSync('/proc/meminfo').split('\n');
      int? totalKb, availKb;
      for (final line in lines) {
        if (line.startsWith('MemTotal:'))
          totalKb = int.tryParse(line.replaceAll(RegExp(r'[^\d]'), ''));
        if (line.startsWith('MemAvailable:'))
          availKb = int.tryParse(line.replaceAll(RegExp(r'[^\d]'), ''));
        if (totalKb != null && availKb != null) break;
      }
      if (totalKb != null && totalKb > 0 && mounted) {
        final usedMb  = availKb != null ? ((totalKb - availKb) / 1024).round() : 0;
        final totalMb = (totalKb / 1024).round();
        setState(() {
          _device['ramUsedMb']  = usedMb;
          _device['ramTotalMb'] = totalMb;
          _device['ramPct']     = totalMb > 0 ? usedMb / totalMb : 0.0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCpu() async {
    if (kIsWeb) return;
    try {
      final lines = const LineSplitter().convert(_readFileSync('/proc/cpuinfo'));
      final cores = lines.where((l) => l.startsWith('processor')).length;
      String hardware = '';
      for (final l in lines) {
        if (l.startsWith('Hardware') || l.startsWith('model name')) {
          hardware = l.split(':').last.trim();
          break;
        }
      }
      // Fréquence max depuis /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq
      int freqKhz = 0;
      try {
        final f = _readFileSync('/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq').trim();
        freqKhz = int.tryParse(f) ?? 0;
      } catch (_) {}
      if (mounted) setState(() {
        _device['cpuCores']   = cores;
        _device['cpuName']    = hardware.isEmpty ? 'ARM' : hardware;
        _device['cpuFreqMhz'] = freqKhz > 0 ? (freqKhz / 1000).round() : 0;
      });
    } catch (_) {}
  }

  Future<void> _loadStorage() async {
    if (kIsWeb) return;
    try {
      final result = await Process.run('df', ['-k', '/data']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).trim().split('\n');
        if (lines.length >= 2) {
          final parts = lines.last.trim().split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final totalKb = int.tryParse(parts[1]) ?? 0;
            final usedKb  = int.tryParse(parts[2]) ?? 0;
            if (totalKb > 0 && mounted) setState(() {
              _device['storTotalGb'] = (totalKb / 1048576).toStringAsFixed(0);
              _device['storUsedGb']  = (usedKb  / 1048576).toStringAsFixed(1);
              _device['storPct']     = usedKb / totalKb;
            });
          }
        }
      }
    } catch (_) {}
  }

  String _readFileSync(String p) {
    try { return File(p).readAsStringSync(); } catch (_) { return ''; }
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  String _fmtUptime(int seconds) {
    if (seconds <= 0) return '--';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final d         = _botStatus ?? {};
    final an        = _analytics ?? {};
    final connected = d['status'] == 'online';
    final phone     = (d['phoneNumber'] as String? ?? '').replaceAll('@s.whatsapp.net', '');
    final name      = d['name'] as String? ?? 'Wabot';
    final uptime    = d['uptime'] as int? ?? 0;
    final ram       = d['ramUsage'] as int? ?? 0;
    final ramTotal  = d['ramTotal'] as int? ?? 0;
    final ramPct    = ramTotal > 0 ? (ram / ramTotal).clamp(0.0, 1.0) : 0.0;
    final picUrl    = d['profilePicUrl'] as String? ?? '';
    final nodeVer   = d['node'] as String? ?? '';
    final groups    = an['totalGroups']   as int? ?? (d['groupsCount']   as int? ?? 0);
    final msgs      = an['totalMessages'] as int? ?? (d['messagesTotal'] as int? ?? 0);
    final cmds      = an['totalCommands'] as int? ?? 0;
    final users     = an['totalUsers']    as int? ?? 0;
    final msgGrowth = (an['messagesGrowth'] as num?)?.toDouble() ?? 0.0;
    final cmdGrowth = (an['commandsGrowth'] as num?)?.toDouble() ?? 0.0;
    final topCmds   = (an['topCommands'] as List? ?? []).cast<Map<String, dynamic>>();
    final maxCount  = topCmds.isNotEmpty ? (topCmds.first['count'] as int? ?? 1) : 1;

    // Device stats
    final devRamUsed  = _device['ramUsedMb']  as int? ?? 0;
    final devRamTotal = _device['ramTotalMb'] as int? ?? 0;
    final devRamPct   = (_device['ramPct']    as double? ?? 0.0).clamp(0.0, 1.0);
    final cpuCores    = _device['cpuCores']   as int? ?? 0;
    final cpuName     = _device['cpuName']    as String? ?? '';
    final cpuFreq     = _device['cpuFreqMhz'] as int? ?? 0;
    final storTotal   = _device['storTotalGb'] as String? ?? '--';
    final storUsed    = _device['storUsedGb']  as String? ?? '--';
    final storPct     = (_device['storPct']    as double? ?? 0.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _g,
        backgroundColor: _card,
        onRefresh: () async { await _load(); await _loadDevice(); },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
          children: [

            // ── Header ─────────────────────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dashboard', style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900,
                    color: _ink, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Row(children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: connected ? _g : _red,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: (connected ? _g : _red).withOpacity(
                              connected ? 0.3 + 0.4 * _pulseCtrl.value : 0.3),
                          blurRadius: connected ? 4 + 4 * _pulseCtrl.value : 4,
                        )],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(connected ? 'Bot connecté' : 'Bot hors ligne',
                      style: TextStyle(
                          color: connected ? _g : _red,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ])),
              if (_loading)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: _g, strokeWidth: 2))
              else
                GestureDetector(
                  onTap: () async { await _load(); await _loadDevice(); },
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: _muted, size: 18)),
                ),
            ]),
            const SizedBox(height: 20),

            // ── Hero banner : profil WhatsApp ──────────────────────────────
            _HeroBanner(
              connected: connected,
              name: name,
              phone: phone,
              picUrl: picUrl,
              uptime: _fmtUptime(uptime),
              nodeVer: nodeVer,
              pulse: _pulseCtrl,
            ),
            const SizedBox(height: 20),

            // ── Section : Vue d'ensemble ──────────────────────────────────
            _SectionLabel(label: 'Vue d\'ensemble', trailing: '7 derniers jours'),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: _BigStat(
                icon: Icons.chat_bubble_rounded,
                label: 'Messages', value: _fmtNum(msgs),
                color: _g, growth: msgGrowth, sub: 'reçus',
              )),
              const SizedBox(width: 10),
              Expanded(child: _BigStat(
                icon: Icons.terminal_rounded,
                label: 'Commandes', value: _fmtNum(cmds),
                color: _purple, growth: cmdGrowth, sub: 'exécutées',
              )),
            ]),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: _SmallStat(
                icon: Icons.groups_rounded, label: 'Groupes',
                value: _fmtNum(groups), color: _teal)),
              const SizedBox(width: 10),
              Expanded(child: _SmallStat(
                icon: Icons.people_rounded, label: 'Utilisateurs',
                value: _fmtNum(users), color: _orange)),
              const SizedBox(width: 10),
              Expanded(child: _SmallStat(
                icon: Icons.phone_android_rounded, label: 'Sessions',
                value: connected ? '1' : '0', color: _blue)),
            ]),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: _SmallStat(
                icon: Icons.timer_rounded, label: 'Uptime',
                value: _fmtUptime(uptime), color: _teal)),
              const SizedBox(width: 10),
              Expanded(child: _SmallStat(
                icon: Icons.memory_rounded, label: 'RAM Bot',
                value: ram > 0 ? '${ram}MB' : '--', color: _blue)),
              const SizedBox(width: 10),
              Expanded(child: _SmallStat(
                icon: Icons.code_rounded, label: 'Node.js',
                value: nodeVer.isNotEmpty ? nodeVer.replaceAll('v', '') : '--',
                color: _purple)),
            ]),
            const SizedBox(height: 20),

            // ── Ressources Bot (Node.js) ──────────────────────────────────
            _SectionLabel(label: 'Ressources Bot (Node.js)'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(children: [
                _ResourceRow(icon: Icons.timer_rounded, label: 'Uptime',
                    value: _fmtUptime(uptime), color: _teal),
                const SizedBox(height: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.memory_rounded, size: 15, color: _muted),
                    const SizedBox(width: 6),
                    const Text('Heap RAM', style: TextStyle(color: _muted, fontSize: 12)),
                    const Spacer(),
                    Text(ram > 0 ? '$ram MB / $ramTotal MB' : '--',
                        style: const TextStyle(color: _ink, fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ramPct,
                      backgroundColor: _border,
                      valueColor: AlwaysStoppedAnimation(
                          ramPct > 0.8 ? _red : ramPct > 0.6 ? _orange : _blue),
                      minHeight: 7,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                _ResourceRow(icon: Icons.verified_rounded, label: 'Version',
                    value: 'v2.0 — Stable', color: _g),
                if (nodeVer.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _ResourceRow(icon: Icons.code_rounded, label: 'Node.js',
                      value: nodeVer, color: _purple),
                ],
              ]),
            ),
            const SizedBox(height: 20),

            // ── Ressources Téléphone ─────────────────────────────────────
            _SectionLabel(label: 'Ressources Téléphone'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(children: [

                // RAM téléphone
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _g.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.memory_rounded, size: 14, color: _g),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('RAM Téléphone',
                          style: TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        devRamTotal > 0
                            ? '${_fmtMb(devRamUsed)} utilisés / ${_fmtMb(devRamTotal)} total'
                            : 'Chargement…',
                        style: const TextStyle(color: _ink, fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    ])),
                    if (devRamTotal > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (devRamPct > 0.8 ? _red : devRamPct > 0.6 ? _orange : _g)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${(devRamPct * 100).round()}%',
                            style: TextStyle(
                              color: devRamPct > 0.8 ? _red : devRamPct > 0.6 ? _orange : _g,
                              fontSize: 11, fontWeight: FontWeight.w800,
                            )),
                      ),
                  ]),
                  if (devRamTotal > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: devRamPct,
                        backgroundColor: _border,
                        valueColor: AlwaysStoppedAnimation(
                            devRamPct > 0.8 ? _red : devRamPct > 0.6 ? _orange : _g),
                        minHeight: 7,
                      ),
                    ),
                  ],
                ]),

                const SizedBox(height: 16),
                Container(height: 1, color: _border),
                const SizedBox(height: 16),

                // CPU
                Row(children: [
                  Expanded(child: _DevBox(
                    icon: Icons.developer_board_rounded,
                    label: 'Processeur',
                    value: cpuName.isNotEmpty
                        ? cpuName.length > 20
                            ? '${cpuName.substring(0, 20)}…'
                            : cpuName
                        : '—',
                    color: _blue,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _DevBox(
                    icon: Icons.grid_view_rounded,
                    label: 'Cœurs CPU',
                    value: cpuCores > 0 ? '$cpuCores cœurs' : '—',
                    color: _blue,
                  )),
                ]),
                const SizedBox(height: 10),

                Row(children: [
                  Expanded(child: _DevBox(
                    icon: Icons.speed_rounded,
                    label: 'Freq. Max',
                    value: cpuFreq > 0 ? '${cpuFreq} MHz' : '—',
                    color: _orange,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _DevBox(
                    icon: Icons.storage_rounded,
                    label: 'Stockage',
                    value: storTotal != '--' ? '$storUsed / $storTotal GB' : '—',
                    color: _purple,
                  )),
                ]),

                if (storTotal != '--') ...[
                  const SizedBox(height: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.storage_rounded, size: 13, color: _muted),
                      const SizedBox(width: 6),
                      const Text('Stockage interne',
                          style: TextStyle(color: _muted, fontSize: 11)),
                      const Spacer(),
                      Text('${(storPct * 100).round()}% utilisé',
                          style: const TextStyle(color: _ink, fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: storPct,
                        backgroundColor: _border,
                        valueColor: AlwaysStoppedAnimation(
                            storPct > 0.9 ? _red : storPct > 0.7 ? _orange : _purple),
                        minHeight: 6,
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 20),

            // ── Top commandes ─────────────────────────────────────────────
            if (topCmds.isNotEmpty) ...[
              _SectionLabel(label: 'Top Commandes', trailing: '5 premières'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: topCmds.take(5).toList().asMap().entries.map((e) {
                    final cmd   = e.value['command'] as String? ?? '';
                    final count = e.value['count'] as int? ?? 0;
                    final pct   = count / maxCount;
                    const colors = [_g, _blue, _purple, _orange, _red];
                    final color  = colors[e.key % colors.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: color.withOpacity(.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text('${e.key + 1}',
                                style: TextStyle(color: color, fontSize: 9,
                                    fontWeight: FontWeight.w900))),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(cmd,
                              style: TextStyle(fontSize: 13, color: color,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace'))),
                          Text(_fmtNum(count),
                              style: const TextStyle(fontSize: 12, color: _ink,
                                  fontWeight: FontWeight.w800)),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const SizedBox(width: 28),
                          Expanded(child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              backgroundColor: color.withOpacity(.08),
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 5,
                            ),
                          )),
                        ]),
                      ]),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Actions rapides ───────────────────────────────────────────
            _SectionLabel(label: 'Actions rapides'),
            const SizedBox(height: 10),
            _QuickAction(
              icon: Icons.qr_code_2_rounded,
              title: connected ? 'Bot déjà connecté' : 'Scanner un QR code',
              desc:  connected ? 'Compte lié • +$phone' : 'Lier un compte WhatsApp',
              color: _g, disabled: connected,
            ),
            const SizedBox(height: 8),
            _QuickAction(
              icon: Icons.bar_chart_rounded,
              title: 'Analytics',
              desc:  'Performance et statistiques détaillées',
              color: _purple,
            ),
            const SizedBox(height: 8),
            _QuickAction(
              icon: Icons.receipt_long_rounded,
              title: 'Logs d\'activité',
              desc:  'Historique des messages et commandes',
              color: _blue,
            ),

            if (!connected && !_loading) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _red.withOpacity(.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _red.withOpacity(.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, color: _red, size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text(
                    'Le bot est hors ligne. Envoie .ping sur WhatsApp ou redémarre le serveur Node.js.',
                    style: TextStyle(color: _red, fontSize: 12),
                  )),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtMb(int mb) {
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '$mb MB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Banner Card
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final bool connected;
  final String name, phone, picUrl, uptime, nodeVer;
  final AnimationController pulse;

  const _HeroBanner({
    required this.connected, required this.name, required this.phone,
    required this.picUrl, required this.uptime, required this.nodeVer,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final accent = connected ? _g : _red;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: connected
              ? [const Color(0xFF0A1E12), const Color(0xFF081408)]
              : [const Color(0xFF1C0D0D), const Color(0xFF120A0A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.3), width: 1.2),
        boxShadow: [BoxShadow(
          color: accent.withOpacity(0.1),
          blurRadius: 20, offset: const Offset(0, 6),
        )],
      ),
      child: Column(children: [
        // ── Bannière ───────────────────────────────────────────────────
        Container(
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: connected
                  ? [_gd.withOpacity(0.35), _g.withOpacity(0.15)]
                  : [_red.withOpacity(0.25), Colors.transparent],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
          ),
          child: Stack(children: [
            // Déco cercles
            Positioned(right: -20, top: -20,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.06),
                ))),
            Positioned(right: 40, top: -10,
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.04),
                ))),
            // Label Wabot
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.auto_awesome_rounded, color: accent.withOpacity(0.6), size: 14),
                const SizedBox(width: 6),
                Text('WABOT DASHBOARD',
                    style: TextStyle(
                      color: accent.withOpacity(0.8),
                      fontSize: 10, fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    )),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedBuilder(
                      animation: pulse,
                      builder: (_, __) => Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: accent, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: accent.withOpacity(0.4 + 0.4 * pulse.value),
                            blurRadius: 4,
                          )],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(connected ? 'EN LIGNE' : 'HORS LIGNE',
                        style: TextStyle(color: accent, fontSize: 9,
                            fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),

        // ── Profil row ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Transform.translate(
            offset: const Offset(0, -24),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // Photo de profil WhatsApp
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: connected ? [_g, _gd] : [_red, const Color(0xFFCC3333)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: const Color(0xFF0A1E12), width: 3),
                  boxShadow: [BoxShadow(
                    color: accent.withOpacity(0.3),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )],
                ),
                child: picUrl.isNotEmpty
                    ? ClipOval(child: Image.network(picUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatarIcon(connected)))
                    : _avatarIcon(connected),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),
                  Text(name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                          color: _ink, letterSpacing: -0.3),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  if (phone.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.phone_rounded, size: 12, color: _muted),
                      const SizedBox(width: 4),
                      Text('+$phone',
                          style: const TextStyle(color: _muted, fontSize: 12.5,
                              fontFamily: 'monospace')),
                    ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _Tag('⬆ $uptime', _teal),
                    if (nodeVer.isNotEmpty) _Tag('Node $nodeVer', _purple),
                    _Tag(connected ? '● WhatsApp' : '○ Déconnecté', accent),
                  ]),
                ],
              )),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _avatarIcon(bool conn) => Center(child: Icon(
      conn ? Icons.smart_toy_rounded : Icons.wifi_off_rounded,
      color: Colors.white, size: 32));
}

Widget _Tag(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: color.withOpacity(0.12),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: color.withOpacity(0.25)),
  ),
  child: Text(label, style: TextStyle(fontSize: 10, color: color,
      fontWeight: FontWeight.w700)),
);

// ─────────────────────────────────────────────────────────────────────────────
// Widgets partagés
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? trailing;
  const _SectionLabel({required this.label, this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800,
        color: _muted, letterSpacing: 0.6)),
    const Spacer(),
    if (trailing != null)
      Text(trailing!, style: const TextStyle(fontSize: 10, color: _muted)),
  ]);
}

class _ResourceRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _ResourceRow({required this.icon, required this.label,
      required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 28, height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, size: 14, color: color)),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
    const Spacer(),
    Text(value, style: const TextStyle(color: _ink, fontSize: 12,
        fontWeight: FontWeight.w700)),
  ]);
}

class _DevBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _DevBox({required this.icon, required this.label,
      required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
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
        Text(label, style: const TextStyle(fontSize: 9, color: _muted,
            letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, color: color,
            fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

class _BigStat extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  final double growth;
  const _BigStat({required this.icon, required this.label, required this.value,
      required this.color, required this.growth, required this.sub});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(.2)),
      gradient: LinearGradient(
        colors: [_card, color.withOpacity(.04)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const Spacer(),
        if (growth != 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: (growth > 0 ? _g : _red).withOpacity(.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(growth > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 10, color: growth > 0 ? _g : _red),
              const SizedBox(width: 3),
              Text('${growth.abs().toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 9, color: growth > 0 ? _g : _red,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
      ]),
      const SizedBox(height: 12),
      Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
          color: color, letterSpacing: -0.5)),
      const SizedBox(height: 4),
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: _ink)),
        const SizedBox(width: 6),
        Text(sub, style: const TextStyle(fontSize: 10, color: _muted)),
      ]),
    ]),
  );
}

class _SmallStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _SmallStat({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
          color: color), overflow: TextOverflow.ellipsis),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontSize: 10, color: _muted,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  final Color color;
  final bool disabled;
  const _QuickAction({required this.icon, required this.title, required this.desc,
      required this.color, this.disabled = false});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: disabled ? 0.5 : 1.0,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: disabled ? _border : color.withOpacity(.2)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13.5, color: _ink,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(fontSize: 11.5, color: _muted)),
        ])),
        Icon(Icons.chevron_right_rounded, color: _muted.withOpacity(.5), size: 18),
      ]),
    ),
  );
}
