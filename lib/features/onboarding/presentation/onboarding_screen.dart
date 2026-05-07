import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/storage_service.dart';
import '../../../theme/app_colors.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _apiController = TextEditingController(text: AppConstants.defaultApiUrl);
  bool _loading = false;

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

                Text('Welcome to Wabot', style: theme.textTheme.displaySmall?.copyWith(letterSpacing: -1))
                    .animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

                const SizedBox(height: 8),

                Text(
                  'Your premium WhatsApp bot dashboard. Connect to your bot instance to get started.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.6),
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 40),

                Text('Bot API URL', style: theme.textTheme.labelLarge).animate(delay: 300.ms).fadeIn(),

                const SizedBox(height: 8),

                TextField(
                  controller: _apiController,
                  decoration: const InputDecoration(
                    hintText: 'http://localhost:3001',
                    prefixIcon: Icon(Icons.link, size: 18),
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                ).animate(delay: 350.ms).fadeIn(duration: 400.ms),

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
                          'You can change this later in Settings. Leave the default if running locally.',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _continue,
                    child: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Get Started'),
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
    await StorageService.setString(AppConstants.keyApiUrl, _apiController.text.trim());
    await StorageService.setBool(AppConstants.keyOnboardingDone, true);
    if (mounted) context.go(AppConstants.routeDashboard);
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }
}
