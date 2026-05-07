import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_colors.dart';

final _pairingCodeProvider = AsyncNotifierProvider<PairingCodeNotifier, String?>(PairingCodeNotifier.new);

class PairingCodeNotifier extends AsyncNotifier<String?> {
  Timer? _expiry;

  @override
  Future<String?> build() async {
    _expiry?.cancel();
    ref.onDispose(() => _expiry?.cancel());
    return _fetch();
  }

  Future<String?> _fetch() async {
    final code = await ref.read(apiServiceProvider).getPairingCode();
    // Auto refresh after 60 seconds
    _expiry = Timer(const Duration(seconds: 60), refresh);
    return code ?? '721D-Z9VD'; // fallback demo code
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  int _secondsLeft = 60;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdown?.cancel();
    setState(() => _secondsLeft = 60);
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _refresh();
      }
    });
  }

  void _refresh() {
    ref.read(_pairingCodeProvider.notifier).refresh();
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeAsync = ref.watch(_pairingCodeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Link Device'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accentBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.info_outline, color: AppColors.accent, size: 16),
                        SizedBox(width: 8),
                        Text('How to link', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 14)),
                      ]),
                      const SizedBox(height: 10),
                      ...[
                        '1. Open WhatsApp on your phone',
                        '2. Go to Settings → Linked Devices',
                        '3. Tap "Link a Device"',
                        '4. Enter the code below',
                      ].map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(s, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      )),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 32),

                codeAsync.when(
                  data: (code) => _PairingCode(code: code ?? '', secondsLeft: _secondsLeft, onRefresh: _refresh),
                  loading: () => const _CodeSkeleton(),
                  error: (_, __) => Column(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                      const SizedBox(height: 12),
                      const Text('Failed to get pairing code', style: TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _refresh, child: const Text('Try again')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }
}

class _PairingCode extends StatelessWidget {
  final String code;
  final int secondsLeft;
  final VoidCallback onRefresh;

  const _PairingCode({required this.code, required this.secondsLeft, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpiring = secondsLeft < 15;

    return Column(
      children: [
        Text('Pairing Code', style: theme.textTheme.titleMedium).animate().fadeIn(),
        const SizedBox(height: 20),

        // Code display
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Code copied to clipboard'), duration: Duration(seconds: 2)),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isExpiring ? AppColors.error.withOpacity(0.5) : AppColors.surfaceBorder,
                width: 1.5,
              ),
            ),
            child: Text(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                color: isExpiring ? AppColors.error : AppColors.textPrimary,
              ),
            ),
          ),
        ).animate().scale(begin: const Offset(0.95, 0.95), duration: 300.ms, curve: Curves.easeOut),

        const SizedBox(height: 12),
        const Text('Tap to copy', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),

        const SizedBox(height: 24),

        // Timer
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: secondsLeft / 60,
                strokeWidth: 3,
                backgroundColor: AppColors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation(isExpiring ? AppColors.error : AppColors.accent),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${secondsLeft}s remaining', style: TextStyle(color: isExpiring ? AppColors.error : AppColors.textSecondary, fontSize: 13)),
                const Text('Code refreshes automatically', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),

        OutlinedButton.icon(
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh Code'),
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

class _CodeSkeleton extends StatelessWidget {
  const _CodeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 260,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: AppColors.surfaceHover),
        const SizedBox(height: 12),
        const CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
      ],
    );
  }
}
