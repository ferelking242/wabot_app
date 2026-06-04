import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class WNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const WNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

class WNavGroup {
  final String label;
  final List<WNavItem> items;
  const WNavGroup({required this.label, required this.items});
}

const kNavGroups = [
  WNavGroup(label: 'BOT', items: [
    WNavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
      route: AppConstants.routeDashboard,
    ),
    WNavItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chats',
      route: AppConstants.routeChats,
    ),
    WNavItem(
      icon: Icons.devices_outlined,
      activeIcon: Icons.devices_rounded,
      label: 'Devices',
      route: AppConstants.routeDevices,
    ),
  ]),
  WNavGroup(label: 'MONITORING', items: [
    WNavItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Analytics',
      route: AppConstants.routeAnalytics,
    ),
    WNavItem(
      icon: Icons.terminal_outlined,
      activeIcon: Icons.terminal_rounded,
      label: 'Logs',
      route: AppConstants.routeLogs,
    ),
    WNavItem(
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome_rounded,
      label: 'Automation',
      route: AppConstants.routeAutomation,
    ),
  ]),
];

List<WNavItem> get kAllNavItems => [
  for (final g in kNavGroups) ...g.items,
];
