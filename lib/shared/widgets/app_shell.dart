import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'app_sidebar.dart';
import '../../core/constants/app_constants.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    final isMobile = ResponsiveBreakpoints.of(context).smallerThan(TABLET);
    final collapsed = ref.watch(sidebarCollapsedProvider);

    if (isMobile) {
      return Scaffold(
        body: child,
        bottomNavigationBar: const AppBottomNav(),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            collapsed: !isDesktop || collapsed,
            onToggle: () => ref.read(sidebarCollapsedProvider.notifier).state = !collapsed,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const PageHeader({super.key, required this.title, this.subtitle, this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: -0.5)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (actions != null) Row(children: actions!),
        ],
      ),
    );
  }
}
