import 'dart:io' show File, Process;
import 'dart:convert' show LineSplitter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg    = Color(0xFF060709);
const _card  = Color(0xFF0C0F14);
const _card2 = Color(0xFF111620);
const _brdr  = Color(0xFF181E2C);
const _g     = Color(0xFF25D366);
const _gd    = Color(0xFF1AAD4B);
const _b     = Color(0xFF4A9EFF);
const _p     = Color(0xFF7C6FF7);
const _o     = Color(0xFFFF9D4A);
const _r     = Color(0xFFFF5B5B);
const _t     = Color(0xFF20D9C0);
const _ink   = Color(0xFFF2F3F5);
const _sub   = Color(0xFF8A94A8);
const _muted = Color(0xFF3D4455);

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

  Future<void> _loadDevice() async {
    if (kIsWeb) return;
    try {
      await Future.wait([_loadRam(), _loadCpu(), _loadStorage()]);
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
      int freqKhz = 0;
      try {
        final f = _readFileSync(
            '/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq').trim();
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

  String _fmtMb(int mb) {
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '$mb MB';
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [

            // ── Header ──────────────────────────────────────────────────────
            _DashHeader(loading: _loading,
                onRefresh: () async { await _load(); await _loadDevice(); })
                .animate().fadeIn(duration: 200.ms),

            const SizedBox(height: 16),

            // ── Hero ────────────────────────────────────────────────────────
            _HeroBanner(
              connected: connected, name: name, phone: phone,
              picUrl: picUrl, uptime: _fmtUptime(uptime),
              ram: ram > 0 ? '${ram} MB' : '--',
              node: nodeVer, pulse: _pulseCtrl,
            ).animate().fadeIn(duration: 300.ms, delay: 40.ms)
                .slideY(begin: 0.03, curve: Curves.easeOut),

            const SizedBox(height: 14),

            // ── Stats 2×2 ────────────────────────────────────────────────────
            Row(children: [
              Expanded(child: _StatCard(icon: Icons.chat_bubble_rounded,
                  label: 'Messages', value: _fmtNum(msgs),
                  color: _g, growth: msgGrowth)
                  .animate().fadeIn(duration: 300.ms, delay: 80.ms)
                  .slideY(begin: 0.04)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(icon: Icons.terminal_rounded,
                  label: 'Commandes', value: _fmtNum(cmds),
                  color: _p, growth: cmdGrowth)
                  .animate().fadeIn(duration: 300.ms, delay: 110.ms)
                  .slideY(begin: 0.04)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _StatCard(icon: Icons.groups_rounded,
                  label: 'Groupes', value: _fmtNum(groups), color: _t)
                  .animate().fadeIn(duration: 300.ms, delay: 140.ms)
                  .slideY(begin: 0.04)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(icon: Icons.people_rounded,
                  label: 'Utilisateurs', value: _fmtNum(users), color: _o)
                  .animate().fadeIn(duration: 300.ms, delay: 170.ms)
                  .slideY(begin: 0.04)),
            ]),

            const SizedBox(height: 22),

            // ── Ressources Bot ───────────────────────────────────────────────
            _SecLabel(label: 'Ressources Bot')
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 10),
            _BotResCard(
              uptime: _fmtUptime(uptime), ram: ram,
              ramTotal: ramTotal, ramPct: ramPct.toDouble(),
              nodeVer: nodeVer,
            ).animate().fadeIn(duration: 300.ms, delay: 220.ms),

            const SizedBox(height: 22),

            // ── Ressources Téléphone ─────────────────────────────────────────
            _SecLabel(label: 'Ressources Téléphone')
                .animate().fadeIn(delay: 240.ms),
            const SizedBox(height: 10),
            _PhoneResCard(
              ramUsed: devRamUsed, ramTotal: devRamTotal,
              ramPct: devRamPct.toDouble(), cpuName: cpuName,
              cpuCores: cpuCores, cpuFreq: cpuFreq,
              storTotal: storTotal, storUsed: storUsed,
              storPct: storPct.toDouble(), fmtMb: _fmtMb,
            ).animate().fadeIn(duration: 300.ms, delay: 260.ms),

            // ── Top Commandes ────────────────────────────────────────────────
            if (topCmds.isNotEmpty) ...[
              const SizedBox(height: 22),
              _SecLabel(label: 'Top Commandes', trailing: '7 jours')
                  .animate().fadeIn(delay: 280.ms),
              const SizedBox(height: 10),
              _TopCmdsCard(commands: topCmds.take(5).toList(), maxCount: maxCount)
                  .animate().fadeIn(duration: 300.ms, delay: 300.ms),
            ],

          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Header ─────────────────────────────────────────────────────────
class _DashHeader extends StatelessWidget {
  final bool loading;
  final AsyncCallback onRefresh;
  const _DashHeader({required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Text('Dashboard', style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900,
          color: _ink, letterSpacing: -0.8)),
      const Spacer(),
      if (loading)
        const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _g))
      else
        _RoundBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
    ],
  );
}

// ─── Round icon button ────────────────────────────────────────────────────────
class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _brdr),
      ),
      child: Icon(icon, color: _sub, size: 17),
    ),
  );
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SecLabel extends StatelessWidget {
  final String label;
  final String? trailing;
  const _SecLabel({required this.label, this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: _sub, letterSpacing: 0.5)),
    if (trailing != null) ...[
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: _g.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(trailing!, style: const TextStyle(
            color: _g, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    ],
  ]);
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final bool connected;
  final String name, phone, picUrl, uptime, ram, node;
  final AnimationController pulse;

  const _HeroBanner({
    required this.connected, required this.name, required this.phone,
    required this.picUrl, required this.uptime, required this.ram,
    required this.node, required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final ac = connected ? _g : _r;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: connected
              ? [const Color(0xFF081410), const Color(0xFF050C08), _bg]
              : [const Color(0xFF14080A), const Color(0xFF0D0507), _bg],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ac.withOpacity(0.22), width: 1.2),
        boxShadow: [
          BoxShadow(color: ac.withOpacity(0.08), blurRadius: 28, spreadRadius: -4),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

        // Avatar with animated glow ring
        SizedBox(width: 72, height: 72, child: Stack(children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: ac.withOpacity(0.18 + 0.18 * pulse.value),
                  blurRadius: 14 + 10 * pulse.value,
                  spreadRadius: 2,
                )],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [ac, ac.withOpacity(0.3), ac],
              ),
            ),
            padding: const EdgeInsets.all(2.5),
            child: Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: _card),
              child: ClipOval(
                child: picUrl.isNotEmpty
                    ? Image.network(picUrl, fit: BoxFit.cover, width: 67, height: 67,
                        errorBuilder: (_, __, ___) => _AvatarFallback(color: ac))
                    : _AvatarFallback(color: ac),
              ),
            ),
          ),
          Positioned(
            bottom: 2, right: 2,
            child: AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: ac, shape: BoxShape.circle,
                  border: Border.all(color: _card, width: 2.5),
                  boxShadow: [BoxShadow(
                    color: ac.withOpacity(0.65 * pulse.value), blurRadius: 8)],
                ),
              ),
            ),
          ),
        ])),

        const SizedBox(width: 16),

        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(name, style: const TextStyle(
              fontSize: 19, fontWeight: FontWeight.w800,
              color: _ink, letterSpacing: -0.3),
              overflow: TextOverflow.ellipsis, maxLines: 1),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text('+$phone', style: const TextStyle(
                color: _sub, fontSize: 12, fontFamily: 'monospace')),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _Pill(icon: Icons.circle, text: connected ? 'EN LIGNE' : 'HORS LIGNE',
                color: ac, filled: true),
            if (uptime != '--') _Pill(icon: Icons.timer_outlined, text: uptime, color: _b),
            if (node.isNotEmpty) _Pill(icon: Icons.code_rounded, text: node, color: _p),
          ]),
        ])),
      ]),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final Color color;
  const _AvatarFallback({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 67, height: 67,
    color: color.withOpacity(0.1),
    child: Icon(Icons.smart_toy_rounded, color: color, size: 30),
  );
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool filled;
  const _Pill({required this.icon, required this.text, required this.color,
      this.filled = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(filled ? 0.14 : 0.08),
      borderRadius: BorderRadius.circular(20),
      border: filled ? Border.all(color: color.withOpacity(0.35)) : null,
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (filled) ...[
        Container(width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
      ] else ...[
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
      ],
      Text(text, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w800, letterSpacing: 0.3)),
    ]),
  );
}

