import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cottage/features/dashboard/presentation/dashboard_screen.dart';
import 'package:cottage/features/meal/presentation/meal_screen.dart';
import 'package:cottage/features/menu/presentation/menu_screen.dart';
import 'package:cottage/features/notices/presentation/notices_screen.dart';
import 'package:cottage/features/utilities/presentation/utilities_screen.dart';
import 'package:cottage/constants/theme.dart';

class _NavTabData {
  final IconData icon;
  final String label;
  final WidgetBuilder builder;
  const _NavTabData({required this.icon, required this.label, required this.builder});
}

// Uses the `lucide_icons` package (the exact icon set MobileBottomNav.tsx
// uses on web, via lucide-react) instead of Material Icons -- Material's
// filled/rounded glyphs are a fundamentally different visual language
// (heavier weight, different proportions) than Lucide's 2px-stroke outline
// icons, so no Material substitute ever reads as "the same icon" at a
// glance. This is a direct swap of each web glyph:
// LayoutDashboard/Pin/UtensilsCrossed/Zap/Menu.
final _tabs = <_NavTabData>[
  _NavTabData(icon: LucideIcons.layoutDashboard, label: 'Home', builder: (_) => const DashboardScreen()),
  _NavTabData(icon: LucideIcons.pin, label: 'Notices', builder: (_) => const NoticesScreen()),
  _NavTabData(
    icon: LucideIcons.utensilsCrossed,
    label: 'Meal',
    builder: (_) => MealScreen(key: MealScreen.mealScreenKey),
  ),
  _NavTabData(
    icon: LucideIcons.zap,
    label: 'Utilities',
    builder: (_) => UtilitiesScreen(key: UtilitiesScreen.utilitiesScreenKey),
  ),
  _NavTabData(
    icon: LucideIcons.menu,
    label: 'Menu',
    builder: (_) => MenuScreen(key: MenuScreen.menuScreenKey),
  ),
];

