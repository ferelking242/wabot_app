import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/storage_service.dart';
import 'splash_screen.dart' show WabotLogoWidget;
import 'package:dio/dio.dart';

const _g  = Color(0xFF25D366);
const _gd = Color(0xFF128C7E);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _urlCtrl  = TextEditingController(text: AppConstants.defaultApiUrl);
  final _keyCtrl  = TextEditingController();
  final _form     = GlobalKey<FormState>();
  bool _loading   = false;
  bool _obscure   = true;
  bool _importing = false;
  String? _importMsg;
  bool _importOk  = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final url = _urlCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
    final key = _keyCtrl.text.trim();
    await StorageService.setString(AppConstants.keyApiUrl, url);
    await ref.read(authProvider.notifier).signIn(key);
    if (mounted) setState(() => _loading = false);
  }

  // ── Import session ─────────────────────────────────────────────────────────
  Future<void> _importSession() async {
    final url = _urlCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
    final key = _keyCtrl.text.trim();

    if (url.isEmpty || !url.startsWith('http')) {
      _setImportMsg("Entre d'abord l'URL du serveur", false);
      return;
    }
    if (key.length < 8) {
      _setImportMsg("Entre d'abord la clé API (wbk_...)", false);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'wabot'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      _setImportMsg('Impossible de lire le fichier', false);
      return;
    }

    setState(() { _importing = true; _importMsg = null; });

    try {
      final Map<String, dynamic> data = jsonDecode(utf8.decode(bytes));
      if (data['files'] == null) {
        _setImportMsg('Fichier de session invalide (clé "files" manquante)', false);
        return;
      }

      final dio = Dio(BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': key,
        },
      ));

      final resp = await dio.post('/api/v1/session/import', data: data);
      final ok = resp.data['success'] == true;
      _setImportMsg(
        ok
          ? '✅ Session importée ! Le bot redémarre — attends 5s puis connecte-toi.'
          : resp.data['error'] ?? 'Erreur inconnue',
        ok,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? e.message ?? 'Connexion impossible';
      _setImportMsg('Erreur : $msg', false);
    } catch (e) {
      _setImportMsg('Erreur : $e', false);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _setImportMsg(String msg, bool ok) {
    if (mounted) setState(() { _importMsg = msg; _importOk = ok; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0C0F), Color(0xFF0D1117)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const WabotLogoWidget(size: 76, radius: 22, iconSize: 36),
                  const SizedBox(height: 18),
                  const Text(AppConfig.appName,
                    style: TextStyle(color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('by ${AppConfig.company}',
                    style: TextStyle(color: Colors.white.withOpacity(.3),
                      fontSize: 12, letterSpacing: .8)),
                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111316),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1E2128)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                      // URL du serveur
                      Text('URL du serveur',
                        style: TextStyle(color: Colors.white.withOpacity(.8),
                          fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _urlCtrl,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(color: Colors.white, fontSize: 14,
                          fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'http://localhost:3001',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(.28),
                            fontFamily: 'monospace'),
                          filled: true,
                          fillColor: const Color(0xFF0D0E11),
                          prefixIcon: const Icon(Icons.link_rounded, size: 17,
                            color: Color(0xFF8A9199)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: const BorderSide(color: Color(0xFF1E2128))),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: const BorderSide(color: Color(0xFF1E2128))),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: const BorderSide(color: _g, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'URL requise';
                          if (!v.trim().startsWith('http')) return 'Doit commencer par http:// ou https://';
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // Clé API
                      Text('Clé API (X-API-Key)',
                        style: TextStyle(color: Colors.white.withOpacity(.8),
                          fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _keyCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'wbk_••••••••••••••••',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(.28)),
                          filled: true,
                          fillColor: const Color(0xFF0D0E11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: const BorderSide(color: Color(0xFF1E2128))),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: const BorderSide(color: Color(0xFF1E2128))),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: const BorderSide(color: _g, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined
                                       : Icons.visibility_off_outlined,
                              size: 18, color: Colors.white30),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Clé API requise';
                          if (v.trim().length < 8) return 'Clé trop courte (min. 8 caractères)';
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),

                      const SizedBox(height: 10),

                      // Info hint
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _g.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _g.withOpacity(0.15))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.info_outline_rounded, size: 13,
                            color: _g.withOpacity(0.7)),
                          const SizedBox(width: 7),
                          Expanded(child: Text(
                            'La clé API apparaît dans les logs wabot au démarrage (format : wbk_xxx…)',
                            style: TextStyle(color: _g.withOpacity(0.7), fontSize: 11))),
                        ]),
                      ),

                      // Message import session
                      if (_importMsg != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: (_importOk ? _g : const Color(0xFFFF5B5B)).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_importOk ? _g : const Color(0xFFFF5B5B)).withOpacity(0.25))),
                          child: Text(_importMsg!,
                            style: TextStyle(
                              color: _importOk ? _g : const Color(0xFFFF5B5B),
                              fontSize: 12)),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Bouton connexion
                      SizedBox(height: 46, child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _g,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                          : const Text('Continuer',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      )),

                      const SizedBox(height: 10),

                      // Bouton importer session
                      SizedBox(height: 44, child: OutlinedButton.icon(
                        onPressed: (_importing || _loading) ? null : _importSession,
                        icon: _importing
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _g))
                          : const Icon(Icons.file_download_outlined, size: 18, color: _g),
                        label: Text(
                          _importing ? 'Import en cours…' : 'Importer une session',
                          style: const TextStyle(color: _g, fontWeight: FontWeight.w600, fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _g, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )),
                    ]),
                  ),

                  const SizedBox(height: 28),
                  Text('© ${DateTime.now().year} ${AppConfig.company}',
                    style: TextStyle(color: Colors.white.withOpacity(.18), fontSize: 11)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
