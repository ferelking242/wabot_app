import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'desktop_shell.dart';
import 'mobile_shell.dart';

final sidebarCollapsedProvider = ValueNotifier<bool>(false);

const double kBreakpointMobile = 720;

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= kBreakpointMobile) {
      return WabotDesktopShell(child: child);
    }
    return WabotMobileShell(child: child);
  }
}

// ── Page Header — used by all feature screens ─────────────────────────────
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const PageHeader({super.key, required this.title, this.subtitle, this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null)
            Row(mainAxisSize: MainAxisSize.min, children: actions!),
        ],
      ),
    );
  }
}

// ── AppBottomNav — kept for backward compat (not shown in new shell) ──────
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