/// Root shell once a member is signed in: an [IndexedStack] of the tab
/// screens under a floating pill nav bar, mirroring the shape/behaviour of
/// the web app's MobileBottomNav (dark pill, active tab pops into a filled
/// brand-colored circle) using the existing Cottage brand color.
class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;
  String? _activeSheet;

  void _handleTabTap(int idx) {
    if (idx == 0 || idx == 1) {
      setState(() {
        _index = idx;
        _activeSheet = null;
      });
    } else {
      final sheetKey = idx == 2 ? 'meal' : (idx == 3 ? 'utilities' : 'menu');
      setState(() {
        if (_activeSheet == sheetKey) {
          _activeSheet = null;
        } else {
          _activeSheet = sheetKey;
        }
      });
    }
  }

  Widget _buildSpeedDialOverlay(double screenWidth, CottageSurface surface) {
    List<_SpeedDialItemData> items = [];
    double rightOffset = 0;

    if (_activeSheet == 'meal') {
      rightOffset = screenWidth * 0.5 - 24;
      items = [
        _SpeedDialItemData(
          key: 'month-details',
          label: 'Month Details',
          icon: Icons.calendar_month_outlined,
          bgColor: surface.accent,
          fgColor: surface.accentForeground,
          onTap: () {
            setState(() {
              _index = 2;
            });
          },
        ),
        _SpeedDialItemData(
          key: 'add-bazaar',
          label: 'Add Meal Expense',
          icon: Icons.shopping_basket_outlined,
          bgColor: const Color(0xFFFEF3C7),
          fgColor: const Color(0xFF92400E),
          onTap: () {
            setState(() {
              _index = 2;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MealScreen.mealScreenKey.currentState?.triggerAction('add-bazaar');
            });
          },
        ),
        _SpeedDialItemData(
          key: 'add-deposit',
          label: 'Add Meal Deposit',
          icon: Icons.wallet_outlined,
          bgColor: const Color(0xFFD1FAE5),
          fgColor: const Color(0xFF065F46),
          onTap: () {
            setState(() {
              _index = 2;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MealScreen.mealScreenKey.currentState?.triggerAction('add-deposit');
            });
          },
        ),
        _SpeedDialItemData(
          key: 'add-meal',
          label: 'Add Meal',
          icon: Icons.add_circle_outline_rounded,
          bgColor: const Color(0xFFE0F2FE),
          fgColor: const Color(0xFF075985),
          onTap: () {
            setState(() {
              _index = 2;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MealScreen.mealScreenKey.currentState?.triggerAction('add-meal');
            });
          },
        ),
      ];
    } else if (_activeSheet == 'utilities') {
      rightOffset = screenWidth * 0.3 - 24;
      items = [
        _SpeedDialItemData(
          key: 'utility-details',
          label: 'Utility Details',
          icon: Icons.list_alt_outlined,
          bgColor: surface.accent,
          fgColor: surface.accentForeground,
          onTap: () {
            setState(() {
              _index = 3;
            });
          },
        ),
        _SpeedDialItemData(
          key: 'cottage-deposit',
          label: 'Cottage Deposit',
          icon: Icons.house_outlined,
          bgColor: const Color(0xFFCCFBF1),
          fgColor: const Color(0xFF0F766E),
          onTap: () {
            setState(() {
              _index = 3;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              UtilitiesScreen.utilitiesScreenKey.currentState?.triggerAction('cottage-deposit');
            });
          },
        ),
        _SpeedDialItemData(
          key: 'member-deposit',
          label: 'Member Deposit',
          icon: Icons.account_balance_wallet_outlined,
          bgColor: const Color(0xFFD1FAE5),
          fgColor: const Color(0xFF065F46),
          onTap: () {
            setState(() {
              _index = 3;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              UtilitiesScreen.utilitiesScreenKey.currentState?.triggerAction('member-deposit');
            });
          },
        ),
        _SpeedDialItemData(
          key: 'utility-expense',
          label: 'Utility Expense',
          icon: Icons.receipt_long_outlined,
          bgColor: const Color(0xFFFEF3C7),
          fgColor: const Color(0xFF92400E),
          onTap: () {
            setState(() {
              _index = 3;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              UtilitiesScreen.utilitiesScreenKey.currentState?.triggerAction('utility-expense');
            });
          },
        ),
      ];
    } else if (_activeSheet == 'menu') {
      rightOffset = screenWidth * 0.1 - 24;
      items = [
        _SpeedDialItemData(
          key: 'notice-board',
          label: 'Notice Board',
          icon: Icons.push_pin_outlined,
          bgColor: const Color(0xFFE0F2FE),
          fgColor: const Color(0xFF075985),
          onTap: () {
            setState(() {
              _index = 1;
            });
          },
        ),
        _SpeedDialItemData(
          key: 'settings',
          label: 'Settings',
          icon: Icons.settings_outlined,
          bgColor: const Color(0xFFF1F5F9),
          fgColor: const Color(0xFF334155),
          onTap: () {
            setState(() {
              _index = 4;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MenuScreen.menuScreenKey.currentState?.triggerAction('settings');
            });
          },
        ),
        _SpeedDialItemData(
          key: 'contacts',
          label: 'Contact',
          icon: Icons.phone_outlined,
          bgColor: const Color(0xFFE0F2FE),
          fgColor: const Color(0xFF075985),
          onTap: () {
            setState(() {
              _index = 4;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MenuScreen.menuScreenKey.currentState?.triggerAction('contacts');
            });
          },
        ),
        _SpeedDialItemData(
          key: 'months',
          label: 'Months',
          icon: Icons.date_range_outlined,
          bgColor: const Color(0xFFF3E8FF),
          fgColor: const Color(0xFF6B21A8),
          onTap: () {
            setState(() {
              _index = 4;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MenuScreen.menuScreenKey.currentState?.triggerAction('months');
            });
          },
        ),
        _SpeedDialItemData(
          key: 'members',
          label: 'Members',
          icon: Icons.people_outline,
          bgColor: const Color(0xFFD1FAE5),
          fgColor: const Color(0xFF065F46),
          onTap: () {
            setState(() {
              _index = 4;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              MenuScreen.menuScreenKey.currentState?.triggerAction('members');
            });
          },
        ),
      ];
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: _SpeedDialMenu(
        items: items,
        rightOffset: rightOffset,
        onClose: () => setState(() => _activeSheet = null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _index,
            children: [for (final tab in _tabs) tab.builder(context)],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _FloatingNavBar(
              index: _index,
              activeSheet: _activeSheet,
              onTap: _handleTabTap,
            ),
          ),
        ),
        if (_activeSheet != null) _buildSpeedDialOverlay(screenWidth, surface),
      ],
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int index;
  final String? activeSheet;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.index,
    required this.activeSheet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: surface.navBackground,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: _NavTab(
                data: _tabs[i],
                active: (activeSheet == null && index == i) ||
                    (activeSheet == 'meal' && i == 2) ||
                    (activeSheet == 'utilities' && i == 3) ||
                    (activeSheet == 'menu' && i == 4),
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// No visible text label is ever rendered here -- mirrors the web's
/// `<span className="sr-only">{label}</span>` (icon-only bar; the label
/// exists only for screen readers).
class _NavTab extends StatefulWidget {
  final _NavTabData data;
  final bool active;
  final VoidCallback onTap;

  const _NavTab({required this.data, required this.active, required this.onTap});

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Web's SpeedDialMenu constants: 320ms ease-out-back (overshoot) expanding
  // into the active state, 260ms ease-in-cubic collapsing out of it.
  static const _expandMs = 320;
  static const _collapseMs = 260;
  static const _expandCurve = Cubic(0.34, 1.56, 0.64, 1);
  static const _collapseCurve = Cubic(0.32, 0, 0.67, 0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _expandMs),
      reverseDuration: const Duration(milliseconds: _collapseMs),
      value: widget.active ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _NavTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      widget.active ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final surface = context.surface;
    return InkWell(
      onTap: widget.onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final curve = _controller.status == AnimationStatus.reverse ? _collapseCurve : _expandCurve;
            final t = curve.transform(_controller.value).clamp(0.0, 1.0);
            final active = widget.active;
            final size = lerpDouble(36, 56, t)!;
            return Container(
              margin: EdgeInsets.only(bottom: lerpDouble(0, 32, t)!),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? CottageColors.primary : Colors.transparent,
                boxShadow: active
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
                    : null,
                border: active ? Border.all(color: surface.background, width: 4) : null,
              ),
              child: Icon(
                data.icon,
                size: active ? 24 : 20,
                color: active ? CottageColors.primaryForeground : surface.navInactive,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpeedDialItemData {
  final String key;
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color fgColor;
  final VoidCallback onTap;

  const _SpeedDialItemData({
    required this.key,
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.fgColor,
    required this.onTap,
  });
}

class _SpeedDialMenu extends StatefulWidget {
  final List<_SpeedDialItemData> items;
  final double rightOffset;
  final VoidCallback onClose;

  const _SpeedDialMenu({
    required this.items,
    required this.rightOffset,
    required this.onClose,
  });

  @override
  State<_SpeedDialMenu> createState() => _SpeedDialMenuState();
}

class _SpeedDialMenuState extends State<_SpeedDialMenu> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<Animation<double>> _staggeredAnimations = [];

  @override
  void initState() {
    super.initState();
    final count = widget.items.length;
    final totalDurationMs = 320 + (count - 1) * 50;
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDurationMs),
    );

    for (var i = 0; i < count; i++) {
      final delayMs = i * 50;
      final start = delayMs / totalDurationMs;
      final end = (delayMs + 320) / totalDurationMs;

      _staggeredAnimations.add(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOutBack,
          ),
        ),
      );
    }

    _animController.forward();
  }

  void _close() {
    _animController.reverse().then((_) => widget.onClose());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final count = widget.items.length;

    return Stack(
      children: [
        GestureDetector(
          onTap: _close,
          behavior: HitTestBehavior.translucent,
          child: FadeTransition(
            opacity: _animController,
            child: Container(
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
        ),
        for (var i = 0; i < count; i++)
          AnimatedBuilder(
            animation: _staggeredAnimations[i],
            builder: (context, child) {
              final animValue = _staggeredAnimations[i].value;

              final yStart = 20.0;
              final yEnd = 96.0 + i * 58.0;
              final currentY = yStart + (yEnd - yStart) * animValue;

              final currentScale = 0.3 + 0.7 * animValue;
              final currentOpacity = animValue.clamp(0.0, 1.0);

              return Positioned(
                bottom: currentY,
                right: widget.rightOffset,
                child: Opacity(
                  opacity: currentOpacity,
                  child: Transform.scale(
                    scale: currentScale,
                    alignment: Alignment.bottomRight,
                    child: _buildItem(widget.items[i], surface),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildItem(_SpeedDialItemData item, CottageSurface surface) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: surface.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: surface.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: surface.foreground,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: item.bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _close();
                item.onTap();
              },
              borderRadius: BorderRadius.circular(24),
              child: Icon(item.icon, color: item.fgColor, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}
