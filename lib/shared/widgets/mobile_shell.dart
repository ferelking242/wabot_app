import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../theme/app_colors.dart';
import 'nav_config.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _pageBg  = AppColors.background;
const _sh1     = Color(0xFF0A0C0F);
const _sh2     = Color(0xFF121417);
const _shTxt   = AppColors.textPrimary;
const _shMute  = AppColors.textSecondary;
const _accent  = AppColors.accent;
const _border  = AppColors.surfaceBorder;

const double _kEdgeZone = 28.0;

class WabotMobileShell extends StatefulWidget {
  final Widget child;
  const WabotMobileShell({super.key, required this.child});

  @override
  State<WabotMobileShell> createState() => _WabotMobileShellState();
}

class _WabotMobileShellState extends State<WabotMobileShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _menuCtrl;
  late final Animation<double> _menuAnim;

  bool   _edgeDrag      = false;
  double _dragStartX    = 0;
  double _dragProgressX = 0;
  bool   _showBubble    = false;

  double _scale  = 1;
  double _xShift = 0;
  double _yShift = 0;
  double _radius = 0;

  bool get _menuOpen => _menuCtrl.value > 0.01;

  @override
  void initState() {
    super.initState();
    _menuCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _menuAnim = CurvedAnimation(
        parent: _menuCtrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
    _menuCtrl.addListener(_onAnim);
  }

  void _onAnim() {
    final t = _menuAnim.value;
    setState(() {
      _scale  = 1 - 0.10 * t;
      _xShift = 0.68 * t;
      _yShift = 0.04 * t;
      _radius = 26 * t;
    });
  }

  @override
  void dispose() {
    _menuCtrl.removeListener(_onAnim);
    _menuCtrl.dispose();
    super.dispose();
  }

  void _openMenu()  => _menuCtrl.animateTo(1);
  void _closeMenu() => _menuCtrl.animateTo(0);
  void _toggleMenu() => _menuOpen ? _closeMenu() : _openMenu();

  void _onDragStart(DragStartDetails d) {
    _dragStartX = d.localPosition.dx;
    _edgeDrag = !_menuOpen && _dragStartX < _kEdgeZone;
    if (_edgeDrag) setState(() { _showBubble = true; _dragProgressX = 0; });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final delta = d.delta.dx;
    if (_edgeDrag) {
      _dragProgressX += delta;
      _menuCtrl.value = (_dragProgressX / 220).clamp(0.0, 1.0);
    } else if (_menuOpen && delta < 0) {
      _menuCtrl.value =
          (_menuCtrl.value + delta / 260).clamp(0.0, 1.0);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    setState(() => _showBubble = false);
    final vel = d.primaryVelocity ?? 0;
    if (_edgeDrag) {
      _edgeDrag = false;
      (_menuCtrl.value > 0.42 || vel > 500) ? _openMenu() : _closeMenu();
    } else if (_menuOpen) {
      (_menuCtrl.value < 0.55 || vel < -500) ? _closeMenu() : _openMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final location = GoRouterState.of(context).uri.path;

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: _sh1,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1 ─ Drawer sidebar
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _MobileSidebarPanel(
                  currentRoute: location,
                  opacity: _menuCtrl.value,
                  width: size.width * 0.72,
                  onSelect: (route) {
                    _closeMenu();
                    context.go(route);
                  },
                  onClose: _closeMenu,
                ),
              ),
            ),

            // 2 ─ Main card with transform
            Transform(
              transform: Matrix4.identity()
                ..translate(size.width * _xShift, size.height * _yShift)
                ..scale(_scale),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: _menuOpen
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(.4),
                            blurRadius: 32,
                            offset: const Offset(-8, 0),
                          ),
                        ]
                      : [],
                ),
                child: GestureDetector(
                  onTap: _menuOpen ? _closeMenu : null,
                  behavior: HitTestBehavior.translucent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_radius),
                    child: Scaffold(
                      backgroundColor: _pageBg,
                      body: SafeArea(
                        bottom: false,
                        child: Column(children: [
                          _MobileHeader(
                            currentRoute: location,
                            onMenu: _toggleMenu,
                          ),
                          Expanded(child: widget.child),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3 ─ Edge bubble
            if (_showBubble ||
                (_menuCtrl.value > 0 && _menuCtrl.value < 0.15))
              Positioned(
                left: 4 + _menuCtrl.value * 12,
                top: size.height * 0.5 - 22,
                child: _EdgeBubble(progress: _menuCtrl.value),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Header
// ─────────────────────────────────────────────────────────────────────────────
class _MobileHeader extends StatelessWidget {
  final String currentRoute;
  final VoidCallback onMenu;

  const _MobileHeader({required this.currentRoute, required this.onMenu});

  String _pageTitle() {
    for (final g in kNavGroups) {
      for (final item in g.items) {
        if (currentRoute == item.route ||
            (item.route != '/' && currentRoute.startsWith(item.route))) {
          return item.label;
        }
      }
    }
    if (currentRoute == AppConstants.routeSettings) return 'Settings';
    return 'Wabot';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 54,
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            _HeaderBtn(onTap: onMenu, child: const _HamburgerIcon()),
            const SizedBox(width: 6),
            // Logo
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_accent, Color(0xFF1AAD4B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_rounded,
                    color: Colors.black, size: 15),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Wabot',
              style: const TextStyle(
                  fontSize: 15,
                  color: _shTxt,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
            const Spacer(),
            _HeaderBtn(
              onTap: () {},
              child: const Icon(Icons.search_rounded, size: 20, color: _shMute),
            ),
            _HeaderBtn(
              onTap: () {},
              child: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.notifications_outlined, size: 20, color: _shMute),
                Positioned(
                  top: -2, right: -2,
                  child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: _accent, shape: BoxShape.circle)),
                ),
              ]),
            ),
          ]),
        ),

        // ── Tab nav bar ────────────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
            children: [
              for (final g in kNavGroups)
                for (final item in g.items) ...[
                  Builder(builder: (ctx) {
                    final sel = currentRoute == item.route ||
                        (item.route != '/' &&
                            currentRoute.startsWith(item.route));
                    return GestureDetector(
                      onTap: () => ctx.go(item.route),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        margin: const EdgeInsets.only(right: 4),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: sel ? _accent : Colors.transparent,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(9)),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  sel
                                      ? item.activeIcon
                                      : item.icon,
                                  size: 14,
                                  color: sel ? Colors.black : _shMute),
                              const SizedBox(width: 6),
                              Text(item.label,
                                  style: TextStyle(
                                      color: sel
                                          ? Colors.black
                                          : _shMute,
                                      fontSize: 12,
                                      fontWeight: sel
                                          ? FontWeight.w700
                                          : FontWeight.w500)),
                            ]),
                      ),
                    );
                  }),
                ],
            ],
          ),
        ),
        Container(height: 1, color: _border),
      ],
    );
  }
}

