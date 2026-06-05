import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../desktop_shell/desktop_shell.dart';
import '../mobile_shell/mobile_shell.dart';

export '../desktop_shell/desktop_shell.dart' show DesktopNavGroup, DesktopNavItem;

class RoleNavEntry {
  final IconData icon;
  final IconData? activeIcon;
  final String labelKey;
  final Widget page;
  const RoleNavEntry({required this.icon, this.activeIcon, required this.labelKey, required this.page});
}

class RoleNavGroup {
  final String labelKey;
  final List<RoleNavEntry> entries;
  const RoleNavGroup({required this.labelKey, required this.entries});
}
