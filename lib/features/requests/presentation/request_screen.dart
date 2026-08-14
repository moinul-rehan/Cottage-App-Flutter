import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/common_widgets/cottage_loader.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../data/request_models.dart';
import '../data/request_service.dart';

/// "Requests" -- Figma node 228:1783: three tabs (Meal / Meal Cost /
/// History) over a "Pending (n)" list of request cards with Approve/Reject.
/// Takes over the Home tab's neighbouring bottom-nav slot for members who
/// can manage meal/bazaar requests (mirrors the web's MobileBottomNav:
/// Notices tab is swapped for this one when `canManageMealRequests` is
/// true). RLS already scopes select/update on both request tables to
/// reviewers + the requester themselves, so no extra client-side filtering
/// is needed. Also exposes a "New Request" action so a member without
/// can_add_meals/can_add_bazaar has somewhere to submit one from. Page
/// shell copies _DynamicDefaultCostHeaderDelegate's collapsing-title
/// mechanics.
class RequestScreen extends StatefulWidget {
  static final requestScreenKey = GlobalKey<_RequestScreenState>();

  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestData {
  final Profile profile;
  final List<MealRequest> mealRequests;
  final List<MealCostRequest> costRequests;
  const _RequestData({
    required this.profile,
    required this.mealRequests,
    required this.costRequests,
  });
}

class _RequestScreenState extends State<RequestScreen> {
  final _requestService = RequestService();
  final _dashService = DashboardService();
  late Future<_RequestData> _future;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RequestData> _load() async {
    final profile = await _dashService.getCurrentProfileFull().timeout(
      const Duration(seconds: 15),
    );
    final mealRequests = await _requestService.getMealRequests().timeout(
      const Duration(seconds: 15),
    );
    final costRequests = await _requestService.getMealCostRequests().timeout(
      const Duration(seconds: 15),
    );
    return _RequestData(
      profile: profile,
      mealRequests: mealRequests,
      costRequests: costRequests,
    );
  }

  /// Public so [RequestScreen.requestScreenKey] can force a reload from
  /// BottomNavShell when this tab is switched back into, same as
  /// DashboardScreen.
  // Block body -- see contacts_screen.dart's _refresh for why the arrow
  // form is a real bug (setState() callback implicitly returning a Future).
  void refresh() => setState(() {
    _future = _load();
  });

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  }

  Future<void> _approveMeal(MealRequest r, _RequestData data) async {
    try {
      await _requestService.approveMealRequest(
        r,
        cottageId: data.profile.cottageId,
        reviewerId: data.profile.id,
      );
    } catch (e) {
      if (mounted) showToast(context, 'Could not approve: $e');
      return;
    }
    refresh();
  }

  Future<void> _rejectMeal(MealRequest r, _RequestData data) async {
    await _requestService.rejectMealRequest(r.id, reviewerId: data.profile.id);
    refresh();
  }

  Future<void> _approveCost(MealCostRequest r, _RequestData data) async {
    try {
      await _requestService.approveMealCostRequest(
        r,
        cottageId: data.profile.cottageId,
        reviewerId: data.profile.id,
      );
    } catch (e) {
      if (mounted) showToast(context, 'Could not approve: $e');
      return;
    }
    refresh();
  }

  Future<void> _rejectCost(MealCostRequest r, _RequestData data) async {
    await _requestService.rejectMealCostRequest(
      r.id,
      reviewerId: data.profile.id,
    );
    refresh();
  }

