import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../theme/app_colors.dart';
import 'nav_config.dart';

// ── Design tokens ────────────────────────────────────────────────────────────
const _sh1    = Color(0xFF0A0C0F);
const _sh2    = Color(0xFF121417);
const _shTxt  = AppColors.textPrimary;
const _shMute = AppColors.textSecondary;
const _accent = AppColors.accent;
const _bg     = AppColors.background;

enum _SideMode { full, icons }

class WabotDesktopShell extends StatefulWidget {
  final Widget child;
  const WabotDesktopShell({super.key, required this.child});

  @override
  State<WabotDesktopShell> createState() => _WabotDesktopShellState();
}

class _WabotDesktopShellState extends State<WabotDesktopShell> {
  _SideMode _mode = _SideMode.full;

  bool get _collapsed => _mode == _SideMode.icons;
  double get _sideW   => _collapsed ? 56.0 : 220.0;

  void _toggle() => setState(() {
    _mode = _collapsed ? _SideMode.full : _SideMode.icons;
  });

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: _sh1,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Sidebar ───────────────────────────────────────────────────
            AnimatedContainer(
              duration: 230.ms,
              curve: Curves.easeInOut,
              width: _sideW,
              child: _DesktopSidebar(
                collapsed: _collapsed,
                currentRoute: location,
                onToggle: _toggle,
              ),
            ),

            // ── Main column: header + content ─────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DesktopHeader(
                    mode: _mode,
                    onToggle: _toggle,
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                      ),
                      child: Container(
                        color: _bg,
                        child: widget.child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopSidebar extends StatefulWidget {
  final bool collapsed;
  final String currentRoute;
  final VoidCallback onToggle;

  const _DesktopSidebar({
    required this.collapsed,
    required this.currentRoute,
    required this.onToggle,
  });

  @override
  State<_DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<_DesktopSidebar> {
  final Set<int> _closedGroups = {};

  int _flatIndex(int gIdx, int iIdx) {
    int f = 0;
    for (var i = 0; i < gIdx; i++) f += kNavGroups[i].items.length;
    return f + iIdx;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_sh1, _sh2],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // ── Logo ─────────────────────────────────────────────────────────
          SizedBox(
            height: 64,
            child: Center(
              child: AnimatedSwitcher(
                duration: 180.ms,
                child: widget.collapsed
                    ? _WabotLogo(size: 32, key: const ValueKey('icon'))
                    : Row(
                        key: const ValueKey('full'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _WabotLogo(size: 30),
                          const SizedBox(width: 10),
                          const Text(
                            'Wabot',
                            style: TextStyle(
                              color: _shTxt,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          Container(height: 1, color: Colors.white.withOpacity(.07)),

          // ── Nav groups ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: widget.collapsed ? 6 : 8,
                vertical: 6,
              ),
              children: [
                for (var g = 0; g < kNavGroups.length; g++) ...[
                  if (!widget.collapsed)
                    GestureDetector(
                      onTap: () => setState(() {
                        if (_closedGroups.contains(g)) {
                          _closedGroups.remove(g);
                        } else {
                          _closedGroups.add(g);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 8, 6),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              kNavGroups[g].label,
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.2,
                                color: _accent.withOpacity(.55),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            _closedGroups.contains(g)
                                ? Icons.expand_more_rounded
                                : Icons.expand_less_rounded,
                            size: 13,
                            color: _accent.withOpacity(.4),
                          ),
                        ]),
                      ),
                    )
                  else
                    const SizedBox(height: 10),

                  if (widget.collapsed || !_closedGroups.contains(g))
                    ...List.generate(kNavGroups[g].items.length, (i) {
                      final item = kNavGroups[g].items[i];
                      final active = widget.currentRoute == item.route ||
                          (item.route != '/' && widget.currentRoute.startsWith(item.route));
                      return _SideItem(
                        item: item,
                        selected: active,
                        collapsed: widget.collapsed,
                        onTap: () => context.go(item.route),
                      );
                    }),
                ],
              ],
            ),
          ),

          // ── Footer ───────────────────────────────────────────────────────
          Container(height: 1, color: Colors.white.withOpacity(.07)),
          _SidebarFooter(
            collapsed: widget.collapsed,
            currentRoute: widget.currentRoute,
          ),
        ],
      ),
    );
  }
}