// ─── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final double growth;

  const _StatCard({
    required this.icon, required this.label, required this.value,
    required this.color, this.growth = 0,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_card2, _card],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _brdr),
      boxShadow: [
        BoxShadow(color: color.withOpacity(0.06), blurRadius: 20, spreadRadius: -4),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const Spacer(),
        if (growth != 0) _GrowthBadge(value: growth),
      ]),
      const SizedBox(height: 14),
      Text(value, style: const TextStyle(
          fontSize: 28, fontWeight: FontWeight.w900,
          color: _ink, letterSpacing: -1.0)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(
          fontSize: 11, color: _sub, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _GrowthBadge extends StatelessWidget {
  final double value;
  const _GrowthBadge({required this.value});
  @override
  Widget build(BuildContext context) {
    final pos = value >= 0;
    final col = pos ? _g : _r;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: col.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(pos ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 10, color: col),
        const SizedBox(width: 3),
        Text('${value.abs().toStringAsFixed(0)}%',
            style: TextStyle(color: col, fontSize: 9.5, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ─── Gradient progress bar ────────────────────────────────────────────────────
class _GBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const _GBar({required this.value, required this.color, this.height = 7});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => LinearProgressIndicator(
        value: v,
        backgroundColor: _brdr,
        valueColor: AlwaysStoppedAnimation(color),
        minHeight: height,
      ),
    ),
  );
}

// ─── Bot resources card ───────────────────────────────────────────────────────
class _BotResCard extends StatelessWidget {
  final String uptime, nodeVer;
  final int ram, ramTotal;
  final double ramPct;

  const _BotResCard({required this.uptime, required this.ram,
      required this.ramTotal, required this.ramPct, required this.nodeVer});

  @override
  Widget build(BuildContext context) {
    final barCol = ramPct > 0.8 ? _r : ramPct > 0.6 ? _o : _b;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brdr),
      ),
      child: Column(children: [
        Row(children: [
          _ResChip(icon: Icons.timer_outlined, label: 'Uptime', value: uptime, color: _t),
          const SizedBox(width: 10),
          if (nodeVer.isNotEmpty)
            _ResChip(icon: Icons.code_rounded, label: 'Node.js', value: nodeVer, color: _p)
          else
            _ResChip(icon: Icons.verified_rounded, label: 'Version', value: 'v2.0', color: _g),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: barCol.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.memory_rounded, size: 15, color: barCol),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Text('Heap RAM', style: TextStyle(
                  color: _sub, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(ram > 0 ? '$ram / $ramTotal MB' : '--',
                  style: TextStyle(color: barCol, fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 7),
            _GBar(value: ramPct, color: barCol),
          ])),
        ]),
      ]),
    );
  }
}

