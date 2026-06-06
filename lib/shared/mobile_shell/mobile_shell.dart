import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../services/api_service.dart';
import '../pages/notifications_page.dart';
import '../pages/search_page.dart';
import '../widgets/responsive_role_shell.dart' show RoleNavEntry;

const _pageBg  = Color(0xFF0D0E11);
const _white   = Colors.white;
const _ink     = Color(0xFFF2F3F5);
const _muted   = Color(0xFF8A9199);
const _terra   = Color(0xFF25D366);
const _orange  = Color(0xFF128C7E);
const _gold    = Color(0xFF34E07E);

const _menuBg1 = Color(0xFF0A0C0F);
const _menuBg2 = Color(0xFF0E1711);
const _menuTxt = Color(0xFFF2F3F5);

const _kEdgeZone = 28.0;

class MobileShell extends ConsumerStatefulWidget {
  final List<RoleNavEntry> dockEntries;
  final List<RoleNavEntry> drawerEntries;
  final String title;
  const MobileShell({
    super.key,
    required this.dockEntries,
    required this.drawerEntries,
    required this.title,
  });

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell>
    with SingleTickerProviderStateMixin {
  int _pageIndex = 0;

  late final AnimationController _menuCtrl;
  late final Animation<double>   _menuAnim;

  bool   _edgeDrag       = false;
  double _dragStartX     = 0;
  double _dragProgressX  = 0;
  bool   _showEdgeBubble = false;

  double _scale  = 1;
  double _xShift = 0;
  double _yShift = 0;
  double _radius = 0;

  bool get _menuOpen => _menuCtrl.value > 0.01;

  @override
  void initState() {
    super.initState();
    _menuCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340));
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
      _yShift = 0.07 * t;   // ← augmenté 0.04→0.07 pour aligner avec les nav items
      _radius = 28 * t;
    });
  }

  @override
  void dispose() {
    _menuCtrl.removeListener(_onAnim);
    _menuCtrl.dispose();
    super.dispose();
  }

  void _openMenu()   => _menuCtrl.animateTo(1);
  void _closeMenu()  => _menuCtrl.animateTo(0);
  void _toggleMenu() => _menuOpen ? _closeMenu() : _openMenu();

  void _navigateTo(String labelKey) {
    final idx = widget.drawerEntries.indexWhere((e) => e.labelKey == labelKey);
    if (idx >= 0) setState(() => _pageIndex = idx);
  }

  void _onDragStart(DragStartDetails d) {
    _dragStartX = d.localPosition.dx;
    _edgeDrag   = !_menuOpen && _dragStartX < _kEdgeZone;
    if (_edgeDrag) setState(() { _showEdgeBubble = true; _dragProgressX = 0; });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final delta = d.delta.dx;
    if (_edgeDrag) {
      _dragProgressX += delta;
      _menuCtrl.value = (_dragProgressX / 220).clamp(0.0, 1.0);
    } else if (_menuOpen && delta < 0) {
      _menuCtrl.value = (_menuCtrl.value + delta / 260).clamp(0.0, 1.0);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    setState(() => _showEdgeBubble = false);
    final vel = d.primaryVelocity ?? 0;
    if (_edgeDrag) {
      _edgeDrag = false;
      (_menuCtrl.value > 0.42 || vel > 500) ? _openMenu() : _closeMenu();
    } else if (_menuOpen) {
      (_menuCtrl.value < 0.55 || vel < -500) ? _closeMenu() : _openMenu();
    }
  }

  void _openNotifications() {
    if (_menuOpen) _closeMenu();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const _FullPage(
            title: 'Notifications', child: NotificationsPage())));
  }

  void _openSearch() {
    if (_menuOpen) _closeMenu();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const _FullPage(
            title: 'Recherche', child: SearchPage())));
  }

  void _openAccount() {
    if (_menuOpen) _closeMenu();
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const _Placeholder('Compte')));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: _menuBg1,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1 — Sidebar panel
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SidebarPanel(
                  entries: widget.drawerEntries,
                  onSelect: (key) { _closeMenu(); _navigateTo(key); },
                  onSignOut: () => ref.read(authProvider.notifier).signOut(),
                  onAccount: _openAccount,
                  onClose: _closeMenu,
                  opacity: _menuCtrl.value,
                  width: size.width * 0.72,
                ),
              ),
            ),

            // 2 — Main card
            Transform(
              transform: Matrix4.identity()
                ..translate(size.width * _xShift, size.height * _yShift)
                ..scale(_scale),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: _menuCtrl.value > 0.01 ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.18 * _menuCtrl.value),
                      blurRadius: 48,
                      spreadRadius: -4,
                      offset: const Offset(-24, 0),
                    ),
                    BoxShadow(
                      color: _terra.withOpacity(0.10 * _menuCtrl.value),
                      blurRadius: 24,
                      offset: const Offset(-10, 0),
                    ),
                  ] : [],
                ),
                child: GestureDetector(
                  onTap: _menuOpen ? _closeMenu : null,
                  behavior: HitTestBehavior.translucent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_radius),
                    child: Scaffold(
                      backgroundColor: _pageBg,
                      body: SafeArea(
                        bottom: true,
                        child: Column(children: [
                          _SmartHeader(
                            title: widget.title,
                            onMenu: _toggleMenu,
                            onSearch: _openSearch,
                            onNotifications: _openNotifications,
                            onAccount: _openAccount,
                            pageIndex: _pageIndex,
                            entries: widget.drawerEntries,
                            onTabTap: (i) {
                              if (_menuOpen) _closeMenu();
                              setState(() => _pageIndex = i);
                            },
                          ),
                          Expanded(
                            child: KeyedSubtree(
                              key: ValueKey(_pageIndex),
                              child: widget.drawerEntries[_pageIndex].page,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3 — Edge bubble
            if (_showEdgeBubble || (_menuCtrl.value > 0 && _menuCtrl.value < 0.15))
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
//  Full-page overlay (search / notifications)
// ─────────────────────────────────────────────────────────────────────────────

class _FullPage extends StatelessWidget {
  final String title;
  final Widget child;
  const _FullPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: const Color(0xFF111316),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: _ink, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: _ink, fontSize: 17,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Top header bar inside the main card
// ─────────────────────────────────────────────────────────────────────────────

class _SmartHeader extends StatelessWidget {
  final String title;
  final VoidCallback onMenu;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onAccount;
  final int pageIndex;
  final List<RoleNavEntry> entries;
  final ValueChanged<int> onTabTap;

  const _SmartHeader({
    required this.title,
    required this.onMenu, required this.onSearch,
    required this.onNotifications, required this.onAccount,
    required this.pageIndex, required this.entries,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 56,
          color: const Color(0xFF111316),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            _HeaderBtn(onTap: onMenu, child: const _HamburgerIcon()),
            Image.asset('assets/images/logo_transparent.png', width: 28, height: 28,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/logo.png', width: 28, height: 28,
                  errorBuilder: (_, __, ___) =>
                    const Icon(Icons.chat_rounded, size: 26, color: _terra),
                )),
            const SizedBox(width: 7),
            Text(AppConfig.appName,
                style: const TextStyle(fontSize: 14, color: _ink,
                    fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const Spacer(),
            _HeaderBtn(onTap: onSearch,
                child: const Icon(Icons.search_rounded, size: 20, color: _muted)),
            _HeaderBtn(
              onTap: onNotifications,
              child: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.notifications_outlined, size: 20, color: _muted),
                Positioned(top: -2, right: -2,
                  child: Container(width: 7, height: 7,
                      decoration: const BoxDecoration(color: _terra, shape: BoxShape.circle))),
              ]),
            ),
            GestureDetector(
              onTap: onAccount,
              child: Container(
                width: 32, height: 32,
                margin: const EdgeInsets.only(left: 2, right: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_terra, _orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(
                      color: _terra.withOpacity(.3),
                      blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: const Center(child: Icon(Icons.person_rounded, size: 16, color: Colors.white)),
              ),
            ),
          ]),
        ),
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
        Container(width: 20, height: 2, color: _ink),
        const SizedBox(height: 4),
        Container(width: 14, height: 2, color: _ink),
        const SizedBox(height: 4),
        Container(width: 17, height: 2, color: _ink),
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

class _EdgeBubble extends StatelessWidget {
  final double progress;
  const _EdgeBubble({required this.progress});
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (1 - progress * 6).clamp(0.0, 1.0),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _terra.withOpacity(.85),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(
              color: Color(0x33000000), blurRadius: 12, offset: Offset(2, 2))],
        ),
        child: const Center(
            child: Icon(Icons.chevron_right_rounded, size: 26, color: _white)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sidebar panel — AMÉLIORÉ :
//    • photo de profil WhatsApp depuis l'API (ou initiales en fallback)
//    • sélecteur de compte (bottom sheet) avec ajout / changement
//    • top padding ajusté pour alignement avec les nav items
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarPanel extends ConsumerStatefulWidget {
  final List<RoleNavEntry> entries;
  final ValueChanged<String> onSelect;
  final VoidCallback onSignOut;
  final VoidCallback onAccount;
  final VoidCallback onClose;
  final double opacity;
  final double width;

  const _SidebarPanel({
    required this.entries,
    required this.onSelect, required this.onSignOut,
    required this.onAccount, required this.onClose,
    required this.opacity, required this.width,
  });

  @override
  ConsumerState<_SidebarPanel> createState() => _SidebarPanelState();
}

class _SidebarPanelState extends ConsumerState<_SidebarPanel> {
  String _activeKey = '';

  // Bot info fetched from API
  String _botName    = 'Wabot';
  String _botPhone   = '';
  String _picUrl     = '';
  bool   _fetched    = false;

  @override
  void initState() {
    super.initState();
    if (widget.entries.isNotEmpty) _activeKey = widget.entries.first.labelKey;
    _fetchBotInfo();
  }

  Future<void> _fetchBotInfo() async {
    if (_fetched) return;
    try {
      final api  = ref.read(apiServiceProvider);
      final data = await api.getBotStatus();
      if (mounted) {
        setState(() {
          _botName  = (data['name'] as String? ?? 'Wabot').isNotEmpty
              ? (data['name'] as String) : 'Wabot';
          _botPhone = data['phoneNumber'] as String? ?? '';
          _picUrl   = data['profilePicUrl'] as String? ?? '';
          _fetched  = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _fetched = true);
    }
  }

  /// Initiales à partir du nom du bot
  String get _initials {
    final parts = _botName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (_botName.length >= 2) return _botName.substring(0, 2).toUpperCase();
    return _botName.toUpperCase();
  }

  /// Bottom-sheet : sélecteur / gestionnaire de comptes
  void _showAccountSwitcher(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF111316),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AccountSwitcherSheet(
        currentName:  _botName,
        currentPhone: _botPhone,
        picUrl:       _picUrl,
        onAddAccount: () {
          Navigator.pop(ctx);
          widget.onAccount();
        },
      ),
    );
  }

  List<_NavGroup> get _groups {
    final entries = widget.entries;
    if (entries.isEmpty) return [];
    final main = entries.take(math.min(5, entries.length)).toList();
    final rest = entries.skip(main.length).toList();
    return [
      _NavGroup(labelKey: 'nav.main', entries: main),
      if (rest.isNotEmpty)
        _NavGroup(labelKey: 'nav.other', entries: rest),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Opacity(
        opacity: widget.opacity.clamp(0.0, 1.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_menuBg1, _menuBg2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            CustomPaint(painter: _SidebarPatternPainter(), child: const SizedBox.expand()),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header : photo de profil + infos + bouton X ──
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Photo de profil WhatsApp (ou initiales)
                        GestureDetector(
                          onTap: () => _showAccountSwitcher(context),
                          child: Stack(
                            children: [
                              Container(
                                width: 46, height: 46,
                                decoration: const BoxDecoration(shape: BoxShape.circle),
                                clipBehavior: Clip.antiAlias,
                                child: _picUrl.isNotEmpty
                                    ? Image.network(
                                        _picUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _InitialsAvatar(
                                            initials: _initials),
                                      )
                                    : _InitialsAvatar(initials: _initials),
                              ),
                              // Indicateur en ligne (petit point vert)
                              Positioned(
                                right: 0, bottom: 0,
                                child: Container(
                                  width: 12, height: 12,
                                  decoration: BoxDecoration(
                                    color: _terra,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _menuBg1, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 11),

                        // Nom + numéro — tappable pour ouvrir le switcher
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showAccountSwitcher(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(
                                    child: Text(_botName,
                                        style: const TextStyle(color: _white,
                                            fontSize: 15, fontWeight: FontWeight.w800),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.expand_more_rounded,
                                      color: _muted, size: 16),
                                ]),
                                Text(
                                  _botPhone.isNotEmpty ? _botPhone : 'Administrateur',
                                  style: TextStyle(
                                      color: _white.withOpacity(.5), fontSize: 11),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Bouton fermer (X)
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: _white.withOpacity(.10),
                              shape: BoxShape.circle,
                              border: Border.all(color: _white.withOpacity(.14)),
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 17),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    color: _white.withOpacity(.08)),
                const SizedBox(height: 6),

                // ── Navigation groups ──
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    children: [
                      for (final group in _groups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 5),
                          child: Text(
                            group.labelKey == 'nav.main' ? 'NAVIGATION' : 'OUTILS',
                            style: TextStyle(
                                color: _terra.withOpacity(.7),
                                fontSize: 9, fontWeight: FontWeight.w800,
                                letterSpacing: 1.5),
                          ),
                        ),
                        for (int i = 0; i < group.entries.length; i++)
                          _SidebarItem(
                            entry:    group.entries[i],
                            selected: group.entries[i].labelKey == _activeKey,
                            index:    i,
                            opacity:  widget.opacity,
                            onTap: () {
                              setState(() => _activeKey = group.entries[i].labelKey);
                              widget.onSelect(group.entries[i].labelKey);
                            },
                          ),
                      ],

                      const SizedBox(height: 8),
                      Container(height: 1, color: _white.withOpacity(.06),
                          margin: const EdgeInsets.symmetric(horizontal: 4)),
                      const SizedBox(height: 8),
                      _SidebarLogoutItem(onTap: widget.onSignOut),
                    ],
                  ),
                ),

                // ── Footer branding ──
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                    child: Row(children: [
                      const Icon(Icons.chat_rounded, size: 15, color: _terra),
                      const SizedBox(width: 7),
                      Text(AppConfig.appName,
                          style: TextStyle(color: _white.withOpacity(.45),
                              fontSize: 11, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('v${AppConfig.appVersion}',
                          style: TextStyle(color: _white.withOpacity(.22), fontSize: 9)),
                    ]),
                  ),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Avatar initiales
// ─────────────────────────────────────────────────────────────────────────────

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_terra, _orange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Text(initials,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom-sheet : sélecteur de compte
// ─────────────────────────────────────────────────────────────────────────────

class _AccountSwitcherSheet extends StatelessWidget {
  final String currentName;
  final String currentPhone;
  final String picUrl;
  final VoidCallback onAddAccount;

  const _AccountSwitcherSheet({
    required this.currentName,
    required this.currentPhone,
    required this.picUrl,
    required this.onAddAccount,
  });

  String get _initials {
    final parts = currentName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (currentName.length >= 2) return currentName.substring(0, 2).toUpperCase();
    return currentName.isNotEmpty ? currentName[0].toUpperCase() : 'W';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(
          width: 38, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 18),

        // Title
        Row(children: [
          const Text('Comptes',
              style: TextStyle(color: _ink, fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          // Bouton "Ajouter un compte"
          GestureDetector(
            onTap: onAddAccount,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _terra.withOpacity(.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _terra.withOpacity(.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 15, color: _terra),
                SizedBox(width: 4),
                Text('Ajouter', style: TextStyle(
                    color: _terra, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Compte actuel
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _terra.withOpacity(.25)),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: picUrl.isNotEmpty
                  ? Image.network(picUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _InitialsAvatar(initials: _initials))
                  : _InitialsAvatar(initials: _initials),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentName, style: const TextStyle(
                    color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(currentPhone.isNotEmpty ? currentPhone : 'Compte principal',
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _terra.withOpacity(.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Actif',
                  style: TextStyle(color: _terra, fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // Info — multi-comptes à venir
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 15, color: _muted),
            SizedBox(width: 8),
            Expanded(child: Text(
              'La gestion multi-comptes arrive bientôt. Tu pourras gérer plusieurs bots WhatsApp depuis une seule app.',
              style: TextStyle(color: _muted, fontSize: 12),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sidebar navigation item
// ─────────────────────────────────────────────────────────────────────────────

class _NavGroup {
  final String labelKey;
  final List<RoleNavEntry> entries;
  const _NavGroup({required this.labelKey, required this.entries});
}

class _SidebarItem extends StatelessWidget {
  final RoleNavEntry entry;
  final bool selected;
  final int index;
  final double opacity;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.entry, required this.selected,
    required this.index, required this.opacity, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: Offset(-(1 - opacity.clamp(0.0, 1.0)) * 0.35, 0),
      duration: Duration(milliseconds: 180 + index * 35),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: opacity.clamp(0.0, 1.0),
        duration: Duration(milliseconds: 180 + index * 35),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              splashColor: _terra.withOpacity(.15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: selected ? _terra.withOpacity(.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: selected ? Border.all(color: _terra.withOpacity(.3)) : null,
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? _terra.withOpacity(.25)
                          : _white.withOpacity(.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(entry.icon, size: 18,
                        color: selected ? _terra : _menuTxt.withOpacity(.7)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(entry.labelKey,
                        style: TextStyle(
                          color: selected ? _white : _menuTxt.withOpacity(.8),
                          fontSize: 14,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        )),
                  ),
                  if (selected)
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: _terra, shape: BoxShape.circle),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarLogoutItem extends StatelessWidget {
  final VoidCallback onTap;
  const _SidebarLogoutItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
            ),
            const SizedBox(width: 14),
            const Text('Déconnexion',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Background pattern (WhatsApp-style blobs)
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = const Color(0xFF25D366).withOpacity(.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.12), 100, p1);

    final p2 = Paint()
      ..color = const Color(0xFF128C7E).withOpacity(.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.75), 130, p2);

    final p3 = Paint()
      ..color = const Color(0xFF34E07E).withOpacity(.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.45), 70, p3);

    final pg = Paint()
      ..color = const Color(0xFF25D366).withOpacity(.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const sp = 44.0;
    final cols = (size.width  / sp).ceil() + 1;
    final rows = (size.height / sp).ceil() + 1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = c * sp + (r.isEven ? sp * 0.5 : 0);
        final cy = r * sp * 0.866;
        _diamond(canvas, Offset(cx, cy), 7, pg);
      }
    }
  }

  void _diamond(Canvas canvas, Offset o, double r, Paint p) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..lineTo(o.dx + r * 0.7, o.dy)
      ..lineTo(o.dx, o.dy + r)
      ..lineTo(o.dx - r * 0.7, o.dy)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Placeholder page
// ─────────────────────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: const Color(0xFF111316),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D21),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: _ink, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: _ink, fontSize: 17,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
          const Expanded(child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.construction_rounded, color: _muted, size: 40),
              SizedBox(height: 12),
              Text('Page en construction',
                  style: TextStyle(color: _muted, fontSize: 14)),
            ]),
          )),
        ]),
      ),
    );
  }
}