class _SideItem extends StatefulWidget {
  final WNavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _SideItem({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    return Tooltip(
      message: widget.collapsed ? widget.item.label : '',
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: 140.ms,
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: EdgeInsets.symmetric(
              horizontal: widget.collapsed ? 0 : 10,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: active
                  ? _accent.withOpacity(.12)
                  : _hovered
                      ? Colors.white.withOpacity(.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: active
                  ? Border.all(color: _accent.withOpacity(.25))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: widget.collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  active ? widget.item.activeIcon : widget.item.icon,
                  size: 18,
                  color: active
                      ? _accent
                      : _hovered
                          ? _shTxt
                          : _shMute,
                ),
                if (!widget.collapsed) ...[
                  const SizedBox(width: 10),
                  Text(
                    widget.item.label,
                    style: TextStyle(
                      color: active
                          ? _accent
                          : _hovered
                              ? _shTxt
                              : _shMute,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatefulWidget {
  final bool collapsed;
  final String currentRoute;
  const _SidebarFooter({required this.collapsed, required this.currentRoute});

  @override
  State<_SidebarFooter> createState() => _SidebarFooterState();
}

class _SidebarFooterState extends State<_SidebarFooter> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.currentRoute == AppConstants.routeSettings;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.collapsed ? 6 : 8,
          vertical: 6,
        ),
        child: Tooltip(
          message: widget.collapsed ? 'Settings' : '',
          preferBelow: false,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: () => context.go(AppConstants.routeSettings),
              child: AnimatedContainer(
                duration: 140.ms,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 0 : 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? _accent.withOpacity(.12)
                      : _hovered
                          ? Colors.white.withOpacity(.06)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: active
                      ? Border.all(color: _accent.withOpacity(.25))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: widget.collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(
                      active
                          ? Icons.settings_rounded
                          : Icons.settings_outlined,
                      size: 18,
                      color: active
                          ? _accent
                          : _hovered
                              ? _shTxt
                              : _shMute,
                    ),
                    if (!widget.collapsed) ...[
                      const SizedBox(width: 10),
                      Text(
                        'Settings',
                        style: TextStyle(
                          color: active
                              ? _accent
                              : _hovered
                                  ? _shTxt
                                  : _shMute,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop Header
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopHeader extends StatefulWidget {
  final _SideMode mode;
  final VoidCallback onToggle;

  const _DesktopHeader({required this.mode, required this.onToggle});

  @override
  State<_DesktopHeader> createState() => _DesktopHeaderState();
}

class _DesktopHeaderState extends State<_DesktopHeader> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchActive = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_sh1, _sh2],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Toggle button
          _DarkHeaderBtn(
            icon: widget.mode == _SideMode.full
                ? Icons.menu_open_rounded
                : Icons.menu_rounded,
            tooltip: widget.mode == _SideMode.full ? 'Réduire' : 'Étendre',
            onTap: widget.onToggle,
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 18, color: Colors.white.withOpacity(.1)),
          const SizedBox(width: 12),

          // Search bar
          AnimatedContainer(
            duration: 200.ms,
            width: _searchActive ? 260 : 200,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white
                  .withOpacity(_searchActive ? .10 : .06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _searchActive
                    ? _accent.withOpacity(.35)
                    : Colors.white.withOpacity(.08),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 9),
                Icon(Icons.search_rounded,
                    size: 14, color: _shMute.withOpacity(.7)),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onTap: () => setState(() => _searchActive = true),
                    onTapOutside: (_) {
                      _searchFocus.unfocus();
                      setState(() => _searchActive = false);
                    },
                    style: const TextStyle(fontSize: 12.5, color: _shTxt),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Rechercher…',
                      hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: _shMute.withOpacity(.6)),
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (!_searchActive)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('⌘K',
                        style: TextStyle(
                            fontSize: 10,
                            color: _shMute.withOpacity(.7))),
                  )
                else
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      _searchFocus.unfocus();
                      setState(() => _searchActive = false);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.close_rounded,
                          size: 13, color: _shMute),
                    ),
                  ),
              ],
            ),
          ),

          const Spacer(),

          // Status indicator
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withOpacity(.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withOpacity(.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: _accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text('Bot en ligne',
                  style: TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 18, color: Colors.white.withOpacity(.1)),
          const SizedBox(width: 12),

          // Notification
          _DarkHeaderBtn(
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            badge: true,
            onTap: () {},
          ),
          const SizedBox(width: 4),

          // Avatar
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accent, Color(0xFF1AAD4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                    color: _accent.withOpacity(.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: const Center(
              child: Icon(Icons.smart_toy_rounded,
                  color: Colors.black, size: 16),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _DarkHeaderBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool badge;
  final VoidCallback onTap;

  const _DarkHeaderBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = false,
  });

  @override
  State<_DarkHeaderBtn> createState() => _DarkHeaderBtnState();
}

class _DarkHeaderBtnState extends State<_DarkHeaderBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: 120.ms,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white.withOpacity(.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(widget.icon,
                      size: 18,
                      color: _hovered ? _shTxt : _shMute),
                ),
                if (widget.badge)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: _accent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo Widget
// ─────────────────────────────────────────────────────────────────────────────
class _WabotLogo extends StatelessWidget {
  final double size;
  const _WabotLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_accent, Color(0xFF1AAD4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
              color: _accent.withOpacity(.35),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Center(
        child: Icon(Icons.smart_toy_rounded,
            color: Colors.black, size: size * 0.52),
      ),
    );
  }
}