  void _showNewRequest(_RequestData data) {
    bool isMeal = true;
    final now = DateTime.now();
    String date = _isoDate(now);
    final lunchCtrl = TextEditingController(text: '1');
    final dinnerCtrl = TextEditingController(text: '1');
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final surface = sheetContext.surface;
          return CottageSheetContent(
          title: 'New Request',
          children: [
            Row(
              children: [
                Expanded(
                  child: _RequestKindChip(
                    label: 'Meal',
                    selected: isMeal,
                    onTap: () => setSheetState(() => isMeal = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RequestKindChip(
                    label: 'Bazar Cost',
                    selected: !isMeal,
                    onTap: () => setSheetState(() => isMeal = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Date',
              style: TextStyle(fontSize: 13, color: surface.foreground),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: sheetContext,
                  initialDate: DateTime.tryParse(date) ?? now,
                  firstDate: DateTime(now.year, now.month - 1, 1),
                  lastDate: now,
                );
                if (picked != null) {
                  setSheetState(() => date = _isoDate(picked));
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: surface.background,
                  border: Border.all(color: surface.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 13,
                    color: surface.foreground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isMeal) ...[
              Row(
                children: [
                  Expanded(
                    child: _RequestNumberField(
                      label: 'Lunch',
                      controller: lunchCtrl,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RequestNumberField(
                      label: 'Dinner',
                      controller: dinnerCtrl,
                    ),
                  ),
                ],
              ),
            ] else ...[
              _RequestNumberField(label: 'Amount (৳)', controller: amountCtrl),
              const SizedBox(height: 16),
              Text(
                'Items purchased (optional)',
                style: TextStyle(fontSize: 13, color: surface.foreground),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Rice, Egg, Oil'),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (isMeal) {
                  final lunch = double.tryParse(lunchCtrl.text) ?? 0;
                  final dinner = double.tryParse(dinnerCtrl.text) ?? 0;
                  if (lunch <= 0 && dinner <= 0) {
                    showToast(sheetContext, 'Enter at least one meal.');
                    return;
                  }
                  Navigator.pop(sheetContext);
                  await _requestService.createMealRequest(
                    cottageId: data.profile.cottageId,
                    userId: data.profile.id,
                    requestDate: date,
                    lunch: lunch,
                    dinner: dinner,
                  );
                } else {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (amount <= 0) {
                    showToast(sheetContext, 'Enter a valid amount.');
                    return;
                  }
                  Navigator.pop(sheetContext);
                  await _requestService.createMealCostRequest(
                    cottageId: data.profile.cottageId,
                    userId: data.profile.id,
                    entryDate: date,
                    amount: amount,
                    description: descCtrl.text.trim(),
                  );
                }
                refresh();
              },
              child: const Text('Submit Request'),
            ),
          ],
        );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return FutureBuilder<_RequestData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFFDE7356),
            body: Center(child: CottageLoader()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFDE7356),
            body: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surface.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 40,
                      color: CottageColors.destructive,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load requests.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final canReviewMeals =
            data.profile.isSuperAdmin || data.profile.canAddMeals;
        final canReviewBazaar =
            data.profile.isSuperAdmin || data.profile.canAddBazaar;

        final pendingMeal = data.mealRequests
            .where((r) => r.status == RequestStatus.pending)
            .toList();
        final pendingCost = data.costRequests
            .where((r) => r.status == RequestStatus.pending)
            .toList();
        final historyMeal = data.mealRequests
            .where((r) => r.status != RequestStatus.pending)
            .toList();
        final historyCost = data.costRequests
            .where((r) => r.status != RequestStatus.pending)
            .toList();

        Widget mealTab() {
          if (pendingMeal.isEmpty) {
            return const EmptyState(icon: Icons.inbox_outlined, title: 'No pending meal requests.');
          }
          return RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, 0, 0, context.bottomNavClearance),
              children: [
                Text(
                  'Pending (${pendingMeal.length})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.surface.foreground),
                ),
                const SizedBox(height: 10),
                for (final r in pendingMeal)
                  _MealRequestCard(
                    request: r,
                    formatDate: _formatDate,
                    canReview: canReviewMeals,
                    onApprove: () => _approveMeal(r, data),
                    onReject: () => _rejectMeal(r, data),
                  ),
              ],
            ),
          );
        }

        Widget costTab() {
          if (pendingCost.isEmpty) {
            return const EmptyState(icon: Icons.inbox_outlined, title: 'No pending bazar cost requests.');
          }
          return RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, 0, 0, context.bottomNavClearance),
              children: [
                Text(
                  'Pending (${pendingCost.length})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.surface.foreground),
                ),
                const SizedBox(height: 10),
                for (final r in pendingCost)
                  _CostRequestCard(
                    request: r,
                    formatDate: _formatDate,
                    canReview: canReviewBazaar,
                    onApprove: () => _approveCost(r, data),
                    onReject: () => _rejectCost(r, data),
                  ),
              ],
            ),
          );
        }

        Widget historyTab() {
          if (historyMeal.isEmpty && historyCost.isEmpty) {
            return const EmptyState(icon: Icons.inbox_outlined, title: 'No reviewed requests yet.');
          }
          return RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, 0, 0, context.bottomNavClearance),
              children: [
                for (final r in historyMeal)
                  _MealRequestCard(
                    request: r,
                    formatDate: _formatDate,
                    canReview: false,
                    onApprove: () {},
                    onReject: () {},
                  ),
                for (final r in historyCost)
                  _CostRequestCard(
                    request: r,
                    formatDate: _formatDate,
                    canReview: false,
                    onApprove: () {},
                    onReject: () {},
                  ),
              ],
            ),
          );
        }

        final tabs = [mealTab(), costTab(), historyTab()];

        return Scaffold(
          backgroundColor: const Color(0xFFDE7356),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showNewRequest(data),
            backgroundColor: CottageColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'New Request',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DynamicRequestHeaderDelegate(
                    surface: surface,
                    safeAreaTop: MediaQuery.of(context).padding.top,
                  ),
                ),
              ];
            },
            body: Container(
              color: surface.card,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.responsivePadding,
                      16,
                      context.responsivePadding,
                      12,
                    ),
                    child: _RequestTabSwitcher(
                      activeIndex: _activeTabIndex,
                      onTap: (i) => setState(() => _activeTabIndex = i),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.responsivePadding),
                      child: tabs[_activeTabIndex],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Meal / Meal Cost / History pill switcher -- Figma's "Self driver
