import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../core/config/app_config.dart';
import 'splash_screen.dart' show WabotLogoWidget;

const _g  = Color(0xFF25D366);
const _gd = Color(0xFF128C7E);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final _ctrl = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = false, _obscure = true;

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).signIn(_ctrl.text.trim());
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0A0C0F), Color(0xFF0D1117)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
            child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
              const WabotLogoWidget(size: 76, radius: 22, iconSize: 36),
              const SizedBox(height: 18),
              const Text(AppConfig.appName, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('by ${AppConfig.company}', style: TextStyle(color: Colors.white.withOpacity(.3), fontSize: 12, letterSpacing: .8)),
              const SizedBox(height: 30),
              Container(padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF111316),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1E2128)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Clé API', style: TextStyle(color: Colors.white.withOpacity(.8), fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ctrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Votre clé API Wabot',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(.28)),
                      filled: true, fillColor: const Color(0xFF0D0E11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFF1E2128))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFF1E2128))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _g, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: Colors.white30),
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
                  const SizedBox(height: 18),
                  SizedBox(height: 46, child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _g, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Se connecter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  )),
                ])),
              const SizedBox(height: 28),
              Text('© ${DateTime.now().year} ${AppConfig.company}',
                style: TextStyle(color: Colors.white.withOpacity(.18), fontSize: 11)),
            ])),
          ),
        )),
      ),
    );
  }
}
