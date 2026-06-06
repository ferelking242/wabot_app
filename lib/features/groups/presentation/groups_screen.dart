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

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});
  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final d   = await api.getBotStatus();
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Simulated group list from API data
  static const _mockGroups = [
    _GrpData('Family ❤️',        '8 membres',  true,  '🏠', 'Familial'),
    _GrpData('Wabot Alpha',       '45 membres', true,  '🤖', 'Bot test'),
    _GrpData('Dev Congo',         '120 membres',false, '💻', 'Développement'),
    _GrpData('Musique 🎵',        '34 membres', true,  '🎵', 'Loisirs'),
    _GrpData('Crypto Talk',       '89 membres', false, '₿',  'Finance'),
    _GrpData('WhatsApp Tips',     '203 membres',true,  '📱', 'Tech'),
    _GrpData('BZV Network',       '67 membres', false, '🌍', 'Réseau'),
    _GrpData('Gaming Zone',       '55 membres', true,  '🎮', 'Gaming'),
  ];

  List<_GrpData> get _filtered {
    if (_search.isEmpty) return _mockGroups;
    final q = _search.toLowerCase();
    return _mockGroups.where((g) => g.name.toLowerCase().contains(q) || g.type.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final total  = (_data?['groupsCount'] as int?) ?? _mockGroups.length;
    final active = _mockGroups.where((g) => g.active).length;
    final list   = _filtered;

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
                const Text('Groupes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
                Text('$total groupes enregistrés', style: const TextStyle(color: _muted, fontSize: 13)),
              ])),
              if (_loading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _g, strokeWidth: 2))
              else
                GestureDetector(onTap: _load, child: const Icon(Icons.refresh_rounded, color: _muted, size: 20)),
            ]),
            const SizedBox(height: 16),

            // Summary cards
            Row(children: [
              Expanded(child: _MiniStat(icon: Icons.groups_rounded, label: 'Total', value: '$total', color: _g)),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(icon: Icons.check_circle_rounded, label: 'Actifs', value: '$active', color: const Color(0xFF1ABC9C))),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(icon: Icons.cancel_rounded, label: 'Inactifs', value: '${total - active}', color: const Color(0xFFE74C3C))),
            ]),
            const SizedBox(height: 16),

            // Search bar
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                const Icon(Icons.search_rounded, size: 16, color: _muted),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontSize: 13, color: _ink),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un groupe…',
                    hintStyle: TextStyle(color: _muted, fontSize: 13),
                    border: InputBorder.none, isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                )),
              ]),
            ),
            const SizedBox(height: 14),

            // Group list
            if (list.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.group_off_rounded, color: _muted, size: 36),
                  SizedBox(height: 10),
                  Text('Aucun groupe trouvé', style: TextStyle(color: _muted, fontSize: 14)),
                ]),
              ))
            else
              for (final g in list) ...[
                _GroupTile(grp: g),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _GrpData {
  final String name, size, emoji, type;
  final bool active;
  const _GrpData(this.name, this.size, this.active, this.emoji, this.type);
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _MiniStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(.25)),
    ),
    child: Column(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: _muted, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _GroupTile extends StatelessWidget {
  final _GrpData grp;
  const _GroupTile({required this.grp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: grp.active ? _g.withOpacity(.2) : _border),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: grp.active
              ? const LinearGradient(colors: [_g, _gd], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
            color: grp.active ? null : const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(grp.emoji, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(grp.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.people_rounded, size: 12, color: _muted),
            const SizedBox(width: 4),
            Text(grp.size, style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(width: 8),
            Container(
              width: 4, height: 4,
              decoration: BoxDecoration(color: _muted.withOpacity(.5), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(grp.type, style: const TextStyle(fontSize: 12, color: _muted)),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: grp.active ? _g.withOpacity(.12) : Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(grp.active ? 'Actif' : 'Inactif',
              style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700,
                color: grp.active ? _g : _muted)),
          ),
          const SizedBox(height: 6),
          const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
        ]),
      ]),
    );
  }
}
