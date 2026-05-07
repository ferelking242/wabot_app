import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';
import '../../theme/app_colors.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

final _navItems = <NavItem>[
  const NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', route: AppConstants.routeDashboard),
  const NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Chats', route: AppConstants.routeChats),
  const NavItem(icon: Icons.devices_outlined, activeIcon: Icons.devices, label: 'Devices', route: AppConstants.routeDevices),
  const NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Analytics', route: AppConstants.routeAnalytics),
  const NavItem(icon: Icons.terminal_outlined, activeIcon: Icons.terminal, label: 'Logs', route: AppConstants.routeLogs),
  const NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: 'Automation', route: AppConstants.routeAutomation),
];

class AppSidebar extends StatelessWidget {
  final bool collapsed;
  final VoidCallback? onToggle;

  const AppSidebar({super.key, this.collapsed = false, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final width = collapsed ? AppConstants.sidebarCollapsedWidth : AppConstants.sidebarWidth;

    return AnimatedContainer(
      duration: 220.ms,
      curve: Curves.easeInOut,
      width: width,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Column(
        children: [
          _SidebarHeader(collapsed: collapsed, onToggle: onToggle),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _navItems.length,
              itemBuilder: (context, i) {
                final item = _navItems[i];
                final active = location == item.route || (item.route != '/' && location.startsWith(item.route));
                return _NavTile(item: item, active: active, collapsed: collapsed, index: i);
              },
            ),
          ),
          const Divider(height: 1),
          _SidebarFooter(collapsed: collapsed),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final bool collapsed;
  final VoidCallback? onToggle;

  const _SidebarHeader({required this.collapsed, this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.black, size: 16),
            ),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Wabot',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.menu, size: 18),
                onPressed: onToggle,
                color: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ] else ...[
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.menu, size: 18),
                onPressed: onToggle,
                color: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final NavItem item;
  final bool active;
  final bool collapsed;
  final int index;

  const _NavTile({required this.item, required this.active, required this.collapsed, required this.index});

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;

    return Tooltip(
      message: widget.collapsed ? widget.item.label : '',
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => context.go(widget.item.route),
          child: AnimatedContainer(
            duration: 150.ms,
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: EdgeInsets.symmetric(
              horizontal: widget.collapsed ? 0 : 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accentSurface
                  : _hovered
                      ? AppColors.surfaceHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: active ? Border.all(color: AppColors.accentBorder) : null,
            ),
            child: Row(
              mainAxisAlignment: widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  active ? widget.item.activeIcon : widget.item.icon,
                  size: 18,
                  color: active ? AppColors.accent : (_hovered ? AppColors.textPrimary : AppColors.textSecondary),
                ),
                if (!widget.collapsed) ...[
                  const SizedBox(width: 10),
                  Text(
                    widget.item.label,
                    style: TextStyle(
                      color: active ? AppColors.accent : (_hovered ? AppColors.textPrimary : AppColors.textSecondary),
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 40 * widget.index))
        .fadeIn(duration: 250.ms)
        .slideX(begin: -0.05, end: 0, duration: 250.ms);
  }
}

class _SidebarFooter extends StatelessWidget {
  final bool collapsed;

  const _SidebarFooter({required this.collapsed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.go(AppConstants.routeSettings),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.settings_outlined, size: 18, color: AppColors.textSecondary),
              ),
            ),
            if (!collapsed) ...[
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Settings',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        currentIndex: _getIndex(location),
        onTap: (i) => context.go(_navItems[i].route),
        items: _navItems.take(5).map((item) => BottomNavigationBarItem(
          icon: Icon(item.icon, size: 22),
          activeIcon: Icon(item.activeIcon, size: 22),
          label: item.label,
        )).toList(),
      ),
    );
  }

  int _getIndex(String location) {
    for (int i = 0; i < _navItems.length; i++) {
      if (_navItems[i].route == location || (location.startsWith(_navItems[i].route) && _navItems[i].route != '/')) {
        return i;
      }
    }
    return 0;
  }
}
