import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cottage/features/dashboard/data/dashboard_data.dart';
import 'package:cottage/features/dashboard/data/dashboard_service.dart';
import 'package:cottage/features/dashboard/presentation/dashboard_screen.dart';
import 'package:cottage/features/meal/presentation/meal_screen.dart';
import 'package:cottage/features/menu/presentation/menu_screen.dart';
import 'package:cottage/features/notices/presentation/notices_screen.dart';
import 'package:cottage/features/requests/data/request_service.dart';
import 'package:cottage/features/requests/presentation/request_screen.dart';
import 'package:cottage/features/utilities/presentation/utilities_screen.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';

class _NavTabData {
  final IconData icon;
  final String label;
  final WidgetBuilder builder;
  final int? badge;
  const _NavTabData({
    required this.icon,
    required this.label,
    required this.builder,
    this.badge,
  });
}

/// Root shell once a member is signed in: an [IndexedStack] of the tab
/// screens under a floating pill nav bar, mirroring the shape/behaviour of
/// the web app's MobileBottomNav (dark pill, active tab pops into a filled
/// brand-colored circle) using the existing Cottage brand color.
class BottomNavShell extends StatefulWidget {
  /// Dashboard data fetched by [CottageApp] while the splash screen was
  /// still animating, so the Home tab renders fully populated on its very
  /// first frame instead of showing its own loading state right after
  /// splash hands off. Only consumed once, by [DashboardScreen]'s initial
  /// mount.
  final (Profile, DashboardData)? preloadedDashboard;

  /// Lets code outside this file (e.g. a notification's tap handler) switch
  /// tabs and, optionally, trigger that tab's own quick-action -- the same
  /// mechanism the speed-dial items above already use internally, just
  /// exposed for callers that aren't `BottomNavShellState` itself. See
  /// [BottomNavShellState.openTab].
  static final GlobalKey<BottomNavShellState> shellKey =
      GlobalKey<BottomNavShellState>();

  const BottomNavShell({super.key, this.preloadedDashboard});

  @override
  State<BottomNavShell> createState() => BottomNavShellState();
}

class BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;
  String? _activeSheet;
  final _requestService = RequestService();

  /// Fetched once at startup (full `can_add_*` columns -- unlike the
  /// smaller slice [DashboardService.getCurrentProfile] selects) so the
  /// shell can decide, same as the web's MobileBottomNav, whether the
  /// second tab should be Notices or the Request inbox: `canAddMeals ||
  /// canAddBazaar` gets the inbox (they're the ones who'd review requests),
  /// everyone else keeps direct Notices access.
  Profile? _profile;
  int _pendingRequestCount = 0;

  bool get _canManageMealRequests =>
      (_profile?.canAddMeals ?? false) || (_profile?.canAddBazaar ?? false);

  bool get _canAddMeals => _profile?.canAddMeals ?? false;
  bool get _canAddBazaar => _profile?.canAddBazaar ?? false;
  bool get _canAddDeposit => _profile?.canAddDeposit ?? false;
  bool get _isSuperAdmin => _profile?.isSuperAdmin ?? false;
  bool get _canAddExpenses => _profile?.canAddExpenses ?? false;

  /// A plain member (no super admin, no `can_add_expenses` grant) only ever
  /// sees the single "Utility Details" speed-dial item -- mirrors
  /// MobileUtilitiesSheet.tsx's `items` list, where every other entry is
  /// gated behind `isSuperAdmin`/`canAddExpenses`. With just one possible
  /// destination, popping open a speed dial to pick it is pointless
  /// ceremony -- see [_handleTabTap].
  bool get _utilitiesHasOnlyDetails => !_isSuperAdmin && !_canAddExpenses;

  /// Public read of the same flag, for callers outside this State deciding
  /// whether tab 1 is the Requests inbox or Notices (see
  /// notification_navigation.dart).
  bool get canManageMealRequests => _canManageMealRequests;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    try {
      final profile = await DashboardService().getCurrentProfileFull();
      if (!mounted) return;
      setState(() => _profile = profile);
      if (_canManageMealRequests) _refreshPendingCount();
    } catch (_) {
      // Left null -- falls back to showing Notices directly, same as a
      // member without either permission would see.
    }
  }

  Future<void> _refreshPendingCount() async {
    try {
      final count = await _requestService.getPendingCount();
      if (mounted) setState(() => _pendingRequestCount = count);
    } catch (_) {
      // Badge just stays at its last known value.
    }
  }

  // Uses the `lucide_icons` package (the exact icon set MobileBottomNav.tsx
  // uses on web, via lucide-react) instead of Material Icons -- Material's
  // filled/rounded glyphs are a fundamentally different visual language
  // (heavier weight, different proportions) than Lucide's 2px-stroke outline
  // icons, so no Material substitute ever reads as "the same icon" at a
  // glance. This is a direct swap of each web glyph:
  // LayoutDashboard/Inbox-or-Pin/UtensilsCrossed/Zap/Menu.
  //
  // Rebuilt per State (rather than a top-level constant) so the Home tab
  // can carry widget.preloadedDashboard and the 2nd tab can react to
  // _canManageMealRequests/_pendingRequestCount -- harmless to rebuild
  // every time since DashboardScreen/RequestScreen's GlobalKeys make
  // Flutter reuse their existing State once mounted, ignoring new
  // constructor values on subsequent rebuilds.
  List<_NavTabData> get _tabs => [
    _NavTabData(
      icon: LucideIcons.layoutDashboard,
      label: 'Home',
      builder: (_) => DashboardScreen(
        key: DashboardScreen.dashboardScreenKey,
        preloadedData: widget.preloadedDashboard,
      ),
    ),
    _canManageMealRequests
        ? _NavTabData(
            icon: LucideIcons.inbox,
            label: 'Requests',
            badge: _pendingRequestCount,
            builder: (_) => RequestScreen(key: RequestScreen.requestScreenKey),
          )
        : _NavTabData(
            icon: LucideIcons.pin,
            label: 'Notices',
            builder: (_) => const NoticesScreen(),
          ),
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

  /// Public counterpart to the speed-dial items' own `setState(() =>
  /// _index = N)` + `triggerAction(...)` pattern above, for callers outside
  /// this State (e.g. a notification's tap handler routing to the tab that
  /// notification is about). [action] is forwarded to that tab's own
  /// `triggerAction`, same as the speed dial does, once the tab has had a
  /// frame to build (the target screen's State may not exist yet on the
  /// very first switch to it).
  void openTab(int index, {String? action}) {
    setState(() {
      _index = index;
      _activeSheet = null;
    });
    if (action == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (index) {
        case 2:
          MealScreen.mealScreenKey.currentState?.triggerAction(action);
          break;
        case 3:
          UtilitiesScreen.utilitiesScreenKey.currentState?.triggerAction(action);
          break;
        case 4:
          MenuScreen.menuScreenKey.currentState?.triggerAction(action);
          break;
      }
    });
  }

  void _handleTabTap(int idx) {
    if (idx == 0 || idx == 1) {
      // Coming back to Home from another tab: DashboardScreen is kept
      // alive inside the IndexedStack below, so its own data (e.g. a
      // bazaar duty just self-assigned from Members) would otherwise stay
      // stale until the app restarts -- force a reload on every re-entry.
      if (idx == 0 && _index != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          DashboardScreen.dashboardScreenKey.currentState?.refresh();
        });
      }
      if (idx == 1 && _index != 1 && _canManageMealRequests) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          RequestScreen.requestScreenKey.currentState?.refresh();
        });
        _refreshPendingCount();
      }
      setState(() {
        _index = idx;
        _activeSheet = null;
      });
    } else if (idx == 3 && _utilitiesHasOnlyDetails) {
      // Only one destination exists for this member -- skip the speed dial
      // and go straight there, same as tapping Home/Requests above.
      setState(() {
        _index = 3;
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
        // Mirrors MobileMealSheet.tsx's `canAddBazaar ? add-cost :
        // request-cost` -- a member without the grant submits a
        // meal_cost_requests row for review instead of writing directly.
        _canAddBazaar
            ? _SpeedDialItemData(
                key: 'add-bazaar',
                label: 'Add Meal Expense',
                icon: LucideIcons.shoppingBag,
                bgColor: const Color(0xFFFEF3C7),
                fgColor: const Color(0xFF92400E),
                onTap: () {
                  setState(() {
                    _index = 2;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    MealScreen.mealScreenKey.currentState?.triggerAction(
                      'add-bazaar',
                    );
                  });
                },
              )
            : _SpeedDialItemData(
                key: 'request-cost',
                label: 'Request Meal Cost',
                icon: Icons.send_outlined,
                bgColor: const Color(0xFFFEF3C7),
                fgColor: const Color(0xFF92400E),
                onTap: () {
                  setState(() {
                    _index = 2;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    MealScreen.mealScreenKey.currentState?.triggerAction(
                      'request-cost',
                    );
                  });
                },
              ),
        // Deposit has no request-flow fallback (mirrors the web, which
        // simply omits this item when canAddDeposit is false).
        if (_canAddDeposit)
          _SpeedDialItemData(
            key: 'add-deposit',
            label: 'Add Meal Deposit',
            icon: Icons.savings_outlined,
            bgColor: const Color(0xFFD1FAE5),
            fgColor: const Color(0xFF065F46),
            onTap: () {
              setState(() {
                _index = 2;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                MealScreen.mealScreenKey.currentState?.triggerAction(
                  'add-deposit',
                );
              });
            },
          ),
        // Mirrors MobileMealSheet.tsx's `canAddMeals ? add-meal :
        // request-meal`.
        _canAddMeals
            ? _SpeedDialItemData(
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
                    MealScreen.mealScreenKey.currentState?.triggerAction(
                      'add-meal',
                    );
                  });
                },
              )
            : _SpeedDialItemData(
                key: 'request-meal',
                label: 'Request Meal',
                icon: Icons.send_outlined,
                bgColor: const Color(0xFFE0F2FE),
                fgColor: const Color(0xFF075985),
                onTap: () {
                  setState(() {
                    _index = 2;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    MealScreen.mealScreenKey.currentState?.triggerAction(
                      'request-meal',
                    );
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
        // Mirrors MobileUtilitiesSheet.tsx: cottage/member deposit and the
        // Statement shortcut are super-admin only.
        if (_isSuperAdmin) ...[
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
                UtilitiesScreen.utilitiesScreenKey.currentState
                    ?.triggerAction('cottage-deposit');
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
                UtilitiesScreen.utilitiesScreenKey.currentState
                    ?.triggerAction('member-deposit');
              });
            },
          ),
        ],
        // Mirrors `canAddExpenses` gating "Utility Expense" -- a plain
        // member without this grant has no way to add one from here (there
        // is no request-flow for utility expenses, unlike meal expenses).
        if (_canAddExpenses)
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
                UtilitiesScreen.utilitiesScreenKey.currentState
                    ?.triggerAction('utility-expense');
              });
            },
          ),
        if (_isSuperAdmin)
          _SpeedDialItemData(
            key: 'utility-statement',
            label: 'Utility Statement',
            icon: Icons.description_outlined,
            bgColor: const Color(0xFFF3E8FF),
            fgColor: const Color(0xFF6B21A8),
            onTap: () {
              setState(() {
                _index = 3;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                UtilitiesScreen.utilitiesScreenKey.currentState
                    ?.triggerAction('utility-statement');
              });
            },
          ),
      ];
    } else if (_activeSheet == 'menu') {
      rightOffset = screenWidth * 0.1 - 24;
      items = [
        // Only needed when the 2nd tab has been taken over by the Request
        // inbox -- otherwise Notices is already directly one tap away, so
        // this would just be a redundant second path to it (matches the
        // web's `showNoticeBoard={canManageMealRequests}`).
        if (_canManageMealRequests)
          _SpeedDialItemData(
            key: 'notice-board',
            label: 'Notice Board',
            icon: Icons.push_pin_outlined,
            bgColor: const Color(0xFFE0F2FE),
            fgColor: const Color(0xFF075985),
            onTap: () {
              setState(() => _activeSheet = null);
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const NoticesScreen()));
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
          // Without this, the Scaffold reserves space for the floating nav
          // bar and shrinks the body above it -- a tab's own full-page
          // loading state (e.g. DashboardScreen's orange splash-style
          // loader) then can't paint behind the bar, leaving a gap where
          // whatever's beneath the nav bar peeks through. extendBody lets
          // the body (IndexedStack) draw the full screen height, with the
          // pill nav bar floating on top of it as designed.
          extendBody: true,
          body: IndexedStack(
            index: _index,
            children: [for (final tab in _tabs) tab.builder(context)],
          ),
          bottomNavigationBar: _NavBarFootprintMeasurer(
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _FloatingNavBar(
                tabs: _tabs,
                index: _index,
                activeSheet: _activeSheet,
                onTap: _handleTabTap,
              ),
            ),
          ),
        ),
        if (_activeSheet != null) _buildSpeedDialOverlay(screenWidth, surface),
      ],
    );
  }
}

