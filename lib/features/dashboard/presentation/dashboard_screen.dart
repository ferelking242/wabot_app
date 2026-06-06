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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _botStatus;
  Map<String, dynamic>? _analytics;
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
      final results = await Future.wait([
        api.getBotStatus(),
        api.getAnalytics(period: '7d'),
      ]);
      if (mounted) setState(() {
        _botStatus  = results[0];
        _analytics  = results[1];
        _loading    = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d         = _botStatus ?? {};
    final an        = _analytics ?? {};
    final connected = d['status'] == 'online';
    final phone     = (d['phoneNumber'] as String? ?? '').replaceAll('@s.whatsapp.net', '');
    final uptime    = d['uptime'] as int? ?? 0;
    final uptimeStr = uptime > 0
        ? '${(uptime ~/ 3600)}h ${((uptime % 3600) ~/ 60)}m'
        : '--';
    final ram       = d['ramUsage'] as int? ?? 0;
    final ramTotal  = d['ramTotal'] as int? ?? 512;
    final groups    = an['totalGroups'] as int? ?? (d['groupsCount'] as int? ?? 0);
    final msgs      = an['totalMessages'] as int? ?? (d['messagesTotal'] as int? ?? 0);
    final cmds      = an['totalCommands'] as int? ?? 0;
    final users     = an['totalUsers'] as int? ?? 0;
    final msgGrowth = (an['messagesGrowth'] as num?)?.toStringAsFixed(1) ?? '0';
    final cmdGrowth = (an['commandsGrowth'] as num?)?.toStringAsFixed(1) ?? '0';

    String _fmtNum(int n) {
      if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
      if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}k';
      return n.toString();
    }

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _g,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            // Header
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 4),
                Text('État du bot Wabot', style: TextStyle(color: _muted, fontSize: 13)),
              ])),
              if (_loading)
                const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: _g, strokeWidth: 2))
              else
                GestureDetector(
                  onTap: _load,
                  child: const Icon(Icons.refresh_rounded, color: _muted, size: 20)),
            ]),
            const SizedBox(height: 20),

            // Status card — connexion
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: connected
                  ? LinearGradient(colors: [_g.withOpacity(.12), _gd.withOpacity(.08)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
                color: connected ? null : _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: connected ? _g.withOpacity(.35) : _border),
              ),
              child: Row(children: [
                Container(width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: connected ? _g.withOpacity(.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(14)),
                  child: Icon(
                    connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: connected ? _g : _muted, size: 24)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(connected ? 'Bot connecté ✅' : 'Bot déconnecté',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: connected ? _g : _ink)),
                  const SizedBox(height: 3),
                  Text(
                    connected && phone.isNotEmpty ? '📱 +$phone' : 'Aucun compte lié',
                    style: const TextStyle(color: _muted, fontSize: 12)),
                ])),
                if (connected) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _g.withOpacity(.15), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(
                      color: _g, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _g.withOpacity(.5), blurRadius: 6)])),
                    const SizedBox(width: 5),
                    const Text('En ligne', style: TextStyle(color: _g, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Stats grid — 4 cards
            const Text('Vue d\'ensemble', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [
                _Stat(icon: Icons.groups_rounded, label: 'Groupes', value: _fmtNum(groups), color: const Color(0xFF4ECDC4), sub: null),
                _Stat(icon: Icons.chat_bubble_rounded, label: 'Messages (7j)', value: _fmtNum(msgs), color: _g, sub: '+$msgGrowth%'),
                _Stat(icon: Icons.terminal_rounded, label: 'Commandes (7j)', value: _fmtNum(cmds), color: const Color(0xFF9B59B6), sub: '+$cmdGrowth%'),
                _Stat(icon: Icons.people_rounded, label: 'Utilisateurs', value: _fmtNum(users), color: const Color(0xFFE67E22), sub: null),
              ],
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [
                _Stat(icon: Icons.timer_rounded, label: 'Uptime', value: uptimeStr, color: const Color(0xFF3498DB), sub: null),
                _Stat(icon: Icons.memory_rounded, label: 'RAM', value: ram > 0 ? '${ram}MB' : '--', color: const Color(0xFFE74C3C), sub: ramTotal > 0 ? '/${ramTotal}MB' : null),
                _Stat(icon: Icons.phone_android_rounded, label: 'Sessions', value: connected ? '1' : '0', color: const Color(0xFF1ABC9C), sub: connected ? 'Active' : 'Inactive'),
                _Stat(icon: Icons.verified_rounded, label: 'Version', value: 'v2.0', color: const Color(0xFFF39C12), sub: 'Stable'),
              ],
            ),
            const SizedBox(height: 20),

            // Top commands section
            if (_analytics != null) ...[
              const Text('Top Commandes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              ...((_analytics!['topCommands'] as List? ?? []).cast<Map<String, dynamic>>().take(5).toList().asMap().entries.map((e) {
                final cmd   = e.value['command'] as String? ?? '';
                final count = e.value['count'] as int? ?? 0;
                final max   = ((_analytics!['topCommands'] as List? ?? []).isNotEmpty
                  ? ((_analytics!['topCommands'] as List).first['count'] as int? ?? 1)
                  : 1);
                final pct = count / max;
                final colors = [_g, const Color(0xFF3498DB), const Color(0xFF9B59B6), const Color(0xFFE67E22), const Color(0xFFE74C3C)];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                    child: Row(children: [
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(color: colors[e.key % colors.length].withOpacity(.15), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text('${e.key + 1}', style: TextStyle(color: colors[e.key % colors.length], fontWeight: FontWeight.w800, fontSize: 12))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(cmd, style: TextStyle(color: colors[e.key % colors.length], fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            backgroundColor: _border,
                            valueColor: AlwaysStoppedAnimation(colors[e.key % colors.length]),
                            minHeight: 5,
                          ),
                        ),
                      ])),
                      const SizedBox(width: 10),
                      Text('$count', style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                );
              })),
              const SizedBox(height: 10),
            ],

            // Quick actions
            const Text('Actions rapides', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            _Action(
              icon: Icons.qr_code_rounded,
              title: 'Scanner un QR',
              desc: connected ? 'Bot déjà connecté' : 'Lier un compte WhatsApp',
              disabled: connected,
              color: _g,
            ),
            const SizedBox(height: 8),
            _Action(
              icon: Icons.receipt_long_rounded,
              title: 'Voir les logs',
              desc: 'Historique des messages et commandes',
              color: const Color(0xFF3498DB),
            ),
            const SizedBox(height: 8),
            _Action(
              icon: Icons.bar_chart_rounded,
              title: 'Analytics',
              desc: 'Performance et statistiques du bot',
              color: const Color(0xFF9B59B6),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? sub;
  const _Stat({required this.icon, required this.label, required this.value, required this.color, required this.sub});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(.25)),
      gradient: LinearGradient(
        colors: [_card, color.withOpacity(.05)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ink)),
            if (sub != null) ...[
              const SizedBox(width: 4),
              Text(sub!, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
            ],
          ]),
          Text(label, style: const TextStyle(fontSize: 10.5, color: _muted, fontWeight: FontWeight.w500)),
        ]),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool disabled;
  final Color color;
  const _Action({required this.icon, required this.title, required this.desc, this.disabled = false, required this.color});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: disabled ? 0.45 : 1.0,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: color)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _ink)),
          Text(desc, style: const TextStyle(fontSize: 12, color: _muted)),
        ])),
        Icon(Icons.chevron_right_rounded, color: color.withOpacity(.5), size: 20),
      ]),
    ),
  );
}
