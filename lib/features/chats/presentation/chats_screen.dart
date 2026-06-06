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

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});
  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  List<Map<String, dynamic>> _messages = [];
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
      final data = await api.getRecentMessages(limit: 50);
      if (mounted) setState(() { _messages = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _messages;
    final q = _search.toLowerCase();
    return _messages.where((m) {
      final from = _senderLabel(m).toLowerCase();
      final body = _body(m).toLowerCase();
      return from.contains(q) || body.contains(q);
    }).toList();
  }

  String _senderLabel(Map<String, dynamic> m) {
    final from = m['from'] ?? m['sender'] ?? m['jid'] ?? '';
    return from.toString().replaceAll('@s.whatsapp.net', '').replaceAll('@g.us', '');
  }

  String _body(Map<String, dynamic> m) =>
      (m['body'] ?? m['text'] ?? m['message'] ?? m['content'] ?? '').toString();

  String _timeLabel(Map<String, dynamic> m) {
    try {
      final ts = m['timestamp'];
      DateTime? dt;
      if (ts is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(ts * (ts > 1e10 ? 1 : 1000));
      } else if (ts is String) {
        dt = DateTime.parse(ts).toLocal();
      }
      if (dt == null) return '';
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  bool _isBot(Map<String, dynamic> m) =>
      m['fromBot'] == true || m['isBot'] == true || m['fromMe'] == true;

  String _initials(String label) {
    final cleaned = label.replaceAll(RegExp(r'[^\w\d]'), '');
    if (cleaned.isEmpty) return '?';
    return cleaned.substring(0, cleaned.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

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
                const Text('Conversations', style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w800, color: _ink)),
                Text('${_messages.length} message${_messages.length > 1 ? "s" : ""} reçu${_messages.length > 1 ? "s" : ""}',
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
                    hintText: 'Rechercher une conversation…',
                    hintStyle: TextStyle(color: _muted, fontSize: 13),
                    border: InputBorder.none, isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                )),
              ]),
            ),
            const SizedBox(height: 14),

            // Error / offline
            if (_error.isNotEmpty && !_loading)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF6B6B).withOpacity(.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.wifi_off_rounded, color: Color(0xFFFF6B6B), size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
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
                  Icon(Icons.chat_bubble_outline_rounded, color: _muted.withOpacity(.5), size: 48),
                  const SizedBox(height: 12),
                  const Text('Aucun message reçu',
                      style: TextStyle(color: _ink, fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    _search.isNotEmpty
                        ? 'Aucun résultat pour "$_search"'
                        : 'Envoie .ping dans WhatsApp pour tester le bot',
                    style: const TextStyle(color: _muted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ))
            else
              for (final m in list) ...[
                _ChatRow(
                  label:    _senderLabel(m),
                  preview:  _body(m),
                  time:     _timeLabel(m),
                  isBot:    _isBot(m),
                  initials: _initials(_senderLabel(m)),
                  isGroup:  (m['isGroup'] ?? false) == true,
                ),
                Container(height: 1, color: _border),
              ],
          ],
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final String label, preview, time, initials;
  final bool   isBot, isGroup;
  const _ChatRow({
    required this.label,   required this.preview,
    required this.time,    required this.isBot,
    required this.initials, required this.isGroup,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_gd, _g]),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Center(child: Text(initials,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (isGroup) const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.group_rounded, size: 13, color: _muted)),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 13.5, color: _ink,
                  fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 3),
        Text(preview.isEmpty ? '—' : preview,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _muted)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (time.isNotEmpty)
          Text(time, style: const TextStyle(fontSize: 10.5, color: _muted)),
        if (isBot) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _g.withOpacity(.15),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text('BOT',
                style: TextStyle(fontSize: 9, color: _g,
                    fontWeight: FontWeight.w800))),
        ],
      ]),
    ]),
  );
}