class _ResChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _ResChip({required this.icon, required this.label,
      required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 7),
        Text(value, style: TextStyle(
            color: color, fontSize: 15, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color.withOpacity(0.6),
            fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ─── Phone resources card ─────────────────────────────────────────────────────
class _PhoneResCard extends StatelessWidget {
  final int ramUsed, ramTotal, cpuCores, cpuFreq;
  final double ramPct, storPct;
  final String cpuName, storTotal, storUsed;
  final String Function(int) fmtMb;

  const _PhoneResCard({
    required this.ramUsed, required this.ramTotal, required this.ramPct,
    required this.cpuName, required this.cpuCores, required this.cpuFreq,
    required this.storTotal, required this.storUsed, required this.storPct,
    required this.fmtMb,
  });

  @override
  Widget build(BuildContext context) {
    final ramCol  = ramPct > 0.8 ? _r : ramPct > 0.6 ? _o : _g;
    final storCol = storPct > 0.9 ? _r : storPct > 0.7 ? _o : _p;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brdr),
      ),
      child: Column(children: [
        _ProgRow(icon: Icons.memory_rounded, label: 'RAM Téléphone',
            value: ramTotal > 0
                ? '${fmtMb(ramUsed)} / ${fmtMb(ramTotal)}' : '…',
            pct: ramPct, color: ramCol),
        const SizedBox(height: 16),
        Divider(height: 1, color: _brdr),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _InfoBox(icon: Icons.developer_board_rounded,
              label: 'Processeur',
              value: cpuName.isEmpty ? '—'
                  : (cpuName.length > 18 ? '${cpuName.substring(0, 18)}…' : cpuName),
              color: _b)),
          const SizedBox(width: 10),
          Expanded(child: _InfoBox(icon: Icons.grid_view_rounded,
              label: 'Cœurs CPU',
              value: cpuCores > 0 ? '$cpuCores cores' : '—',
              color: _b)),
        ]),
        if (storTotal != '--') ...[
          const SizedBox(height: 16),
          Divider(height: 1, color: _brdr),
          const SizedBox(height: 16),
          _ProgRow(icon: Icons.storage_rounded, label: 'Stockage',
              value: '$storUsed / $storTotal GB',
              pct: storPct, color: storCol),
        ],
      ]),
    );
  }
}

class _ProgRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final double pct;
  final Color color;
  const _ProgRow({required this.icon, required this.label, required this.value,
      required this.pct, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(label, style: const TextStyle(
            color: _sub, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(
            color: _ink, fontSize: 13, fontWeight: FontWeight.w700)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('${(pct * 100).round()}%',
            style: TextStyle(color: color, fontSize: 11,
                fontWeight: FontWeight.w800)),
      ),
    ]),
    const SizedBox(height: 9),
    _GBar(value: pct, color: color),
  ]);
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoBox({required this.icon, required this.label,
      required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.14)),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(value, style: const TextStyle(
            color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
      ])),
    ]),
  );
}

// ─── Top commands card ────────────────────────────────────────────────────────
class _TopCmdsCard extends StatelessWidget {
  final List<Map<String, dynamic>> commands;
  final int maxCount;
  const _TopCmdsCard({required this.commands, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    const colors = [_g, _b, _p, _o, _t];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brdr),
      ),
      child: Column(
        children: commands.asMap().entries.map((e) {
          final cmd   = e.value['command'] as String? ?? '';
          final count = e.value['count']   as int?    ?? 0;
          final pct   = maxCount > 0 ? count / maxCount : 0.0;
          final col   = colors[e.key % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: col.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(child: Text('${e.key + 1}',
                      style: TextStyle(color: col, fontSize: 10,
                          fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('.${cmd}', style: const TextStyle(
                    color: _ink, fontSize: 13, fontWeight: FontWeight.w600,
                    fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: col.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$count', style: TextStyle(
                      color: col, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 7),
              _GBar(value: pct.toDouble(), color: col, height: 5),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