/// requirement" frame (230:1791): 3 equal-width chips, selected one filled
/// orange, unselected ones flat #FAFAFA.
class _RequestTabSwitcher extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;
  const _RequestTabSwitcher({required this.activeIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget item(int index, String label) {
      final active = activeIndex == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => onTap(index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFDE7356) : context.surface.background,
              border: Border.all(color: context.surface.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? Colors.white : context.surface.foreground,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3.2),
      decoration: BoxDecoration(
        color: context.surface.card,
        border: Border.all(color: context.surface.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          item(0, 'Meal'),
          const SizedBox(width: 3.2),
          item(1, 'Meal Cost'),
          const SizedBox(width: 3.2),
          item(2, 'History'),
        ],
      ),
    );
  }
}

class _MealRequestCard extends StatelessWidget {
  final MealRequest request;
  final String Function(String) formatDate;
  final bool canReview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _MealRequestCard({
    required this.request,
    required this.formatDate,
    required this.canReview,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return _RequestCardShell(
      title: request.memberName ?? 'Member',
      date: formatDate(request.requestDate),
      status: request.status,
      canReview: canReview,
      onApprove: onApprove,
      onReject: onReject,
      body: Row(
        children: [
          _StatField(label: 'Lunch', value: request.lunch.toStringAsFixed(request.lunch == request.lunch.roundToDouble() ? 0 : 1)),
          const SizedBox(width: 20),
          _StatField(label: 'Dinner', value: request.dinner.toStringAsFixed(request.dinner == request.dinner.roundToDouble() ? 0 : 1)),
        ],
      ),
    );
  }
}

class _CostRequestCard extends StatelessWidget {
  final MealCostRequest request;
  final String Function(String) formatDate;
  final bool canReview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _CostRequestCard({
    required this.request,
    required this.formatDate,
    required this.canReview,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return _RequestCardShell(
      title: request.memberName ?? 'Member',
      date: formatDate(request.entryDate),
      status: request.status,
      canReview: canReview,
      onApprove: onApprove,
      onReject: onReject,
      body: Row(
        children: [
          _StatField(label: 'Amount', value: '৳${request.amount.toStringAsFixed(0)}'),
          if (request.description?.isNotEmpty ?? false) ...[
            const SizedBox(width: 20),
            Expanded(
              child: _StatField(label: 'Items', value: request.description!),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatField extends StatelessWidget {
  final String label;
  final String value;
  const _StatField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: context.surface.mutedForeground)),
        const SizedBox(height: 2),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.surface.foreground),
        ),
      ],
    );
  }
}

/// Shared card shell for both request kinds -- Figma's 228:1795 frame:
/// avatar circle + name + date, a divider, the kind-specific stat row, then
/// full-width Approve (green)/Reject (white, red border) buttons.
class _RequestCardShell extends StatelessWidget {
  final String title;
  final String date;
  final Widget body;
  final RequestStatus status;
  final bool canReview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCardShell({
    required this.title,
    required this.date,
    required this.body,
    required this.status,
    required this.canReview,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface.background,
        border: Border.all(color: context.surface.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: context.surface.accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.surface.foreground),
                ),
              ),
              if (status == RequestStatus.pending)
                Text(date, style: TextStyle(fontSize: 11, color: context.surface.mutedForeground))
              else
                _StatusPill(status: status),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: context.surface.border),
          const SizedBox(height: 10),
          body,
          if (status == RequestStatus.pending && canReview) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onApprove,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF63B64E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Approve', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onReject,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0x66FF4F4F)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, size: 14, color: Color(0xFFFF4F4F)),
                          SizedBox(width: 6),
                          Text('Reject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFF4F4F))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final RequestStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final approved = status == RequestStatus.approved;
    final rejected = status == RequestStatus.rejected;
    final color = approved
        ? const Color(0xFF16A34A)
        : rejected
        ? CottageColors.destructive
        : context.surface.mutedForeground;
    final label = approved
        ? 'Approved'
        : rejected
        ? 'Rejected'
        : 'Cancelled';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _RequestKindChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RequestKindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? CottageColors.primary : surface.background,
          border: Border.all(
            color: selected ? CottageColors.primary : surface.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : surface.foreground,
          ),
        ),
      ),
    );
  }
}

