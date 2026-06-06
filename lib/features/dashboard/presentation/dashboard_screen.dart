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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _botStatus;
  Map<String, dynamic>? _analytics;
  bool _loading = true;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _load();
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
    final ramTotal  = d['ramTotal'] as int? ?? 512;
    final ramPct    = ramTotal > 0 ? (ram / ramTotal).clamp(0.0, 1.0) : 0.0;
    final groups    = an['totalGroups']   as int? ?? (d['groupsCount']   as int? ?? 0);
    final msgs      = an['totalMessages'] as int? ?? (d['messagesTotal'] as int? ?? 0);
    final cmds      = an['totalCommands'] as int? ?? 0;
    final users     = an['totalUsers']    as int? ?? 0;
    final msgGrowth = (an['messagesGrowth'] as num?)?.toDouble() ?? 0.0;
    final cmdGrowth = (an['commandsGrowth'] as num?)?.toDouble() ?? 0.0;
    final topCmds   = (an['topCommands'] as List? ?? []).cast<Map<String, dynamic>>();
    final maxCount  = topCmds.isNotEmpty ? (topCmds.first['count'] as int? ?? 1) : 1;

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _g,
        backgroundColor: _card,
        onRefresh: _load,
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
                  onTap: _load,
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

            // ── Hero card : statut connexion ─────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: connected
                      ? [const Color(0xFF0E2018), const Color(0xFF091A10)]
                      : [const Color(0xFF1A1010), const Color(0xFF110D0D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: connected ? _g.withOpacity(.25) : _red.withOpacity(.2)),
              ),
              child: Stack(children: [
                // Blob décoratif
                Positioned(
                  right: -20, top: -20,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (connected ? _g : _red).withOpacity(.05),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    // Avatar
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: connected ? [_g, _gd] : [_red, const Color(0xFFCC3333)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                          color: (connected ? _g : _red).withOpacity(.25),
                          blurRadius: 12, offset: const Offset(0, 4),
                        )],
                      ),
                      child: Center(child: Icon(
                        connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        color: Colors.white, size: 26,
                      )),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(connected ? name : 'Déconnecté',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
                      const SizedBox(height: 4),
                      Text(
                        connected && phone.isNotEmpty ? '+$phone' : 'Aucun compte lié',
                        style: const TextStyle(color: _muted, fontSize: 12.5)),
                      const SizedBox(height: 8),
                      if (connected) Row(children: [
                        _MiniTag(label: '⬆ ${_fmtUptime(uptime)}', color: _teal),
                        const SizedBox(width: 6),
                        _MiniTag(label: '🖥 ${ram}MB RAM', color: _blue),
                      ]),
                    ])),
                    if (connected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _g.withOpacity(.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: _g.withOpacity(.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (_, __) => Container(
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                color: _g, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(
                                  color: _g.withOpacity(0.4 + 0.4 * _pulseCtrl.value),
                                  blurRadius: 4 + 4 * _pulseCtrl.value,
                                )],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('En ligne', style: TextStyle(
                              color: _g, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ]),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _red.withOpacity(.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: _red.withOpacity(.25)),
                        ),
                        child: const Text('Hors ligne', style: TextStyle(
                            color: _red, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Section : Vue d'ensemble ─────────────────────────────────
            _SectionLabel(label: 'Vue d\'ensemble', trailing: '7 derniers jours'),
            const SizedBox(height: 10),

            // Ligne 1 — Messages + Commandes (grandes cards)
            Row(children: [
              Expanded(child: _BigStat(
                icon: Icons.chat_bubble_rounded,
                label: 'Messages', value: _fmtNum(msgs),
                color: _g,
                growth: msgGrowth,
                sub: 'reçus',
              )),
              const SizedBox(width: 10),
              Expanded(child: _BigStat(
                icon: Icons.terminal_rounded,
                label: 'Commandes', value: _fmtNum(cmds),
                color: _purple,
                growth: cmdGrowth,
                sub: 'exécutées',
              )),
            ]),
            const SizedBox(height: 10),

            // Ligne 2 — Groupes + Utilisateurs
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
            const SizedBox(height: 20),

            // ── Section : Ressources serveur ──────────────────────────────
            _SectionLabel(label: 'Ressources serveur'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(children: [
                // Uptime
                _ResourceRow(
                  icon: Icons.timer_rounded,
                  label: 'Uptime',
                  value: _fmtUptime(uptime),
                  color: _teal,
                ),
                const SizedBox(height: 14),
                // RAM barre
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.memory_rounded, size: 15, color: _muted),
                    const SizedBox(width: 6),
                    const Text('RAM', style: TextStyle(color: _muted, fontSize: 12)),
                    const Spacer(),
                    Text(ram > 0 ? '$ram MB / $ramTotal MB' : '--',
                        style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
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
                _ResourceRow(
                  icon: Icons.verified_rounded,
                  label: 'Version',
                  value: 'v2.0 — Stable',
                  color: _g,
                ),
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
                                  fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
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
              color: _g,
              disabled: connected,
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

            // ── Offline banner ────────────────────────────────────────────
            if (!connected && !_loading) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _red.withOpacity(.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _red.withOpacity(.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: _red, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(child: Text(
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? trailing;
  const _SectionLabel({required this.label, this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.6)),
    const Spacer(),
    if (trailing != null)
      Text(trailing!, style: const TextStyle(fontSize: 10, color: _muted)),
  ]);
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(.2)),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}

class _BigStat extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  final double growth;
  const _BigStat({
    required this.icon, required this.label, required this.value,
    required this.color, required this.growth, required this.sub,
  });

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
            child: Text(
              '${growth > 0 ? '+' : ''}${growth.toStringAsFixed(1)}%',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: growth > 0 ? _g : _red),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      Text(value, style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900,
          color: color, letterSpacing: -0.5)),
      const SizedBox(height: 2),
      Text('$label $sub', style: const TextStyle(fontSize: 11, color: _muted)),
    ]),
  );
}

class _SmallStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _SmallStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(.18)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 17, color: color),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w900, color: _ink)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10.5, color: _muted)),
    ]),
  );
}

class _ResourceRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _ResourceRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: _muted),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
    const Spacer(),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Text(value, style: TextStyle(
          color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    ),
  ]);
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  final Color color;
  final bool disabled;
  const _QuickAction({
    required this.icon, required this.title, required this.desc,
    required this.color, this.disabled = false,
  });

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: disabled ? 0.45 : 1.0,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 12, color: _muted)),
        ])),
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.chevron_right_rounded, color: color, size: 18),
        ),
      ]),
    ),
  );
}