class _HamburgerIcon extends StatelessWidget {
  const _HamburgerIcon();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 20, height: 2, color: _shTxt),
        const SizedBox(height: 4),
        Container(width: 14, height: 2, color: _shTxt),
        const SizedBox(height: 4),
        Container(width: 17, height: 2, color: _shTxt),
      ],
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HeaderBtn({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Sidebar Panel
// ─────────────────────────────────────────────────────────────────────────────
class _MobileSidebarPanel extends StatefulWidget {
  final String currentRoute;
  final double opacity;
  final double width;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  const _MobileSidebarPanel({
    required this.currentRoute,
    required this.opacity,
    required this.width,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_MobileSidebarPanel> createState() => _MobileSidebarPanelState();
}

class _MobileSidebarPanelState extends State<_MobileSidebarPanel> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Opacity(
        opacity: widget.opacity.clamp(0.0, 1.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_sh1, _sh2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
                  child: Row(children: [
                    // Logo + title
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_accent, Color(0xFF1AAD4B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                              color: _accent.withOpacity(.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.smart_toy_rounded,
                            color: Colors.black, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('Wabot',
                        style: TextStyle(
                            color: _shTxt,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3)),
                    const Spacer(),
                    // Close button
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: _shTxt, size: 17),
                      ),
                    ),
                  ]),
                ),
              ),

              // Status badge
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _accent.withOpacity(.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: _accent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Bot en ligne',
                        style: TextStyle(
                            color: _accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5)),
                  ]),
                ),
              ),

              Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white.withOpacity(.07)),
              const SizedBox(height: 8),

              // Nav groups
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  children: [
                    for (final group in kNavGroups) ...[
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(10, 14, 10, 6),
                        child: Text(
                          group.label,
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.2,
                            color: _accent.withOpacity(.55),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      for (final item in group.items)
                        _DrawerNavItem(
                          item: item,
                          selected: widget.currentRoute == item.route ||
                              (item.route != '/' &&
                                  widget.currentRoute
                                      .startsWith(item.route)),
                          onTap: () => widget.onSelect(item.route),
                        ),
                    ],
                  ],
                ),
              ),

              // Footer
              Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white.withOpacity(.07)),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _DrawerNavItem(
                    item: const WNavItem(
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings_rounded,
                      label: 'Settings',
                      route: AppConstants.routeSettings,
                    ),
                    selected:
                        widget.currentRoute == AppConstants.routeSettings,
                    onTap: () =>
                        widget.onSelect(AppConstants.routeSettings),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  final WNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color:
            selected ? _accent.withOpacity(.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _accent.withOpacity(.25)),
                  )
                : null,
            child: Row(children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 17,
                color: selected ? _accent : _shMute,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? _accent : _shTxt,
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                      color: _accent, shape: BoxShape.circle),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edge Bubble
// ─────────────────────────────────────────────────────────────────────────────
class _EdgeBubble extends StatelessWidget {
  final double progress;
  const _EdgeBubble({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (1 - progress * 6).clamp(0.0, 1.0),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _accent.withOpacity(.8),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
                color: Color(0x44000000),
                blurRadius: 12,
                offset: Offset(2, 2))
          ],
        ),
        child: const Center(
          child: Icon(Icons.chevron_right_rounded,
              size: 26, color: Colors.black),
        ),
      ),
    );
  }
}