class _RequestNumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _RequestNumberField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: surface.foreground),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '0'),
        ),
      ],
    );
  }
}

class _DynamicRequestHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final double safeAreaTop;

  _DynamicRequestHeaderDelegate({required this.surface, required this.safeAreaTop});

  @override
  double get minExtent => safeAreaTop + 56.0;

  @override
  double get maxExtent => safeAreaTop + 88.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: safeAreaTop + 56 - (shrinkOffset * 1.5).clamp(0, safeAreaTop + 56),
          child: const ColoredBox(color: Color(0xFFDE7356)),
        ),
        Positioned(
          top: (safeAreaTop + 56) * (1 - progress),
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20 * (1 - progress)),
                topRight: Radius.circular(20 * (1 - progress)),
              ),
            ),
          ),
        ),
        // Requests is a bottom-nav tab, not a pushed screen -- no back
        // button, so its title follows the same left inset as every other
        // tab root (Monthly Details/Meal) uses: `context.responsivePadding`
        // directly on the text, not the fixed left:4 used by pushed
        // sub-pages to make room for their back IconButton. A hardcoded
        // left:4 here happened to look right only on compact screens --
        // responsivePadding scales to 24/32 on medium/large ones, so the
        // fixed value drifted out of alignment with Meal's title exactly
        // the way the user noticed.
        Positioned(
          top: safeAreaTop,
          left: context.responsivePadding,
          right: context.responsivePadding,
          child: Text(
            'Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color.lerp(Colors.white, surface.foreground, progress),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DynamicRequestHeaderDelegate oldDelegate) => true;
}
