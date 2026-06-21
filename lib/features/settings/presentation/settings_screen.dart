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

  // Update state
  bool _updateChecking = false;
  bool _updateApplying = false;
  Map<String, dynamic>? _updateInfo;
  String? _updateError;

  @override
  void initState() {
    super.initState();
    _apiUrlController.text = StorageService.getString(AppConstants.keyApiUrl) ?? AppConstants.defaultApiUrl;
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    setState(() { _updateChecking = true; _updateError = null; });
    try {
      final api  = ref.read(apiServiceProvider);
      final info = await api.checkBundleUpdate();
      if (mounted) setState(() { _updateInfo = info; _updateChecking = false; });
    } catch (e) {
      if (mounted) setState(() { _updateError = e.toString(); _updateChecking = false; });
    }
  }

  Future<void> _applyUpdate() async {
    final sha = _updateInfo?['latestSha'] as String?;
    setState(() { _updateApplying = true; _updateError = null; });
    try {
      final ok = await ref.read(apiServiceProvider).applyBundleUpdate(sha);
      if (mounted) {
        setState(() { _updateApplying = false; _updateInfo = null; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? '✅ Mise à jour lancée — le bot redémarre dans ~30s' : '❌ Erreur lors de la mise à jour'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) setState(() { _updateApplying = false; _updateError = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final hasUpdate  = _updateInfo?['hasUpdate'] == true;
    final busy       = _updateChecking || _updateApplying;

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
                          ButtonSegment(value: ThemeMode.dark,   icon: Icon(Icons.dark_mode, size: 14),  label: Text('Dark',   style: TextStyle(fontSize: 12))),
                          ButtonSegment(value: ThemeMode.light,  icon: Icon(Icons.light_mode, size: 14), label: Text('Light',  style: TextStyle(fontSize: 12))),
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.auto_mode, size: 14),  label: Text('System', style: TextStyle(fontSize: 12))),
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
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
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

                // Bot Update
                _Section(
                  title: 'Bot Update',
                  index: 2,
                  children: [
                    // Status row
                    if (_updateInfo != null && _updateInfo!['error'] == null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: hasUpdate
                                  ? AppColors.warning.withOpacity(0.12)
                                  : AppColors.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: hasUpdate
                                      ? AppColors.warning.withOpacity(0.4)
                                      : AppColors.success.withOpacity(0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                hasUpdate
                                    ? Icons.system_update_alt_rounded
                                    : Icons.check_circle_outline_rounded,
                                color: hasUpdate ? AppColors.warning : AppColors.success,
                                size: 13),
                              const SizedBox(width: 6),
                              Text(
                                hasUpdate ? 'Mise à jour disponible !' : 'Bot à jour ✓',
                                style: TextStyle(
                                  color: hasUpdate ? AppColors.warning : AppColors.success,
                                  fontSize: 11, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          const Spacer(),
                          Text(
                            'Actuel: ${_short(_updateInfo!['currentSha'] as String?)}  '
                            'Dernier: ${_short(_updateInfo!['latestSha'] as String?)}',
                            style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_updateError != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 14),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_updateError!,
                              style: const TextStyle(color: AppColors.error, fontSize: 11))),
                        ]),
                      ),
                      const SizedBox(height: 8),
                    ],
                    _SettingRow(
                      label: 'Vérifier la mise à jour',
                      subtitle: 'Comparer la version installée avec GitHub',
                      child: OutlinedButton.icon(
                        icon: _updateChecking
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.search_rounded, size: 16),
                        label: Text(_updateChecking ? 'Vérification…' : 'Vérifier'),
                        onPressed: busy ? null : _checkUpdate,
                      ),
                    ),
                    if (hasUpdate) ...[
                      const Divider(height: 1),
                      _SettingRow(
                        label: 'Appliquer la mise à jour',
                        subtitle: 'Télécharger et redémarrer le bot',
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.black,
                          ),
                          icon: _updateApplying
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Icon(Icons.system_update_alt_rounded, size: 16),
                          label: Text(_updateApplying ? 'Mise à jour…' : 'Mettre à jour'),
                          onPressed: busy ? null : _applyUpdate,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Security
                _Section(
                  title: 'Security',
                  index: 3,
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
                  index: 4,
                  children: [
                    _SettingRow(
                      label: 'Version',
                      subtitle: 'Wabot Dashboard',
                      child: Text(AppConstants.appVersion,
                          style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontFamily: 'monospace', fontSize: 13)),
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
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error)),
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

  String _short(String? sha) =>
      (sha != null && sha.length >= 7) ? sha.substring(0, 7) : (sha ?? '—');

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
          SnackBar(
              content: Text('Connection failed: $e'),
              backgroundColor: AppColors.error),
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
          decoration: const InputDecoration(
              hintText: 'Enter new PIN (4-6 digits)', counterText: ''),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.length >= 4) {
                StorageService.setString(AppConstants.keyAuthPin, ctrl.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN updated')));
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
        content: const Text(
            'This will clear all settings and cached data. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
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
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final int index;

  const _Section(
      {required this.title, required this.children, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.textTertiary, letterSpacing: 0.5)),
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

  const _SettingRow(
      {required this.label, required this.subtitle, required this.child});

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
