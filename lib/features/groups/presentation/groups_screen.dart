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
  List<Map<String, dynamic>> _groups = [];
  bool   _loading = true;
  String _search  = '';
  String _error   = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final api  = ref.read(apiServiceProvider);
      final data = await api.getGroups();
      if (mounted) setState(() { _groups = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _groups;
    final q = _search.toLowerCase();
    return _groups.where((g) {
      final name = (g['name'] ?? g['subject'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  String _groupName(Map<String, dynamic> g) =>
      (g['name'] ?? g['subject'] ?? 'Groupe inconnu').toString();

  int _participantCount(Map<String, dynamic> g) {
    final p = g['participants'] ?? g['participantsCount'] ?? g['size'] ?? 0;
    if (p is int) return p;
    return int.tryParse(p.toString()) ?? 0;
  }

  bool _isAdmin(Map<String, dynamic> g) =>
      g['isAdmin'] == true || g['botIsAdmin'] == true;

  String _emoji(Map<String, dynamic> g) {
    final name = _groupName(g).toLowerCase();
    if (name.contains('family') || name.contains('famille')) return '🏠';
    if (name.contains('bot') || name.contains('wabot'))       return '🤖';
    if (name.contains('dev') || name.contains('code'))        return '💻';
    if (name.contains('music') || name.contains('musique'))   return '🎵';
    if (name.contains('crypto') || name.contains('finance'))  return '₿';
    if (name.contains('game') || name.contains('gaming'))     return '🎮';
    if (name.contains('news') || name.contains('actualité'))  return '📰';
    return '👥';
  }

  @override
  Widget build(BuildContext context) {
    final list    = _filtered;
    final total   = _groups.length;
    final admins  = _groups.where(_isAdmin).length;

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
                const Text('Groupes', style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w800, color: _ink)),
                Text('$total groupe${total > 1 ? "s" : ""} enregistré${total > 1 ? "s" : ""}',
                    style: const TextStyle(color: _muted, fontSize: 13)),
              ])),
              if (_loading)
                const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: _g, strokeWidth: 2))
              else
                GestureDetector(
                  onTap: _load,
                  child: const Icon(Icons.refresh_rounded, color: _muted, size: 20)),
            ]),
            const SizedBox(height: 16),

            // Summary cards
            Row(children: [
              Expanded(child: _MiniStat(
                  icon: Icons.groups_rounded, label: 'Total',
                  value: '$total', color: _g)),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(
                  icon: Icons.admin_panel_settings_rounded, label: 'Admin',
                  value: '$admins', color: const Color(0xFF1ABC9C))),
              const SizedBox(width: 10),
              Expanded(child: _MiniStat(
                  icon: Icons.group_outlined, label: 'Membre',
                  value: '${total - admins}', color: const Color(0xFF57B6FF))),
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

            // Error state
            if (_error.isNotEmpty && !_loading)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Color(0xFFFF6B6B), size: 16),
                  const SizedBox(width: 8),
                  const Expanded(child: Text(
                    'Bot hors ligne — reconnecte-toi et réessaie',
                    style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
                  )),
                ]),
              ),

            // Empty state
            if (!_loading && list.isEmpty && _error.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.group_off_rounded, color: _muted, size: 48),
                  const SizedBox(height: 12),
                  const Text('Aucun groupe pour l\'instant',
                      style: TextStyle(color: _ink, fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    _search.isNotEmpty
                        ? 'Aucun résultat pour "$_search"'
                        : 'Le bot n\'est dans aucun groupe WhatsApp',
                    style: const TextStyle(color: _muted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ))
            else
              for (final g in list) ...[
                _GroupTile(
                  name:       _groupName(g),
                  count:      _participantCount(g),
                  emoji:      _emoji(g),
                  isAdmin:    _isAdmin(g),
                  id:         (g['id'] ?? '').toString(),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color    color;
  const _MiniStat({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

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
  final String name, emoji, id;
  final int    count;
  final bool   isAdmin;
  const _GroupTile({
    required this.name, required this.count,
    required this.emoji, required this.isAdmin, required this.id,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAdmin ? _g.withOpacity(.2) : _border),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            gradient: isAdmin
                ? const LinearGradient(
                    colors: [_g, _gd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                : null,
            color: isAdmin ? null : const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(emoji,
              style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.people_rounded, size: 12, color: _muted),
              const SizedBox(width: 4),
              Text('$count membre${count > 1 ? "s" : ""}',
                  style: const TextStyle(fontSize: 12, color: _muted)),
            ]),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isAdmin ? _g.withOpacity(.12) : Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isAdmin ? 'Admin' : 'Membre',
              style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700,
                color: isAdmin ? _g : _muted)),
          ),
          const SizedBox(height: 6),
          const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
        ]),
      ]),
    );
  }
}
