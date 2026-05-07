import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/storage_service.dart';
import '../../../theme/app_colors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.lock, color: Colors.black, size: 22),
                ).animate().scale(begin: const Offset(0.8, 0.8), duration: 400.ms, curve: Curves.elasticOut),

                const SizedBox(height: 24),
                Text('Enter PIN', style: theme.textTheme.headlineSmall).animate(delay: 100.ms).fadeIn(),
                const SizedBox(height: 6),
                Text('Access your Wabot dashboard', style: theme.textTheme.bodyMedium).animate(delay: 150.ms).fadeIn(),
                const SizedBox(height: 32),

                TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 12),
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '• • • • • •',
                    counterText: '',
                    errorText: _error,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 300.ms),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _unlock,
                    child: const Text('Unlock'),
                  ),
                ).animate(delay: 300.ms).fadeIn(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _unlock() {
    final pin = StorageService.getString(AppConstants.keyAuthPin);
    if (pin == null || pin == _controller.text) {
      if (pin == null) {
        StorageService.setString(AppConstants.keyAuthPin, _controller.text);
      }
      context.go(AppConstants.routeDashboard);
    } else {
      setState(() => _error = 'Incorrect PIN');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
