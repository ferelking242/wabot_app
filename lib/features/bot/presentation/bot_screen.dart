import 'dart:async';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../../../services/api_service.dart';
  import '../../../shared/widgets/app_shell.dart';

  const _g      = Color(0xFF25D366);
  const _gd     = Color(0xFF128C7E);
  const _ink    = Color(0xFFF2F3F5);
  const _muted  = Color(0xFF8A9199);
  const _border = Color(0xFF1E2128);
  const _card   = Color(0xFF111316);
  const _bg     = Color(0xFF0D0E11);
  const _red    = Color(0xFFFF6B6B);
  const _blue   = Color(0xFF57B6FF);
  const _orange = Color(0xFFE67E22);
  const _purple = Color(0xFF9B59B6);
  const _teal   = Color(0xFF1ABC9C);

  class _Cmd  { final String cmd, desc; const _Cmd(this.cmd, this.desc); }
  class _Group { final String name; final IconData icon; final List<_Cmd> cmds; const _Group(this.name, this.icon, this.cmds); }

  const _kGroups = [
    _Group('Systeme', Icons.settings_outlined, [
      _Cmd('.ping',  'Verifier si le bot est actif'),
      _Cmd('.alive', 'Statut complet (uptime, RAM)'),
      _Cmd('.help',  'Afficher toutes les commandes'),
      _Cmd('.owner', 'Infos du proprietaire'),
    ]),
    _Group('Groupe', Icons.group_outlined, [
      _Cmd('.tagall',         'Mentionner tout le groupe'),
      _Cmd('.groupinfo',      'Infos du groupe'),
      _Cmd('.kick @user',     'Exclure un membre'),
      _Cmd('.promote @user',  'Promouvoir en admin'),
      _Cmd('.demote @user',   'Retrograder un admin'),
      _Cmd('.mute',           'Muter le groupe (admins only)'),
      _Cmd('.unmute',         'Demuter le groupe'),
      _Cmd('.ban @user',      'Bannir un membre'),
      _Cmd('.warn @user',     'Avertir un membre'),
    ]),
    _Group('Divertissement', Icons.emoji_emotions_outlined, [
      _Cmd('.joke',       'Blague aleatoire'),
      _Cmd('.quote',      'Citation inspirante'),
      _Cmd('.fact',       'Fait insolite'),
      _Cmd('.8ball <q>',  'Boule magique'),
      _Cmd('.dare',       'Defi aleatoire'),
      _Cmd('.truth',      'Question verite'),
      _Cmd('.compliment', 'Compliment aleatoire'),
      _Cmd('.insult',     'Insulte amicale (humour)'),
      _Cmd('.coinflip',   'Pile ou face'),
      _Cmd('.trivia',     'Question culture generale'),
      _Cmd('.rps',        'Pierre-Feuille-Ciseaux'),
    ]),
    _Group('Utilitaires', Icons.auto_awesome_outlined, [
      _Cmd('.weather <ville>', 'Meteo en direct (wttr.in, sans API key)'),
      _Cmd('.translate <txt>', 'Traduire un texte en francais'),
      _Cmd('.sticker',         'Repondre a une image pour creer un sticker WA'),
    ]),
    _Group('Admin (owner)', Icons.admin_panel_settings_outlined, [
      _Cmd('.ai <question>',    'Poser une question a l\'IA'),
      _Cmd('.autotyping on/off','Simuler frappe en cours'),
      _Cmd('.autoread on/off',  'Marquer msgs comme lus auto'),
      _Cmd('.autostatus on/off','Bot repond aux statuts'),
      _Cmd('.chatbot on/off',   'Mode chatbot IA'),
    ]),
  ];

  class BotScreen extends ConsumerStatefulWidget {
    const BotScreen({super.key});
    @override ConsumerState<BotScreen> createState() => _BotScreenState();
  }

  class _BotScreenState extends ConsumerState<BotScreen> with TickerProviderStateMixin {
    late final TabController _tab;
    late final AnimationController _pulse;
    Timer? _statusTimer, _logTimer;
    Map<String, dynamic> _status = {};
    List<Map<String, dynamic>> _logs = [];
    bool _loadingStatus = true, _loadingLogs = true;
    String _search = '';
    final _searchCtrl = TextEditingController();

    @override
    void initState() {
      super.initState();
      _tab   = TabController(length: 3, vsync: this);
      _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
      _loadStatus(); _loadLogs();
      _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadStatus());
      _logTimer    = Timer.periodic(const Duration(seconds: 3), (_) => _loadLogs());
    }

    @override
    void dispose() {
      _statusTimer?.cancel(); _logTimer?.cancel();
      _tab.dispose(); _pulse.dispose(); _searchCtrl.dispose();
      super.dispose();
    }

    Future<void> _loadStatus() async {
      try {
        final s = await ref.read(apiServiceProvider).getBotStatus();
        if (mounted) setState(() { _status = s; _loadingStatus = false; });
      } catch (_) { if (mounted) setState(() => _loadingStatus = false); }
    }

    Future<void> _loadLogs() async {
      try {
        final l = await ref.read(apiServiceProvider).getLogs(limit: 100);
        if (mounted) setState(() { _logs = l; _loadingLogs = false; });
      } catch (_) { if (mounted) setState(() => _loadingLogs = false); }
    }

    String _fmtUptime(int s) {
      final h = s ~/ 3600; final m = (s % 3600) ~/ 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    @override
    Widget build(BuildContext context) {
      final connected = _status['status'] == 'online';
      final phone     = (_status['phoneNumber'] as String? ?? '').replaceAll('@s.whatsapp.net', '');
      final name      = _status['name'] as String? ?? '';
      final uptime    = _status['uptime'] as int? ?? 0;
      final ram       = _status['ramUsage'] as int? ?? 0;
      final ramTotal  = _status['ramTotal'] as int? ?? 256;
      final node      = _status['node'] as String? ?? '--';
      final version   = _status['version'] as String? ?? '--';

      return Scaffold(
        backgroundColor: _bg,
        body: Column(children: [
          const PageHeader(title: 'Bot', subtitle: 'Statut, logs et commandes du bot embarque'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: connected ? _g.withOpacity(.25) : _red.withOpacity(.25)),
              ),
              child: Row(children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected ? Color.lerp(_g, _gd, _pulse.value)! : _red,
                      boxShadow: connected
                          ? [BoxShadow(color: _g.withOpacity(.4 * _pulse.value), blurRadius: 8)]
                          : [],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(connected ? 'Connecte' : 'Deconnecte',
                      style: TextStyle(color: connected ? _g : _red, fontWeight: FontWeight.w700, fontSize: 15)),
                  if (phone.isNotEmpty)
                    Text('+$phone${name.isNotEmpty ? '  $name' : ''}',
                        style: const TextStyle(color: _muted, fontSize: 12)),
                ])),
                if (uptime > 0) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_fmtUptime(uptime),
                      style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
                  const Text('uptime', style: TextStyle(color: _muted, fontSize: 10)),
                ]),
              ]),
            ),
          ),
          Container(
            decoration: BoxDecoration(color: _card, border: Border(bottom: BorderSide(color: _border))),
            child: TabBar(
              controller: _tab,
              labelColor: _g, unselectedLabelColor: _muted,
              indicatorColor: _g, indicatorSize: TabBarIndicatorSize.label,
              tabs: const [Tab(text: 'Statut'), Tab(text: 'Logs'), Tab(text: 'Commandes')],
            ),
          ),
          Expanded(child: TabBarView(controller: _tab, children: [
            _StatusTab(connected: connected, ram: ram, ramTotal: ramTotal,
                node: node, version: version, loading: _loadingStatus,
                api: ref.read(apiServiceProvider)),
            _LogsTab(logs: _logs, loading: _loadingLogs, onRefresh: _loadLogs),
            _CommandsTab(groups: _kGroups, searchCtrl: _searchCtrl, search: _search,
                onSearch: (v) => setState(() => _search = v)),
          ])),
        ]),
      );
    }
  }

  class _StatusTab extends StatelessWidget {
    final bool connected, loading;
    final int ram, ramTotal;
    final String node, version;
    final ApiService api;
    const _StatusTab({required this.connected, required this.ram, required this.ramTotal,
        required this.node, required this.version, required this.loading, required this.api});

    @override
    Widget build(BuildContext context) {
      if (loading) return const Center(child: CircularProgressIndicator(color: _g));
      final ramPct = ramTotal > 0 ? (ram / ramTotal).clamp(0.0, 1.0) : 0.0;
      return ListView(padding: const EdgeInsets.all(16), children: [
        _Card([
          _Row(Icons.memory_outlined,      _blue,   'RAM utilisee',  '$ram MB / $ramTotal MB'),
          _Row(Icons.code_rounded,         _purple, 'Node.js',       node),
          _Row(Icons.info_outline_rounded, _orange, 'Version',       version),
          _Row(Icons.electrical_services,  _teal,   'Port HTTP',     'localhost:3001'),
          _Row(Icons.hub_outlined,         _blue,   'Protocole',     'Baileys (WA Web)'),
        ]),
        const SizedBox(height: 12),
        _Card([
          const Text('MEMOIRE RAM', style: TextStyle(color: _muted, fontSize: 11, letterSpacing: .8)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: ramPct, minHeight: 8,
                  backgroundColor: _border,
                  valueColor: AlwaysStoppedAnimation(ramPct > .8 ? _red : _g))),
          const SizedBox(height: 4),
          Text('${(ramPct * 100).toInt()}% utilise', style: const TextStyle(color: _muted, fontSize: 11)),
        ]),
        const SizedBox(height: 12),
        const Text('INTEGRATION', style: TextStyle(color: _muted, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _Card([
          _IntegRow('HTTP API (localhost:3001)', true),
          _IntegRow('Node.js embarque (android)', true),
          _IntegRow('WhatsApp Baileys', connected),
          _IntegRow('Supabase session', connected),
          _IntegRow('WebSocket temps reel', connected),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Btn('Redemarrer', Icons.refresh_rounded, _blue, () => api.restartBot())),
          const SizedBox(width: 10),
          Expanded(child: _Btn('Reinitialiser', Icons.delete_sweep_rounded, _red, () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: _card,
                title: const Text('Reinitialiser ?', style: TextStyle(color: _ink)),
                content: const Text('Supprime la session WhatsApp et redemarre.', style: TextStyle(color: _muted)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler', style: TextStyle(color: _muted))),
                  TextButton(onPressed: () => Navigator.pop(context, true),
                      child: const Text('OK', style: TextStyle(color: _red))),
                ],
              ),
            );
            if (ok == true) await api.resetBot();
          })),
        ]),
      ]);
    }
  }

  class _IntegRow extends StatelessWidget {
    final String label; final bool ok;
    const _IntegRow(this.label, this.ok);
    @override Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 15, color: ok ? _g : _muted),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: ok ? _ink : _muted, fontSize: 13)),
      ]),
    );
  }

  class _Card extends StatelessWidget {
    final List<Widget> children;
    const _Card(this.children);
    @override Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  class _Row extends StatelessWidget {
    final IconData icon; final Color color; final String label, value;
    const _Row(this.icon, this.color, this.label, this.value);
    @override Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: color), const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(color: _muted, fontSize: 13))),
        Text(value, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  class _Btn extends StatelessWidget {
    final String label; final IconData icon; final Color color; final VoidCallback onTap;
    const _Btn(this.label, this.icon, this.color, this.onTap);
    @override Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(.3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: color), const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }

  class _LogsTab extends StatelessWidget {
    final List<Map<String, dynamic>> logs;
    final bool loading;
    final VoidCallback onRefresh;
    const _LogsTab({required this.logs, required this.loading, required this.onRefresh});

    Color _lc(String? l) {
      switch (l?.toUpperCase()) {
        case 'ERROR':   return _red;
        case 'WARN':    return _orange;
        case 'SUCCESS': return _g;
        case 'INFO':    return _blue;
        default:        return _muted;
      }
    }

    @override
    Widget build(BuildContext context) {
      if (loading) return const Center(child: CircularProgressIndicator(color: _g));
      if (logs.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.terminal_rounded, size: 40, color: _muted),
        const SizedBox(height: 12),
        const Text('Aucun log', style: TextStyle(color: _muted)),
        const SizedBox(height: 8),
        GestureDetector(onTap: onRefresh, child: const Text('Actualiser', style: TextStyle(color: _g))),
      ]));
      return RefreshIndicator(color: _g, backgroundColor: _card, onRefresh: () async => onRefresh(),
        child: ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: logs.length,
          itemBuilder: (_, i) {
            final log   = logs[i];
            final level = log['level'] as String? ?? 'INFO';
            final msg   = log['message'] as String? ?? log['msg'] as String? ?? '$log';
            return Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _lc(level).withOpacity(.15))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: _lc(level).withOpacity(.1),
                      borderRadius: BorderRadius.circular(3)),
                  child: Text(level.length > 4 ? level.substring(0, 4) : level,
                      style: TextStyle(color: _lc(level), fontSize: 9, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(msg,
                    style: const TextStyle(color: _ink, fontSize: 11.5, fontFamily: 'monospace'))),
              ]),
            );
          },
        ),
      );
    }
  }

  class _CommandsTab extends StatelessWidget {
    final List<_Group> groups;
    final TextEditingController searchCtrl;
    final String search;
    final ValueChanged<String> onSearch;
    const _CommandsTab({required this.groups, required this.searchCtrl,
        required this.search, required this.onSearch});

    @override
    Widget build(BuildContext context) {
      final q = search.toLowerCase();
      final filtered = q.isEmpty
          ? groups
          : groups.map((g) {
              final c = g.cmds.where((x) =>
                  x.cmd.contains(q) || x.desc.toLowerCase().contains(q)).toList();
              return c.isEmpty ? null : _Group(g.name, g.icon, c);
            }).whereType<_Group>().toList();

      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: searchCtrl, onChanged: onSearch,
            style: const TextStyle(color: _ink, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher une commande...', hintStyle: const TextStyle(color: _muted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 18),
              filled: true, fillColor: _card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _g)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: filtered.map((g) => _GroupWidget(g)).toList(),
        )),
      ]);
    }
  }

  class _GroupWidget extends StatelessWidget {
    final _Group group;
    const _GroupWidget(this.group);
    @override Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
          child: Row(children: [
            Icon(group.icon, size: 13, color: _g), const SizedBox(width: 6),
            Text(group.name.toUpperCase(),
                style: const TextStyle(color: _g, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ]),
        ),
        Container(
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border)),
          child: Column(children: List.generate(group.cmds.length, (i) {
            final cmd = group.cmds[i]; final isLast = i == group.cmds.length - 1;
            return GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: cmd.cmd));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Copie: ${cmd.cmd}'), duration: const Duration(seconds: 1),
                  backgroundColor: _card, behavior: SnackBarBehavior.floating,
                ));
              },
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cmd.cmd, style: const TextStyle(color: _g,
                          fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(cmd.desc, style: const TextStyle(color: _muted, fontSize: 12)),
                    ])),
                    const Icon(Icons.content_copy_rounded, size: 13, color: _muted),
                  ]),
                ),
                if (!isLast) Divider(height: 1, color: _border),
              ]),
            );
          })),
        ),
      ],
    );
  }
  