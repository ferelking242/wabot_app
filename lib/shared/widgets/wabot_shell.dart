import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../desktop_shell/desktop_shell.dart';
import '../mobile_shell/mobile_shell.dart';
import '../widgets/responsive_role_shell.dart' show RoleNavEntry;
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/sessions/presentation/sessions_screen.dart';
import '../../features/chats/presentation/chats_screen.dart';
import '../../features/logs/presentation/logs_screen.dart';
import '../../features/automation/presentation/automation_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/commands/presentation/commands_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/docs/presentation/docs_screen.dart';
import '../../shared/pages/settings_page.dart';

class WabotShell extends StatelessWidget {
  const WabotShell({super.key});

  static final _groups = [
    DesktopNavGroup(labelKey: 'principal', items: const [
      DesktopNavItem(icon: Icons.dashboard_outlined,     labelKey: 'Dashboard',   page: DashboardScreen()),
      DesktopNavItem(icon: Icons.phone_android_outlined, labelKey: 'Sessions',    page: SessionsScreen()),
      DesktopNavItem(icon: Icons.chat_outlined,          labelKey: 'Chats',       page: ChatsScreen()),
      DesktopNavItem(icon: Icons.groups_outlined,        labelKey: 'Groupes',     page: GroupsScreen()),
      DesktopNavItem(icon: Icons.receipt_long_outlined,  labelKey: 'Logs',        page: LogsScreen()),
    ]),
    DesktopNavGroup(labelKey: 'bot', items: const [
      DesktopNavItem(icon: Icons.terminal_outlined,      labelKey: 'Commandes',   page: CommandsScreen()),
      DesktopNavItem(icon: Icons.book_outlined,          labelKey: 'Docs',        page: DocsScreen()),
      DesktopNavItem(icon: Icons.bar_chart_outlined,     labelKey: 'Analytics',   page: AnalyticsScreen()),
      DesktopNavItem(icon: Icons.auto_fix_high_outlined, labelKey: 'Automation',  page: AutomationScreen()),
      DesktopNavItem(icon: Icons.settings_outlined,      labelKey: 'Paramètres',  page: SettingsPage()),
    ]),
  ];

  static const _dock = [
    RoleNavEntry(icon: Icons.dashboard_outlined,     labelKey: 'Dashboard',  page: DashboardScreen()),
    RoleNavEntry(icon: Icons.chat_outlined,          labelKey: 'Chats',      page: ChatsScreen()),
    RoleNavEntry(icon: Icons.groups_outlined,        labelKey: 'Groupes',    page: GroupsScreen()),
    RoleNavEntry(icon: Icons.book_outlined,          labelKey: 'Docs',       page: DocsScreen()),
  ];

  static const _drawer = [
    RoleNavEntry(icon: Icons.dashboard_outlined,     labelKey: 'Dashboard',   page: DashboardScreen()),
    RoleNavEntry(icon: Icons.phone_android_outlined, labelKey: 'Sessions',    page: SessionsScreen()),
    RoleNavEntry(icon: Icons.chat_outlined,          labelKey: 'Chats',       page: ChatsScreen()),
    RoleNavEntry(icon: Icons.groups_outlined,        labelKey: 'Groupes',     page: GroupsScreen()),
    RoleNavEntry(icon: Icons.receipt_long_outlined,  labelKey: 'Logs',        page: LogsScreen()),
    RoleNavEntry(icon: Icons.terminal_outlined,      labelKey: 'Commandes',   page: CommandsScreen()),
    RoleNavEntry(icon: Icons.book_outlined,          labelKey: 'Docs',        page: DocsScreen()),
    RoleNavEntry(icon: Icons.bar_chart_outlined,     labelKey: 'Analytics',   page: AnalyticsScreen()),
    RoleNavEntry(icon: Icons.auto_fix_high_outlined, labelKey: 'Automation',  page: AutomationScreen()),
    RoleNavEntry(icon: Icons.settings_outlined,      labelKey: 'Paramètres',  page: SettingsPage()),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
    if (isDesktop) {
      return DesktopShell(title: 'Wabot', groups: _groups);
    }
    return MobileShell(title: 'Wabot', dockEntries: _dock, drawerEntries: _drawer);
  }
}
