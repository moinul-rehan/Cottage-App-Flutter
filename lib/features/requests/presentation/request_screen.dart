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

/// "Request" inbox -- takes over the Home tab's neighbouring slot in the
/// bottom nav for members who can manage meal/bazaar requests (mirrors the
/// web's MobileBottomNav: Notices tab is swapped for this one when
/// `canManageMealRequests` is true). Lists every meal/bazaar-cost request a
/// member has submitted,
/// with Approve/Reject for whoever can review them (RLS already scopes
/// `select`/`update` on both tables to reviewers + the requester
/// themselves, so no extra client-side filtering is needed here). Also
/// exposes a "New Request" action so a member without can_add_meals/
/// can_add_bazaar has somewhere to submit one from.
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

class _RequestScreenState extends State<RequestScreen>
    with SingleTickerProviderStateMixin {
  final _requestService = RequestService();
  final _dashService = DashboardService();
  late Future<_RequestData> _future;
  late TabController _tabController;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
  void refresh() => setState(() => _future = _load());

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
            backgroundColor: CottageColors.primary,
            body: Center(child: CottageLoader()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: CottageColors.primary,
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

        Widget list({
          required List<MealRequest> meals,
          required List<MealCostRequest> costs,
          required String emptyTitle,
        }) {
          if (meals.isEmpty && costs.isEmpty) {
            return EmptyState(icon: Icons.inbox_outlined, title: emptyTitle);
          }
          return RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                context.responsivePadding,
                16,
                context.responsivePadding,
                context.bottomNavClearance,
              ),
              children: [
                for (final r in meals)
                  _MealRequestCard(
                    request: r,
                    formatDate: _formatDate,
                    canReview: canReviewMeals,
                    onApprove: () => _approveMeal(r, data),
                    onReject: () => _rejectMeal(r, data),
                  ),
                for (final r in costs)
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

        return Scaffold(
          backgroundColor: CottageColors.primary,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showNewRequest(data),
            backgroundColor: CottageColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'New Request',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.responsivePadding,
                    8,
                    context.responsivePadding,
                    16,
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Requests',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: surface.card,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            context.responsivePadding,
                            16,
                            context.responsivePadding,
                            0,
                          ),
                          child: _RequestTabSwitcher(
                            activeIndex: _activeTabIndex,
                            pendingCount:
                                pendingMeal.length + pendingCost.length,
                            onTap: (i) => setState(() {
                              _activeTabIndex = i;
                              _tabController.animateTo(i);
                            }),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              list(
                                meals: pendingMeal,
                                costs: pendingCost,
                                emptyTitle: 'No pending requests.',
                              ),
                              list(
                                meals: historyMeal,
                                costs: historyCost,
                                emptyTitle: 'No reviewed requests yet.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RequestTabSwitcher extends StatelessWidget {
  final int activeIndex;
  final int pendingCount;
  final ValueChanged<int> onTap;
  const _RequestTabSwitcher({
    required this.activeIndex,
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    Widget item(int index, String label) {
      final active = activeIndex == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => onTap(index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? CottageColors.primary : surface.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : surface.foreground,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3.2),
      decoration: BoxDecoration(
        color: surface.card,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          item(0, pendingCount > 0 ? 'Pending ($pendingCount)' : 'Pending'),
          const SizedBox(width: 3.2),
          item(1, 'History'),
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
      icon: Icons.restaurant_menu_rounded,
      title: request.memberName ?? 'Member',
      subtitle:
          '${formatDate(request.requestDate)} · Lunch ${request.lunch.toStringAsFixed(1)} · Dinner ${request.dinner.toStringAsFixed(1)}',
      status: request.status,
      canReview: canReview,
      onApprove: onApprove,
      onReject: onReject,
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
      icon: Icons.shopping_basket_outlined,
      title: request.memberName ?? 'Member',
      subtitle:
          '${formatDate(request.entryDate)} · ৳${request.amount.toStringAsFixed(0)}'
          '${(request.description?.isNotEmpty ?? false) ? ' · ${request.description}' : ''}',
      status: request.status,
      canReview: canReview,
      onApprove: onApprove,
      onReject: onReject,
    );
  }
}

class _RequestCardShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final RequestStatus status;
  final bool canReview;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCardShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.canReview,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface.card,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: surface.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: CottageColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: surface.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: surface.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              if (status != RequestStatus.pending) _StatusPill(status: status),
            ],
          ),
          if (status == RequestStatus.pending && canReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: surface.border),
                      foregroundColor: surface.foreground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    child: const Text('Approve'),
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
        : const Color(0xFF7A818D);
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
