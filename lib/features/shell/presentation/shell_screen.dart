import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';

const _bg    = Color(0xFF060709);
const _card  = Color(0xFF0C0F14);
const _card2 = Color(0xFF111620);
const _brdr  = Color(0xFF181E2C);
const _g     = Color(0xFF25D366);
const _gd    = Color(0xFF1AAD4B);
const _ink   = Color(0xFFF2F3F5);
const _sub   = Color(0xFF8A94A8);
const _muted = Color(0xFF3D4455);
const _red   = Color(0xFFFF5B5B);
const _orange= Color(0xFFFF9D4A);
const _blue  = Color(0xFF4A9EFF);
const _cyan  = Color(0xFF20D9C0);

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});
  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  final _inputCtrl   = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _focusNode   = FocusNode();

  final List<_ShellLine> _lines = [];
  bool _loading = false;
  List<String> _history = [];
  int _historyIdx = -1;

  static const _TAG = 'ShellScreen';

  static const _quickCmds = [
    _QuickCmd(label: 'Status',   cmd: 'status',        icon: Icons.info_outline_rounded,     color: _blue),
    _QuickCmd(label: 'Logs',     cmd: 'logs',          icon: Icons.receipt_long_outlined,    color: _g),
    _QuickCmd(label: 'Restart',  cmd: 'restart',       icon: Icons.restart_alt_rounded,      color: _orange),
    _QuickCmd(label: 'Reset',    cmd: 'reset',         icon: Icons.logout_rounded,           color: _red),
    _QuickCmd(label: 'Update',   cmd: 'update check',  icon: Icons.system_update_alt_rounded,color: _cyan),
    _QuickCmd(label: 'Apply',    cmd: 'update apply',  icon: Icons.download_done_rounded,    color: _g),
    _QuickCmd(label: 'Queue',    cmd: 'queue',         icon: Icons.queue_rounded,            color: _sub),
    _QuickCmd(label: 'Clear',    cmd: 'clear',         icon: Icons.clear_all_rounded,        color: _muted),
  ];

  @override
  void initState() {
    super.initState();
    _addLine('Wabot Shell v1.0 — connecté au bot local', _g, isSystem: true);
    _addLine('Tape "help" pour voir les commandes disponibles.', _sub, isSystem: true);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addLine(String text, Color color, {bool isSystem = false, bool isInput = false}) {
    setState(() {
      _lines.add(_ShellLine(
        text: text,
        color: color,
        isSystem: isSystem,
        isInput: isInput,
        time: DateTime.now(),
      ));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runCommand(String raw) async {
    final cmd = raw.trim();
    if (cmd.isEmpty) return;

    _addLine('> $cmd', _g, isInput: true);

    if (!_history.contains(cmd)) {
      _history.insert(0, cmd);
      if (_history.length > 50) _history.removeLast();
    }
    _historyIdx = -1;
    _inputCtrl.clear();

    if (cmd == 'clear') {
      setState(() => _lines.clear());
      _addLine('Terminal effacé.', _sub, isSystem: true);
      return;
    }

    if (cmd == 'help') {
      _showHelp();
      return;
    }

    setState(() => _loading = true);
    try {
      await _dispatch(cmd);
    } catch (e) {
      _addLine('Erreur: $e', _red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dispatch(String cmd) async {
    final api = ref.read(apiServiceProvider);
    final parts = cmd.toLowerCase().split(RegExp(r'\s+'));

    switch (parts[0]) {
      case 'status':
        _addLine('Récupération du statut…', _sub, isSystem: true);
        final s = await api.getBotStatus();
        _addLine('Statut      : ${s['status']}', s['status'] == 'online' ? _g : _red);
        _addLine('Nom         : ${s['name'] ?? '—'}', _ink);
        _addLine('Téléphone   : ${s['phoneNumber'] ?? '—'}', _ink);
        _addLine('Uptime      : ${s['uptime'] ?? 0}s', _blue);
        _addLine('RAM         : ${s['ramUsage'] ?? 0} MB', _orange);
        _addLine('Node.js     : ${s['node'] ?? '—'}', _cyan);
        break;

      case 'logs':
        _addLine('Récupération des logs…', _sub, isSystem: true);
        final limit = parts.length > 1 ? int.tryParse(parts[1]) ?? 20 : 20;
        final logs  = await api.getLogs(limit: limit);
        if (logs.isEmpty) {
          _addLine('Aucun log disponible.', _muted);
        } else {
          for (final l in logs.take(limit)) {
            final lvl = (l['level'] as String? ?? 'INFO').toUpperCase();
            final msg = l['msg'] as String? ?? '';
            final c   = lvl == 'ERROR' ? _red
                      : lvl == 'WARN'  ? _orange
                      : lvl == 'OK'    ? _g
                      : _blue;
            _addLine('[$lvl] $msg', c);
          }
        }
        break;

      case 'restart':
        _addLine('Envoi du signal de redémarrage…', _orange, isSystem: true);
        final ok = await api.restartBot();
        _addLine(ok ? '✅ Redémarrage lancé — attendre ~10s' : '❌ Échec du redémarrage', ok ? _g : _red);
        break;

      case 'reset':
        _addLine('Réinitialisation de la session WhatsApp…', _red, isSystem: true);
        await api.resetBot();
        _addLine('✅ Session réinitialisée — nouveau QR requis', _orange);
        break;

      case 'update':
        if (parts.length < 2) {
          _addLine('Usage: update check | update apply', _sub, isSystem: true);
          break;
        }
        if (parts[1] == 'check') {
          _addLine('Vérification de la mise à jour…', _sub, isSystem: true);
          final info = await api.checkBundleUpdate();
          final has  = info['hasUpdate'] == true;
          _addLine('Actuel  : ${_short(info['currentSha'] as String?)}', _sub);
          _addLine('Dernier : ${_short(info['latestSha'] as String?)}', has ? _orange : _g);
          _addLine(has ? '⬆ Mise à jour disponible !' : '✅ Bot à jour', has ? _orange : _g);
        } else if (parts[1] == 'apply') {
          _addLine('Application de la mise à jour…', _cyan, isSystem: true);
          final info = await api.checkBundleUpdate();
          final sha  = info['latestSha'] as String?;
          if (sha == null) {
            _addLine('❌ Impossible de récupérer le SHA.', _red);
          } else {
            final ok = await api.applyBundleUpdate(sha);
            _addLine(ok ? '✅ Mise à jour lancée — redémarrage dans ~5s' : '❌ Échec.', ok ? _g : _red);
          }
        } else {
          _addLine('Usage: update check | update apply', _sub, isSystem: true);
        }
        break;

      case 'queue':
        _addLine('Récupération de la file…', _sub, isSystem: true);
        try {
          final res = await ref.read(apiServiceProvider).getQueueStats();
          for (final e in res.entries) {
            _addLine('${e.key.padRight(12)}: ${e.value}', _blue);
          }
        } catch (e) {
          _addLine('❌ $e', _red);
        }
        break;

      case 'reconnect':
        _addLine('Reconnexion WhatsApp…', _blue, isSystem: true);
        final r = await api.reconnect();
        _addLine(r['success'] == true ? '✅ ${r['message']}' : '❌ ${r['message'] ?? 'Échec'}',
            r['success'] == true ? _g : _red);
        break;

      case 'ping':
        _addLine('Ping…', _sub, isSystem: true);
        final t0 = DateTime.now().millisecondsSinceEpoch;
        await api.getBotStatus();
        final dt = DateTime.now().millisecondsSinceEpoch - t0;
        _addLine('Pong — ${dt}ms', dt < 300 ? _g : dt < 800 ? _orange : _red);
        break;

      default:
        _addLine('Commande inconnue: "$cmd"', _red);
        _addLine('Tape "help" pour voir les commandes.', _sub, isSystem: true);
    }
  }

  String _short(String? sha) =>
      (sha != null && sha.length >= 7) ? sha.substring(0, 7) : (sha ?? '—');

  void _showHelp() {
    _addLine('─── Commandes disponibles ───────────────────────', _muted, isSystem: true);
    _addLine('status              — Statut du bot', _blue);
    _addLine('logs [N]            — Derniers N logs (défaut: 20)', _blue);
    _addLine('restart             — Redémarrer le bot', _orange);
    _addLine('reset               — Réinitialiser la session WhatsApp', _red);
    _addLine('reconnect           — Reconnecter WhatsApp', _blue);
    _addLine('update check        — Vérifier la mise à jour', _cyan);
    _addLine('update apply        — Appliquer la mise à jour', _g);
    _addLine('queue               — Voir la file de messages', _sub);
    _addLine('ping                — Tester la latence API', _blue);
    _addLine('clear               — Effacer le terminal', _muted);
    _addLine('help                — Afficher cette aide', _sub);
    _addLine('─────────────────────────────────────────────────', _muted, isSystem: true);
  }

  void _historyUp() {
    if (_history.isEmpty) return;
    setState(() {
      _historyIdx = (_historyIdx + 1).clamp(0, _history.length - 1);
      _inputCtrl.text = _history[_historyIdx];
      _inputCtrl.selection = TextSelection.collapsed(
          offset: _inputCtrl.text.length);
    });
  }

  void _historyDown() {
    if (_historyIdx <= 0) {
      setState(() { _historyIdx = -1; _inputCtrl.clear(); });
      return;
    }
    setState(() {
      _historyIdx--;
      _inputCtrl.text = _history[_historyIdx];
      _inputCtrl.selection = TextSelection.collapsed(
          offset: _inputCtrl.text.length);
    });
  }

  Future<void> _copyAll() async {
    final text = _lines.map((l) => l.text).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Terminal copié ✓'),
        backgroundColor: _g,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [

        // ── Header ─────────────────────────────────────────────────────────
        _TerminalHeader(
          loading: _loading,
          onClear: () { setState(() => _lines.clear()); _addLine('Terminal effacé.', _sub, isSystem: true); },
          onCopy: _copyAll,
        ).animate().fadeIn(duration: 200.ms),

        // ── Quick commands ──────────────────────────────────────────────────
        _QuickBar(
          cmds: _quickCmds,
          onTap: (cmd) => _runCommand(cmd),
        ).animate().fadeIn(duration: 250.ms, delay: 40.ms),

        // ── Terminal output ─────────────────────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF040507),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _brdr),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              // Chrome bar
              Container(
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0C11),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: _brdr)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Container(width: 9, height: 9,
                      decoration: BoxDecoration(color: _red.withOpacity(0.7), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Container(width: 9, height: 9,
                      decoration: BoxDecoration(color: _orange.withOpacity(0.7), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Container(width: 9, height: 9,
                      decoration: BoxDecoration(color: _g.withOpacity(0.7), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Text('wabot@shell ~ terminal', style: TextStyle(
                      color: _sub.withOpacity(0.5), fontSize: 10,
                      fontFamily: 'monospace')),
                  const Spacer(),
                  if (_loading)
                    const SizedBox(width: 10, height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: _g)),
                ]),
              ),
              // Lines
              Expanded(
                child: GestureDetector(
                  onTap: () => _focusNode.requestFocus(),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(10),
                    itemCount: _lines.length,
                    itemBuilder: (_, i) => _LineWidget(line: _lines[i]),
                  ),
                ),
              ),
            ]),
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 80.ms),

        // ── Input bar ───────────────────────────────────────────────────────
        _InputBar(
          controller: _inputCtrl,
          focusNode: _focusNode,
          loading: _loading,
          onSubmit: _runCommand,
          onHistoryUp: _historyUp,
          onHistoryDown: _historyDown,
        ).animate().fadeIn(duration: 300.ms, delay: 120.ms),

        const SizedBox(height: 8),
      ]),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _TerminalHeader extends StatelessWidget {
  final bool loading;
  final VoidCallback onClear, onCopy;
  const _TerminalHeader({required this.loading, required this.onClear, required this.onCopy});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Shell', style: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w900, color: _ink, letterSpacing: -0.8)),
        const SizedBox(height: 3),
        Row(children: [
          Container(width: 6, height: 6,
              decoration: BoxDecoration(
                  color: loading ? _orange : _g, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(loading ? 'Exécution…' : 'Prêt',
              style: TextStyle(color: loading ? _orange : _g,
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ])),
      _HBtn(icon: Icons.copy_rounded, tooltip: 'Copier tout', onTap: onCopy),
      const SizedBox(width: 6),
      _HBtn(icon: Icons.clear_all_rounded, tooltip: 'Effacer', onTap: onClear),
    ]),
  );
}

class _HBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HBtn({required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
            color: _card2, borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _brdr)),
        child: Icon(icon, color: _sub, size: 16),
      ),
    ),
  );
}

