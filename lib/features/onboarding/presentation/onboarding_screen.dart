import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../presentation/providers/auth_providers.dart';
import '../../../services/storage_service.dart';
import '../../../theme/app_colors.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _urlController  = TextEditingController(text: AppConstants.defaultApiUrl);
  final _keyController  = TextEditingController();
  bool _loading         = false;
  bool _showKey         = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.smart_toy, color: Colors.black, size: 28),
                ).animate().scale(begin: const Offset(0.8, 0.8), duration: 400.ms, curve: Curves.elasticOut),

                const SizedBox(height: 28),

                Text('Bienvenue sur Wabot',
                    style: theme.textTheme.displaySmall?.copyWith(letterSpacing: -1))
                    .animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 8),

                Text(
                  'Connectez-vous à votre instance wabot pour gérer votre bot WhatsApp.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.6),
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 40),

                // URL field
                Text('URL du serveur wabot', style: theme.textTheme.labelLarge)
                    .animate(delay: 300.ms).fadeIn(),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'http://localhost:3001',
                    prefixIcon: Icon(Icons.link, size: 18),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  keyboardType: TextInputType.url,
                ).animate(delay: 340.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 20),

                // API Key field
                Text('Clé API (X-API-Key)', style: theme.textTheme.labelLarge)
                    .animate(delay: 380.ms).fadeIn(),
                const SizedBox(height: 8),
                TextField(
                  controller: _keyController,
                  obscureText: !_showKey,
                  decoration: InputDecoration(
                    hintText: 'wbk_••••••••••••••••',
                    prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility, size: 18),
                      onPressed: () => setState(() => _showKey = !_showKey),
                    ),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                ).animate(delay: 400.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.accent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'La clé API apparaît dans les logs de wabot au démarrage. '
                          'Format : wbk_xxxxxxxxxxxxxxxx',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 430.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _continue,
                    child: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Continuer'),
                  ),
                ).animate(delay: 500.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continue() async {
    setState(() => _loading = true);
    final url = _urlController.text.trim().replaceAll(RegExp(r'/$'), '');
    final key = _keyController.text.trim();
    await StorageService.setString(AppConstants.keyApiUrl, url);
    if (key.isNotEmpty) {
      // signIn saves to SharedPreferences AND updates authProvider state →
      // triggers GoRouter refresh → redirects to /pair automatically
      await ref.read(authProvider.notifier).signIn(key);
    }
    await StorageService.setBool(AppConstants.keyOnboardingDone, true);
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }
}
