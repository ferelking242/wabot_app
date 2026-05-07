import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../main.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../theme/app_colors.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiUrlController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _apiUrlController.text = StorageService.getString(AppConstants.keyApiUrl) ?? AppConstants.defaultApiUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: PageHeader(title: 'Settings', subtitle: 'Configure your dashboard'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Appearance
                _Section(
                  title: 'Appearance',
                  index: 0,
                  children: [
                    _SettingRow(
                      label: 'Theme',
                      subtitle: 'Choose light, dark or system theme',
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 14), label: Text('Dark', style: TextStyle(fontSize: 12))),
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 14), label: Text('Light', style: TextStyle(fontSize: 12))),
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.auto_mode, size: 14), label: Text('System', style: TextStyle(fontSize: 12))),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (s) {
                          final mode = s.first;
                          ref.read(themeModeProvider.notifier).state = mode;
                          StorageService.setString(AppConstants.keyThemeMode, mode.name);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Connection
                _Section(
                  title: 'Connection',
                  index: 1,
                  children: [
                    _SettingRow(
                      label: 'Bot API URL',
                      subtitle: 'The URL where your wabot server is running',
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _apiUrlController,
                              decoration: const InputDecoration(
                                hintText: 'http://localhost:3001',
                                isDense: true,
                                prefixIcon: Icon(Icons.link, size: 16),
                              ),
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saving ? null : _saveApiUrl,
                            child: _saving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      label: 'Test Connection',
                      subtitle: 'Verify your bot API is reachable',
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.wifi_tethering, size: 16),
                        label: const Text('Test'),
                        onPressed: _testConnection,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Security
                _Section(
                  title: 'Security',
                  index: 2,
                  children: [
                    _SettingRow(
                      label: 'Dashboard PIN',
                      subtitle: 'Set a PIN to protect access to this dashboard',
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.lock_outline, size: 16),
                        label: const Text('Change PIN'),
                        onPressed: () => _showChangePinDialog(context),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // About
                _Section(
                  title: 'About',
                  index: 3,
                  children: [
                    _SettingRow(
                      label: 'Version',
                      subtitle: 'Wabot Dashboard',
                      child: Text(AppConstants.appVersion, style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'monospace', fontSize: 13)),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      label: 'Source',
                      subtitle: 'View on GitHub',
                      child: TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('GitHub'),
                        onPressed: () {},
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingRow(
                      label: 'Reset',
                      subtitle: 'Clear all local data and settings',
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                        onPressed: () => _showResetDialog(context),
                        child: const Text('Reset App'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveApiUrl() async {
    setState(() => _saving = true);
    final url = _apiUrlController.text.trim();
    await StorageService.setString(AppConstants.keyApiUrl, url);
    ref.read(apiServiceProvider).updateBaseUrl(url);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API URL saved successfully')),
      );
    }
  }

  Future<void> _testConnection() async {
    final api = ref.read(apiServiceProvider);
    try {
      final status = await api.getBotStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected! Bot status: ${status['status']}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showChangePinDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change PIN'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: 'Enter new PIN (4-6 digits)', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.length >= 4) {
                StorageService.setString(AppConstants.keyAuthPin, ctrl.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN updated')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text('This will clear all settings and cached data. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              await StorageService.clear();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final int index;

  const _Section({required this.title, required this.children, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.textTertiary, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(children: children),
        ),
      ],
    )
        .animate(delay: Duration(milliseconds: 80 * index))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.05, end: 0, duration: 300.ms);
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final Widget child;

  const _SettingRow({required this.label, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 16),
          child,
        ],
      ),
    );
  }
}
