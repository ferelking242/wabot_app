import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../../../services/api_service.dart';

  const _g      = Color(0xFF25D366);
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
        final data = await api.getBotStatus();
        if (mounted) setState(() { _botStatus = data; _loading = false; });
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }

    @override
    Widget build(BuildContext context) {
      final d         = _botStatus ?? {};
      final connected = d['status'] == 'online';
      final phone     = (d['phoneNumber'] as String? ?? '').replaceAll('@s.whatsapp.net', '');
      final uptime    = d['uptime'] as int? ?? 0;
      final uptimeStr = uptime > 0
          ? '${(uptime ~/ 3600)}h ${((uptime % 3600) ~/ 60)}m'
          : '--';
      final ram       = d['ramUsage'] as int? ?? 0;

      return Scaffold(
        backgroundColor: _bg,
        body: RefreshIndicator(
          color: _g,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              // Header
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
                  SizedBox(height: 4),
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

              // Status card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: connected ? _g.withOpacity(.08) : _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: connected ? _g.withOpacity(.3) : _border),
                ),
                child: Row(children: [
                  Container(width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: connected ? _g.withOpacity(.15) : Colors.white10,
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(
                      connected ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked_rounded,
                      color: connected ? _g : _muted, size: 24)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(connected ? 'Bot connecté' : 'Bot déconnecté',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: connected ? _g : _ink)),
                    const SizedBox(height: 3),
                    Text(
                      connected && phone.isNotEmpty ? '+$phone' : 'Aucun compte lié',
                      style: const TextStyle(color: _muted, fontSize: 12)),
                  ])),
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: connected ? _g : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: connected ? [BoxShadow(color: _g.withOpacity(.5), blurRadius: 6)] : [],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Stats grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  _Stat(icon: Icons.timer_outlined, label: 'Uptime', value: uptimeStr),
                  _Stat(icon: Icons.memory_outlined, label: 'RAM', value: ram > 0 ? '${ram} MB' : '--'),
                  _Stat(icon: Icons.phone_android_outlined, label: 'Sessions', value: connected ? '1' : '0'),
                  _Stat(icon: Icons.chat_bubble_outline_rounded, label: 'Messages', value: '0'),
                ],
              ),
              const SizedBox(height: 20),

              // Quick actions
              const Text('Actions rapides',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 12),
              _Action(
                icon: Icons.qr_code_rounded,
                title: 'Scanner un QR',
                desc: connected ? 'Bot déjà connecté' : 'Lier un compte WhatsApp',
                disabled: connected,
              ),
              const SizedBox(height: 8),
              _Action(
                icon: Icons.receipt_long_outlined,
                title: 'Voir les logs',
                desc: 'Historique des messages et commandes',
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
    const _Stat({required this.icon, required this.label, required this.value});

    @override
    Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20, color: _g),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
            Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
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
    const _Action({required this.icon, required this.title, required this.desc, this.disabled = false});

    @override
    Widget build(BuildContext context) => Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border)),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: _g.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: _g)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
            Text(desc, style: const TextStyle(fontSize: 11.5, color: _muted)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
        ]),
      ),
    );
  }
  