/// Measures where [child] (the SafeArea-wrapped floating nav bar) actually
/// renders and publishes the distance from its top edge to the bottom of
/// the screen into [measuredNavBarFootprint] -- see that field's doc for
/// why this measures instead of recomputing the SafeArea/inset math.
class _NavBarFootprintMeasurer extends StatefulWidget {
  final Widget child;
  const _NavBarFootprintMeasurer({required this.child});

  @override
  State<_NavBarFootprintMeasurer> createState() => _NavBarFootprintMeasurerState();
}

class _NavBarFootprintMeasurerState extends State<_NavBarFootprintMeasurer> {
  final _key = GlobalKey();

  void _measure(Duration _) {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final footprint = screenHeight - topLeft.dy;
    if (footprint > 0 && (measuredNavBarFootprint.value - footprint).abs() > 0.5) {
      measuredNavBarFootprint.value = footprint;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-measure after every layout this widget goes through (first frame,
    // rotation, keyboard show/hide, etc.) rather than just once in
    // initState, since the nav bar's on-screen position can change.
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

class _FloatingNavBar extends StatelessWidget {
  final List<_NavTabData> tabs;
  final int index;
  final String? activeSheet;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.tabs,
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: _NavTab(
                data: tabs[i],
                active:
                    (activeSheet == null && index == i) ||
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
class _NavTab extends StatelessWidget {
  final _NavTabData data;
  final bool active;
  final VoidCallback onTap;

  const _NavTab({
    required this.data,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    
    // The base icon (shown when inactive)
    Widget baseIcon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          data.icon,
          size: 24,
          color: surface.navInactive,
        ),
        if ((data.badge ?? 0) > 0)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: CottageColors.destructive,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: surface.navBackground,
                  width: 2,
                ),
              ),
              child: Text(
                data.badge! > 9 ? '9+' : '${data.badge}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 64, // Same as the navbar height
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // BASE LAYER: The normal icon fades out smoothly
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: active ? 0.0 : 1.0,
              child: baseIcon,
            ),
            
            // TOP LAYER: The floating widget pops in with a bounce
            Positioned(
              bottom: 16, // Pushes it up to match the screenshot intersection
              child: AnimatedScale(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                scale: active ? 1.0 : 0.0,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: CottageColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: surface.background, width: 4),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        data.icon,
                        size: 24,
                        color: CottageColors.primaryForeground,
                      ),
                      if ((data.badge ?? 0) > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            alignment: Alignment.center,
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: CottageColors.destructive,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: CottageColors.primary,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              data.badge! > 9 ? '9+' : '${data.badge}',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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

class _SpeedDialMenuState extends State<_SpeedDialMenu>
    with SingleTickerProviderStateMixin {
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
            child: Container(color: Colors.black.withValues(alpha: 0.25)),
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