// ── Quick command bar ─────────────────────────────────────────────────────────
class _QuickCmd {
  final String label, cmd;
  final IconData icon;
  final Color color;
  const _QuickCmd({required this.label, required this.cmd,
      required this.icon, required this.color});
}

class _QuickBar extends StatelessWidget {
  final List<_QuickCmd> cmds;
  final ValueChanged<String> onTap;
  const _QuickBar({required this.cmds, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: cmds.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final c = cmds[i];
        return GestureDetector(
          onTap: () => onTap(c.cmd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.color.withOpacity(0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(c.icon, color: c.color, size: 12),
              const SizedBox(width: 5),
              Text(c.label, style: TextStyle(
                  color: c.color, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      },
    ),
  );
}

// ── Terminal line ─────────────────────────────────────────────────────────────
class _ShellLine {
  final String text;
  final Color color;
  final bool isSystem, isInput;
  final DateTime time;
  const _ShellLine({required this.text, required this.color,
      required this.isSystem, required this.isInput, required this.time});
}

class _LineWidget extends StatelessWidget {
  final _ShellLine line;
  const _LineWidget({required this.line});

  @override
  Widget build(BuildContext context) {
    final t = line.time;
    final ts = '${t.hour.toString().padLeft(2,'0')}:'
               '${t.minute.toString().padLeft(2,'0')}:'
               '${t.second.toString().padLeft(2,'0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ts, style: const TextStyle(
            fontSize: 9.5, color: Color(0xFF2E3547), fontFamily: 'monospace')),
        const SizedBox(width: 8),
        Expanded(child: Text(line.text, style: TextStyle(
            fontSize: 11.5, color: line.color,
            fontFamily: 'monospace', height: 1.35,
            fontWeight: line.isInput ? FontWeight.w700 : FontWeight.w400))),
      ]),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final ValueChanged<String> onSubmit;
  final VoidCallback onHistoryUp, onHistoryDown;

  const _InputBar({
    required this.controller, required this.focusNode,
    required this.loading, required this.onSubmit,
    required this.onHistoryUp, required this.onHistoryDown,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _g.withOpacity(0.35), width: 1.2),
      boxShadow: [BoxShadow(
        color: _g.withOpacity(0.06), blurRadius: 12)],
    ),
    child: Row(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('>', style: TextStyle(
            color: _g, fontSize: 14, fontFamily: 'monospace',
            fontWeight: FontWeight.w800)),
      ),
      Expanded(
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) onHistoryUp();
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) onHistoryDown();
            }
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: !loading,
            style: const TextStyle(
                color: _ink, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'Entrer une commande…',
              hintStyle: TextStyle(color: _muted, fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: loading ? null : onSubmit,
            textInputAction: TextInputAction.done,
          ),
        ),
      ),
      GestureDetector(
        onTap: loading ? null : () => onSubmit(controller.text),
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: loading ? _muted.withOpacity(0.15) : _g.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: loading
              ? const Center(child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _g)))
              : const Icon(Icons.send_rounded, color: _g, size: 18),
        ),
      ),
    ]),
  );
}
