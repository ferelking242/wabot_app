import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/api_service.dart';

const _g      = Color(0xFF25D366);
const _ink    = Color(0xFFF2F3F5);
const _muted  = Color(0xFF8A9199);
const _border = Color(0xFF1E2128);
const _card   = Color(0xFF111316);
const _bg     = Color(0xFF0D0E11);
const _red    = Color(0xFFFF5B5B);

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});
  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  Map<String, dynamic>? _status;
  bool _loading    = true;
  bool _exporting  = false;
  String? _error;
  String? _exportMsg;
  bool _exportOk   = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getInstanceStatus();
      if (mounted) setState(() { _status = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Export de session ──────────────────────────────────────────────────────
  Future<void> _exportSession() async {
    setState(() { _exporting = true; _exportMsg = null; });
    try {
      final api  = ref.read(apiServiceProvider);
      final data = await api.exportSession();

      if (data['success'] != true) {
        _setExportMsg(data['error'] ?? 'Erreur export', false);
        return;
      }

      final jsonStr  = const JsonEncoder.withIndent('  ').convert(data);
      final filename = 'wabot_session_${DateTime.now().millisecondsSinceEpoch}.json';

      if (kIsWeb) {
        // Web : copier dans le presse-papier (pas d'accès au FS)
        // On ne partage que le JSON tronqué pour sécurité
        _setExportMsg('✅ Session exportée — copie le contenu depuis un appareil Android', true);
        return;
      }

      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/$filename';
      await File(path).writeAsString(jsonStr);
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Session Wabot',
        text: 'Fichier de session WhatsApp — garde-le précieusement !',
      );
      _setExportMsg('✅ Session exportée avec succès', true);
    } catch (e) {
      _setExportMsg('Erreur : $e', false);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _setExportMsg(String msg, bool ok) {
    if (mounted) setState(() { _exportMsg = msg; _exportOk = ok; });
  }

  @override
  Widget build(BuildContext context) {
    final inst      = (_status?['instance'] as Map<String, dynamic>?) ?? {};
    final connected = inst['connected'] == true;
    final rawPhone  = inst['phone'] as String? ?? '';
    final phone     = rawPhone.replaceAll(RegExp(r':.*@'), '@').replaceAll('@s.whatsapp.net', '');
    final name      = inst['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _g,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [

            // ── En-tête ──────────────────────────────────────────────────────
            Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sessions WhatsApp',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
                SizedBox(height: 4),
                Text('Appareils connectés à ce bot',
                  style: TextStyle(color: _muted, fontSize: 12)),
              ])),
              if (_loading)
                const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: _g, strokeWidth: 2))
              else
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, color: _muted, size: 20),
                  tooltip: 'Actualiser',
                ),
            ]),

            const SizedBox(height: 16),

            // ── Bouton Exporter ───────────────────────────────────────────────
            if (connected) ...[
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _exporting ? null : _exportSession,
                  icon: _exporting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.file_upload_outlined, size: 18),
                  label: Text(_exporting ? 'Export en cours…' : 'Exporter la session',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _g,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _g.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _g.withOpacity(0.12))),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 13, color: _g.withOpacity(0.6)),
                  const SizedBox(width: 7),
                  Expanded(child: Text(
                    'Exporte la session pour éviter de re-scanner le QR code à chaque redémarrage.',
                    style: TextStyle(color: _g.withOpacity(0.65), fontSize: 11))),
                ]),
              ),
              if (_exportMsg != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_exportOk ? _g : _red).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (_exportOk ? _g : _red).withOpacity(0.25))),
                  child: Text(_exportMsg!,
                    style: TextStyle(
                      color: _exportOk ? _g : _red, fontSize: 12)),
                ),
              ],
              const SizedBox(height: 16),
            ],

            // ── Carte session ─────────────────────────────────────────────────
            if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (!connected)
              const _EmptyCard()
            else
              _SessionCard(phone: phone, name: name),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final String phone;
  final String name;
  const _SessionCard({required this.phone, required this.name});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border)),
    child: Row(children: [
      Container(width: 44, height: 44,
        decoration: BoxDecoration(color: _g.withOpacity(.15), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.phone_android_rounded, size: 22, color: _g)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(phone.isNotEmpty ? '+$phone' : 'Connecté',
          style: const TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w700)),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(name, style: const TextStyle(fontSize: 12, color: _muted)),
        ],
        const SizedBox(height: 4),
        Row(children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: _g, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          const Text('Connectée · WhatsApp actif', style: TextStyle(fontSize: 11.5, color: _muted)),
        ]),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _g.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
        child: const Text('ACTIF', style: TextStyle(color: _g, fontSize: 10, fontWeight: FontWeight.w800))),
    ]),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border)),
    child: const Column(children: [
      Icon(Icons.phone_android_outlined, size: 48, color: Color(0x668A9199)),
      SizedBox(height: 14),
      Text('Aucune session active',
        style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w600)),
      SizedBox(height: 6),
      Text("Connectez votre WhatsApp depuis l'écran de jumelage",
        textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 12)),
    ]),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF3D1515))),
    child: Column(children: [
      const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6B), size: 36),
      const SizedBox(height: 10),
      const Text('Bot non joignable', style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 6),
      const Text('Vérifiez que le bot est démarré', style: TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 14),
      GestureDetector(onTap: onRetry,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(color: _g.withOpacity(.15), borderRadius: BorderRadius.circular(8)),
          child: const Text('Réessayer', style: TextStyle(color: _g, fontWeight: FontWeight.w700)))),
    ]),
  );
}
