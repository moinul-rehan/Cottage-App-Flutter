import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../data/meal_models.dart';
import '../data/meal_service.dart';
import 'package:cottage/models/profile.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../../menu/data/member_service.dart';
import '../../requests/data/request_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/helpers/ui_helpers.dart';

/// Redesigned Meal section matching the Figma design.
/// Features a brand peach-orange header, sticky tabs for Meal Details, Bazar, and Deposit,
/// and custom list card designs for each.
class MealScreen extends StatefulWidget {
  const MealScreen({super.key});

  static final mealScreenKey = GlobalKey<_MealScreenState>();

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen>
    with SingleTickerProviderStateMixin {
  final _mealService = MealService();
  final _dashService = DashboardService();
  final _memberService = MemberService();
  final _requestService = RequestService();

  _MealData? _currentData;

  void triggerAction(String action) {
    final data = _currentData;
    if (data == null) return;
    if (action == 'add-meal') {
      _showAddMeal(data);
    } else if (action == 'request-meal') {
      _showRequestMeal(data);
    } else if (action == 'add-bazaar') {
      _showAddBazaar(data);
    } else if (action == 'request-cost') {
      _showRequestMealCost(data);
    } else if (action == 'add-deposit') {
      _showAddDeposit(data);
    }
  }

  late TabController _tabController;
  late Future<_MealData> _future;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTabIndex = _tabController.index;
        });
      }
    });
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_MealData> _load() async {
    final profile = await _dashService.getCurrentProfile();
    final monthKey = await _dashService.getActiveMonthKey(profile.cottageId);
    final members = await _memberService.getActiveMembers(profile.cottageId);
    final meals = await _mealService.getDailyMeals(monthKey);
    final bazaar = await _mealService.getBazaarEntries(monthKey);
    final deposits = await _mealService.getMealDeposits(monthKey);

    // Compute summaries
    double totalMeals = 0;
    double totalBazaar = 0;
    for (final m in meals) {
      totalMeals += m.count;
    }
    for (final b in bazaar) {
      totalBazaar += b.amount;
    }
    final mealRate = totalMeals > 0 ? totalBazaar / totalMeals : 0.0;

    return _MealData(
      profile: profile,
      monthKey: monthKey,
      members: members,
      meals: meals,
      bazaar: bazaar,
      deposits: deposits,
      totalMeals: totalMeals,
      totalBazaar: totalBazaar,
      mealRate: mealRate,
    );
  }

  // Block body -- see contacts_screen.dart's _refresh for why the arrow
  // form is a real bug (setState() callback implicitly returning a Future).
  void _refresh() => setState(() {
    _future = _load();
  });

  /// Shares a plain-text summary of whichever tab is currently active --
  /// same rationale/pattern as UtilityStatementScreen/UtilitiesScreen's
  /// _download (no PDF pipeline in this app yet, so a text export is the
  /// closest faithful stand-in for a real "download" action).
  void _download(_MealData data) {
    final monthLabel = _formatMonth(data.monthKey);
    final buffer = StringBuffer();
    switch (_activeTabIndex) {
      case 0:
        buffer.writeln('Meal Details -- $monthLabel\n');
        if (data.meals.isEmpty) buffer.writeln('No meal entries yet.');
        final byDate = <String, List<DailyMeal>>{};
        for (final m in data.meals) {
          (byDate[m.date] ??= []).add(m);
        }
        for (final date in byDate.keys.toList()..sort((a, b) => b.compareTo(a))) {
          buffer.writeln(date);
          for (final m in byDate[date]!) {
            buffer.writeln('  ${m.memberName ?? 'Member'}: ${m.count}');
          }
          buffer.writeln();
        }
        break;
      case 1:
        buffer.writeln('Bazar Entries -- $monthLabel\n');
        if (data.bazaar.isEmpty) buffer.writeln('No bazaar entries yet.');
        for (final e in data.bazaar) {
          buffer.writeln('${e.date}  ${e.memberName ?? 'Member'}');
          if (e.description?.isNotEmpty ?? false) {
            buffer.writeln('  ${e.description}');
          }
          buffer.writeln('  Amount: ${e.amount.toStringAsFixed(2)} tk\n');
        }
        break;
      default:
        buffer.writeln('Meal Deposits -- $monthLabel\n');
        if (data.deposits.isEmpty) buffer.writeln('No meal deposits yet.');
        for (final d in data.deposits) {
          buffer.writeln('${d.date}  ${d.memberName ?? 'Member'}');
          if (d.note?.isNotEmpty ?? false) buffer.writeln('  ${d.note}');
          buffer.writeln('  Amount: ${d.amount.toStringAsFixed(2)} tk\n');
        }
    }
    Share.share(buffer.toString(), subject: 'Monthly Details - $monthLabel');
  }

  String _formatMonth(String monthKey) {
    try {
      final parts = monthKey.split('-');
      if (parts.length < 2) return monthKey;
      final year = parts[0];
      final monthInt = int.tryParse(parts[1]) ?? 1;
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      if (monthInt < 1 || monthInt > 12) return monthKey;
      return '${months[monthInt - 1]} $year';
    } catch (_) {
      return monthKey;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return dateStr;
      final year = parts[0];
      final monthInt = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      if (monthInt < 1 || monthInt > 12) return dateStr;
      return '$day ${months[monthInt - 1]}, $year';
    } catch (_) {
      return dateStr;
    }
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _memberName(List<Profile> members, String? id) {
    if (id == null) return null;
    for (final m in members) {
      if (m.id == id) return m.displayName;
    }
    return null;
  }

  /// Flat list-picker sheet for the "Select member" drawer fields, matching
  /// the Figma "Add Deposit"/"Add Bazar Cost" drawers' member field, which
  /// is a plain tappable box rather than a native dropdown.
  Future<String?> _pickMember(
    BuildContext ctx,
    List<Profile> members,
    String? currentId,
  ) {
    return showCottageSheet<String>(
      context: ctx,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final m in members)
            ListTile(
              title: Text(m.displayName),
              trailing: m.id == currentId
                  ? const Icon(Icons.check, color: CottageColors.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, m.id),
            ),
        ],
      ),
    );
  }

  // --- Meal Add/Edit Modals ---

  /// Existing logged counts for [date], falling back to 0 for members with
  /// no entry yet -- used both to seed the Add Meal drawer and to refresh
  /// it whenever the picked date changes, so reopening/re-dating the
  /// drawer shows what's already logged instead of always resetting to 0
  /// (which would silently zero out real counts on save).
  Map<String, double> _countsForDate(_MealData data, String date) {
    final byUser = {
      for (final m in data.meals)
        if (m.date == date) m.userId: m.count,
    };
    return {for (final m in data.members) m.id: byUser[m.id] ?? 0};
  }

  void _showAddMeal(_MealData data) {
    final now = DateTime.now();
    String selectedDate = _isoDate(now);
    var counts = _countsForDate(data, selectedDate);

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final surface = ctx.surface;
          return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerHeader(
                icon: Icons.restaurant_menu_rounded,
                title: 'Add Meal',
                onClose: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 16),
              _DrawerDateField(
                label: 'Date',
                date: _formatDate(selectedDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.tryParse(selectedDate) ?? now,
                    firstDate: DateTime(now.year, now.month, 1),
                    lastDate: now,
                  );
                  if (picked != null) {
                    setSheetState(() {
                      selectedDate = _isoDate(picked);
                      counts = _countsForDate(data, selectedDate);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Meal count per member',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: surface.foreground,
                ),
              ),
              const SizedBox(height: 16),
              for (final member in data.members) ...[
                _MemberMealRow(
                  member: member,
                  count: counts[member.id]!,
                  onChanged: (v) => setSheetState(() => counts[member.id] = v),
                ),
                if (member != data.members.last)
                  const SizedBox(height: 8)
                else
                  const SizedBox(height: 16),
              ],
              _DrawerSaveButton(
                label: 'Save Meal Count',
                onPressed: () async {
                  Navigator.pop(ctx);
                  for (final member in data.members) {
                    await _mealService.upsertMeal(
                      userId: member.id,
                      monthKey: data.monthKey,
                      date: selectedDate,
                      count: counts[member.id]!,
                      cottageId: data.profile.cottageId,
                      createdBy: data.profile.id,
                    );
                  }
                  _refresh();
                },
              ),
            ],
          ),
        );
        },
      ),
    );
  }

  /// A member without `can_add_meals` can't write `daily_meals` directly --
  /// this submits a `meal_requests` row instead, for a manager/super admin
  /// to review from the Requests tab. Mirrors RequestMealForm.tsx: only
  /// today-or-later dates are allowed (unlike [_showAddMeal], which edits
  /// the past freely), since it doesn't make sense to *request* approval for
  /// a meal that's already been served.
  void _showRequestMeal(_MealData data) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String selectedDate = _isoDate(today);
    final lunchCtrl = TextEditingController(text: '0');
    final dinnerCtrl = TextEditingController(text: '0');

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerHeader(
                icon: Icons.send_outlined,
                title: 'Request Meal',
                onClose: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 16),
              _DrawerDateField(
                label: 'Date',
                date: _formatDate(selectedDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.tryParse(selectedDate) ?? today,
                    firstDate: today,
                    lastDate: DateTime(today.year, today.month + 3, today.day),
                  );
                  if (picked != null) {
                    setSheetState(() => selectedDate = _isoDate(picked));
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DrawerTextField(
                      label: 'Lunch',
                      controller: lunchCtrl,
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DrawerTextField(
                      label: 'Dinner',
                      controller: dinnerCtrl,
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DrawerSaveButton(
                label: 'Submit Request',
                onPressed: () async {
                  final lunch = double.tryParse(lunchCtrl.text) ?? 0;
                  final dinner = double.tryParse(dinnerCtrl.text) ?? 0;
                  Navigator.pop(ctx);
                  await _requestService.createMealRequest(
                    cottageId: data.profile.cottageId,
                    userId: data.profile.id,
                    requestDate: selectedDate,
                    lunch: lunch,
                    dinner: dinner,
                  );
                  if (mounted) {
                    showToast(context, 'Meal request submitted for review.');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMealForDate(
    String date,
    List<DailyMeal> mealsForDate,
    List<Profile> members,
    String cottageId,
    String monthKey,
    String createdBy,
  ) {
    final controllers = <String, TextEditingController>{};
    for (final member in members) {
      final meal = mealsForDate.firstWhere(
        (m) => m.userId == member.id,
        orElse: () => DailyMeal(
          userId: member.id,
          monthKey: monthKey,
          date: date,
          count: 0,
        ),
      );
      controllers[member.id] = TextEditingController(
        text: meal.count > 0
            ? meal.count.toStringAsFixed(meal.count % 1 == 0 ? 0 : 1)
            : '0',
      );
    }

    showCottageSheet(
      context: context,
      builder: (_) => CottageSheetContent(
        title: 'Edit Meals - ${_formatDate(date)}',
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final member in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: controllers[member.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              for (final member in members) {
                final count =
                    double.tryParse(controllers[member.id]?.text ?? '0') ?? 0;
                // If count is changed (or is non-zero), upsert it
                await _mealService.upsertMeal(
                  userId: member.id,
                  monthKey: monthKey,
                  date: date,
                  count: count,
                  cottageId: cottageId,
                  createdBy: createdBy,
                );
              }
              _refresh();
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  // --- Bazaar Add/Edit Modals ---

  void _showAddBazaar(_MealData data) {
    // No default selection -- the member must actively pick from the
    // dropdown rather than the sheet silently pre-picking the viewer, which
    // made it easy to save a bazar cost under the wrong member's name.
    String? selectedUserId;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final now = DateTime.now();
    String selectedDate = _isoDate(now);
    // Mirrors the web app's BazaarForm "credit_deposit" checkbox -- the
    // service already supported this (MealService.addBazaarEntry's
    // creditDeposit param), it just had no way to turn it on from this UI.
    bool creditDeposit = false;

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerHeader(
                icon: LucideIcons.shoppingBag,
                title: 'Add Bazar Cost',
                onClose: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 16),
              _DrawerDateField(
                label: 'Date',
                date: _formatDate(selectedDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.tryParse(selectedDate) ?? now,
                    firstDate: DateTime(now.year, now.month, 1),
                    lastDate: now,
                  );
                  if (picked != null) {
                    setSheetState(() => selectedDate = _isoDate(picked));
                  }
                },
              ),
              const SizedBox(height: 16),
              _DrawerMemberField(
                label: 'Member',
                selectedName: _memberName(data.members, selectedUserId),
                onTap: () async {
                  final picked = await _pickMember(
                    ctx,
                    data.members,
                    selectedUserId,
                  );
                  if (picked != null) {
                    setSheetState(() => selectedUserId = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              _DrawerTextField(
                label: 'Items Purchased',
                controller: descCtrl,
                hint: 'Rice, Egg, Rice, Egg, Oil',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _DrawerTextField(
                label: 'Total Amount',
                controller: amountCtrl,
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixText: '৳',
              ),
              if (selectedUserId != null) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () =>
                      setSheetState(() => creditDeposit = !creditDeposit),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: _drawerFieldDecoration(ctx.surface),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: creditDeposit,
                          onChanged: (v) =>
                              setSheetState(() => creditDeposit = v ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text.rich(
                              TextSpan(
                                text: 'Cost deposit to ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ctx.surface.foreground,
                                ),
                                children: [
                                  TextSpan(
                                    text: _memberName(
                                      data.members,
                                      selectedUserId,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        ' — credits this amount to their meal deposit',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _DrawerSaveButton(
                label: 'Save Bazar Cost',
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (selectedUserId == null) {
                    showToast(ctx, 'Select a member first.');
                    return;
                  }
                  if (amount <= 0) return;
                  Navigator.pop(ctx);
                  await _mealService.addBazaarEntry(
                    userId: selectedUserId!,
                    monthKey: data.monthKey,
                    amount: amount,
                    date: selectedDate,
                    cottageId: data.profile.cottageId,
                    description: descCtrl.text.trim(),
                    creditDeposit: creditDeposit,
                  );
                  _refresh();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A member without `can_add_bazaar` can't write `bazaar_entries` directly
  /// -- this submits a `meal_cost_requests` row instead, for a
  /// manager/super admin to review. Mirrors RequestMealCostForm.tsx.
  void _showRequestMealCost(_MealData data) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String selectedDate = _isoDate(today);
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerHeader(
                icon: Icons.send_outlined,
                title: 'Request Meal Cost',
                onClose: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 6),
              Text(
                'Once approved, this amount is credited straight to your meal deposit.',
                style: TextStyle(
                  fontSize: 12,
                  color: ctx.surface.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              _DrawerDateField(
                label: 'Date',
                date: _formatDate(selectedDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.tryParse(selectedDate) ?? today,
                    firstDate: DateTime(today.year, today.month, 1),
                    lastDate: today,
                  );
                  if (picked != null) {
                    setSheetState(() => selectedDate = _isoDate(picked));
                  }
                },
              ),
              const SizedBox(height: 16),
              _DrawerTextField(
                label: 'Amount',
                controller: amountCtrl,
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixText: '৳',
              ),
              const SizedBox(height: 16),
              _DrawerTextField(
                label: 'Description',
                controller: descCtrl,
                hint: 'What did you buy?',
                maxLines: 3,
                required: false,
              ),
              const SizedBox(height: 16),
              _DrawerSaveButton(
                label: 'Submit Request',
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (amount <= 0) return;
                  Navigator.pop(ctx);
                  await _requestService.createMealCostRequest(
                    cottageId: data.profile.cottageId,
                    userId: data.profile.id,
                    entryDate: selectedDate,
                    amount: amount,
                    description: descCtrl.text.trim(),
                  );
                  if (mounted) {
                    showToast(
                      context,
                      'Meal cost request submitted for review.',
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBazaar(BazaarEntry entry) {
    final amountCtrl = TextEditingController(
      text: entry.amount.toStringAsFixed(0),
    );
    final descCtrl = TextEditingController(text: entry.description ?? '');
    String selectedDate = entry.date;

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => CottageSheetContent(
          title: 'Edit Bazaar Entry',
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount (tk)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Items (Description)',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final currentParsed =
                    DateTime.tryParse(selectedDate) ?? DateTime.now();
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: currentParsed,
                  firstDate: DateTime(
                    currentParsed.year,
                    currentParsed.month,
                    1,
                  ),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setSheetState(() {
                    selectedDate =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(_formatDate(selectedDate)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _mealService.deleteBazaarEntry(entry.id);
                      _refresh();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CottageColors.destructive),
                      foregroundColor: CottageColors.destructive,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (amount <= 0) return;
                      Navigator.pop(context);
                      await _mealService.updateBazaarEntry(
                        id: entry.id,
                        amount: amount,
                        date: selectedDate,
                        description: descCtrl.text.trim(),
                      );
                      _refresh();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBazaarInfo(BazaarEntry entry) {
    showCottageSheet(
      context: context,
      builder: (_) => CottageSheetContent(
        title: 'Bazaar Detail',
        children: [
          ListTile(
            title: const Text(
              'Shopper',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            subtitle: Text(
              entry.memberName ?? 'Member',
              style: const TextStyle(fontSize: 15),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text(
              'Amount',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            subtitle: Text(
              '${entry.amount.toStringAsFixed(2)} tk',
              style: const TextStyle(fontSize: 15),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text(
              'Date',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            subtitle: Text(
              _formatDate(entry.date),
              style: const TextStyle(fontSize: 15),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text(
              'Items/Description',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            subtitle: Text(
              (entry.description != null && entry.description!.isNotEmpty)
                  ? entry.description!
                  : 'No items detailed.',
              style: const TextStyle(fontSize: 15),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- Deposit Add/Edit Modals ---

  void _showAddDeposit(_MealData data) {
    // No default selection -- same reasoning as _showAddBazaar: a
    // pre-picked member makes it easy to save a deposit under the wrong
    // person's name.
    String? selectedUserId;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final now = DateTime.now();
    String selectedDate = _isoDate(now);

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerHeader(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Add Deposit',
                onClose: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 16),
              _DrawerMemberField(
                label: 'Member',
                selectedName: _memberName(data.members, selectedUserId),
                onTap: () async {
                  final picked = await _pickMember(
                    ctx,
                    data.members,
                    selectedUserId,
                  );
                  if (picked != null) {
                    setSheetState(() => selectedUserId = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              _DrawerTextField(
                label: 'Amount',
                controller: amountCtrl,
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixText: '৳',
              ),
              const SizedBox(height: 16),
              _DrawerDateField(
                label: 'Date',
                date: _formatDate(selectedDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.tryParse(selectedDate) ?? now,
                    firstDate: DateTime(now.year, now.month, 1),
                    lastDate: now,
                  );
                  if (picked != null) {
                    setSheetState(() => selectedDate = _isoDate(picked));
                  }
                },
              ),
              const SizedBox(height: 16),
              _DrawerTextField(
                label: 'Note (optional)',
                controller: noteCtrl,
                hint: 'e.g. Cash handover',
                maxLines: 3,
                required: false,
              ),
              const SizedBox(height: 16),
              _DrawerSaveButton(
                label: 'Save Deposit',
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (selectedUserId == null) {
                    showToast(ctx, 'Select a member first.');
                    return;
                  }
                  if (amount <= 0) return;
                  Navigator.pop(ctx);
                  await _mealService.addMealDeposit(
                    userId: selectedUserId!,
                    monthKey: data.monthKey,
                    amount: amount,
                    date: selectedDate,
                    cottageId: data.profile.cottageId,
                    note: noteCtrl.text.trim(),
                  );
                  _refresh();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDeposit(MealDeposit entry) {
    final amountCtrl = TextEditingController(
      text: entry.amount.toStringAsFixed(0),
    );
    final noteCtrl = TextEditingController(text: entry.note ?? '');
    String selectedDate = entry.date;

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => CottageSheetContent(
          title: 'Edit Meal Deposit',
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount (tk)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final currentParsed =
                    DateTime.tryParse(selectedDate) ?? DateTime.now();
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: currentParsed,
                  firstDate: DateTime(
                    currentParsed.year,
                    currentParsed.month,
                    1,
                  ),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setSheetState(() {
                    selectedDate =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(_formatDate(selectedDate)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _mealService.deleteMealDeposit(entry.id);
                      _refresh();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CottageColors.destructive),
                      foregroundColor: CottageColors.destructive,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (amount <= 0) return;
                      Navigator.pop(context);
                      await _mealService.updateMealDeposit(
                        id: entry.id,
                        amount: amount,
                        date: selectedDate,
                        note: noteCtrl.text.trim(),
                      );
                      _refresh();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The card-level trash icon (Figma: pencil + trash sit side by side on
  /// every Bazar/Deposit card, not just buried inside the edit sheet's own
  /// "Delete" button) -- both call the same [MealService.deleteBazaarEntry]
  /// already used there.
  /// Deletes every member's meal count for [date] in one go -- the Meal
  /// Details card's unit is a whole day, not one member, so its delete icon
  /// mirrors web's DeleteMealRowButton.tsx wording and semantics exactly
  /// rather than the per-row delete the Bazar/Deposit cards use.
  void _confirmDeleteMealDay(_MealData data, String date) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete this day's meals?"),
        content: Text(
          "Removes every member's meal count for ${_formatDate(date)}. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _mealService.deleteDailyMealsForDate(
                monthKey: data.monthKey,
                date: date,
              );
              _refresh();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: CottageColors.destructive),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBazaar(BazaarEntry entry) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this bazaar entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _mealService.deleteBazaarEntry(entry.id);
              _refresh();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: CottageColors.destructive),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDeposit(MealDeposit entry) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this meal deposit?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _mealService.deleteMealDeposit(entry.id);
              _refresh();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: CottageColors.destructive),
            ),
          ),
        ],
      ),
    );
  }

  // --- Segmented TabBar widgets ---

  Widget _buildTabBar(CottageSurface surface) {
    return Container(
      padding: const EdgeInsets.all(3.2),
      decoration: BoxDecoration(
        color: surface.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surface.border, width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabItem(0, 'Meal Details', surface)),
          const SizedBox(width: 3.2),
          Expanded(child: _buildTabItem(1, 'Bazar', surface)),
          const SizedBox(width: 3.2),
          Expanded(child: _buildTabItem(2, 'Deposit', surface)),
        ],
      ),
    );
  }

  // Text-only, matching Figma (no per-tab icon) -- and matching
  // UtilitiesScreen's segmented tab bar, which never had one either, so the
  // two "Details" pages' tab bars now read as the same control.
  Widget _buildTabItem(int index, String title, CottageSurface surface) {
    final active = _activeTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTabIndex = index;
          _tabController.animateTo(index);
        });
      },
      child: Container(
        height: 38.61,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? CottageColors.primary : surface.background,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
            color: active ? Colors.white : surface.foreground,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return FutureBuilder<_MealData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: CottageColors.primary,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
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
                      'Could not load meal data.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: surface.foreground),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        _currentData = data;

        return Scaffold(
          backgroundColor: CottageColors.primary,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DynamicMealHeaderDelegate(
                    surface: surface,
                    tabBar: _buildTabBar(surface),
                    monthText: _formatMonth(data.monthKey),
                    onDownload: () => _download(data),
                    safeAreaTop: MediaQuery.of(context).padding.top,
                  ),
                ),
              ];
            },
            body: Container(
              color: surface.card,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _DailyMealsTab(
                    data: data,
                    onRefresh: _refresh,
                    onEditMeal: (date, entries) => _showEditMealForDate(
                      date,
                      entries,
                      data.members,
                      data.profile.cottageId,
                      data.monthKey,
                      data.profile.id,
                    ),
                    onDeleteDay: (date) => _confirmDeleteMealDay(data, date),
                  ),
                  _BazaarTab(
                    data: data,
                    onRefresh: _refresh,
                    onEditBazaar: _showEditBazaar,
                    onShowInfo: _showBazaarInfo,
                    onDeleteBazaar: _confirmDeleteBazaar,
                  ),
                  _DepositTab(
                    data: data,
                    onRefresh: _refresh,
                    onEditDeposit: _showEditDeposit,
                    onDeleteDeposit: _confirmDeleteDeposit,
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

class _MealData {
  final Profile profile;
  final String monthKey;
  final List<Profile> members;
  final List<DailyMeal> meals;
  final List<BazaarEntry> bazaar;
  final List<MealDeposit> deposits;
  final double totalMeals;
  final double totalBazaar;
  final double mealRate;

  const _MealData({
    required this.profile,
    required this.monthKey,
    required this.members,
    required this.meals,
    required this.bazaar,
    required this.deposits,
    required this.totalMeals,
    required this.totalBazaar,
    required this.mealRate,
  });
}

// --- Meal Details Tab ---

class _DailyMealsTab extends StatelessWidget {
  final _MealData data;
  final VoidCallback onRefresh;
  final Function(String, List<DailyMeal>) onEditMeal;
  final Function(String) onDeleteDay;

  const _DailyMealsTab({
    required this.data,
    required this.onRefresh,
    required this.onDeleteDay,
    required this.onEditMeal,
  });

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return dateStr;
      final year = parts[0];
      final monthInt = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      if (monthInt < 1 || monthInt > 12) return dateStr;
      return '$day ${months[monthInt - 1]}, $year';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.meals.isEmpty) {
      return EmptyState(
        icon: Icons.restaurant_rounded,
        title: 'No meals recorded',
        subtitle: 'Start tracking meals for this month.',
      );
    }

    final surface = context.surface;

    // Group meals by date
    final grouped = <String, List<DailyMeal>>{};
    for (final meal in data.meals) {
      grouped.putIfAbsent(meal.date, () => []).add(meal);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsivePadding,
          vertical: 8,
        ),
        itemCount: dates.length + 1,
        itemBuilder: (context, index) {
          if (index == dates.length) return SizedBox(height: context.bottomNavClearance);
          final date = dates[index];
          final entries = grouped[date]!;

          return Container(
            margin: const EdgeInsets.only(bottom: 16), // Gap between cards
            padding: const EdgeInsets.all(
              4,
            ), // Figma has 4px padding for the card wrapper
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.circular(8), // Figma: 8.043px
              border: Border.all(color: surface.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header: Date Badge & Edit button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: surface.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: surface.border, width: 0.8),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w400, // Figma: Poppins Regular
                            color: surface.foreground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => onEditMeal(date, entries),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: CottageColors.primary,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: surface.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(color: surface.border, width: 0.8),
                        ),
                        fixedSize: const Size(38, 38),
                        // Without this, IconButton still reserves Material's
                        // default 48dp minimum tap-target height as invisible
                        // padding around the visually-smaller 38x38 box
                        // (fixedSize alone only caps the visual box, not the
                        // tap target) -- that inflated the header Row's real
                        // height, throwing off the card's top-padding vs.
                        // row-to-content gaps even though both are coded as
                        // the same 4px.
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => onDeleteDay(date),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: CottageColors.destructive,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: surface.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(color: surface.border, width: 0.8),
                        ),
                        fixedSize: const Size(38, 38),
                        // Without this, IconButton still reserves Material's
                        // default 48dp minimum tap-target height as invisible
                        // padding around the visually-smaller 38x38 box
                        // (fixedSize alone only caps the visual box, not the
                        // tap target) -- that inflated the header Row's real
                        // height, throwing off the card's top-padding vs.
                        // row-to-content gaps even though both are coded as
                        // the same 4px.
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4), // 4px gap in Figma
                // Card grid of members & meal counts. Figma's row is a flex
                // row of up to 3 equal-width ("flex-1", fill) tiles that
                // each hug their own content height -- reproduced here as a
                // Column of Rows (chunked 3 at a time) with Expanded tiles,
                // rather than a fixed-aspect-ratio GridView, so a trailing
                // partial row (e.g. 4 or 5 members) still fills the row
                // width evenly instead of leaving empty grid cells.
                for (var i = 0; i < entries.length; i += 3) ...[
                  if (i > 0) const SizedBox(height: 4),
                  Row(
                    children: [
                      for (var j = i; j < i + 3 && j < entries.length; j++) ...[
                        if (j > i) const SizedBox(width: 4),
                        Expanded(child: _MealCountTile(entry: entries[j])),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MealCountTile extends StatelessWidget {
  final DailyMeal entry;
  const _MealCountTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: surface.background,
        border: Border.all(color: surface.border, width: 0.8),
        borderRadius: BorderRadius.circular(
          4,
        ), // Figma: 4px (not 8 -- smaller than the other card radii)
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.memberName ?? 'Member',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CottageColors.primary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8), // Figma: gap-8 inside this cell
          Divider(height: 1, color: surface.border, thickness: 0.8),
          const SizedBox(height: 8),
          Text(
            entry.count.toStringAsFixed(entry.count % 1 == 0 ? 0 : 1),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: surface.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Bazar Tab ---

class _BazaarTab extends StatelessWidget {
  final _MealData data;
  final VoidCallback onRefresh;
  final Function(BazaarEntry) onEditBazaar;
  final Function(BazaarEntry) onShowInfo;
  final Function(BazaarEntry) onDeleteBazaar;

  const _BazaarTab({
    required this.data,
    required this.onRefresh,
    required this.onEditBazaar,
    required this.onShowInfo,
    required this.onDeleteBazaar,
  });

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return dateStr;
      final year = parts[0];
      final monthInt = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      if (monthInt < 1 || monthInt > 12) return dateStr;
      return '$day ${months[monthInt - 1]}, $year';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.bazaar.isEmpty) {
      return EmptyState(
        icon: LucideIcons.shoppingBag,
        title: 'No bazaar entries',
        subtitle: 'Record grocery purchases for this month.',
      );
    }

    final surface = context.surface;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsivePadding,
          vertical: 8,
        ),
        itemCount: data.bazaar.length + 1,
        itemBuilder: (context, index) {
          if (index == data.bazaar.length) return SizedBox(height: context.bottomNavClearance);
          final entry = data.bazaar[index];

          return Container(
            margin: const EdgeInsets.only(
              bottom: 16,
            ), // Same gap as Meal Detail
            padding: const EdgeInsets.all(4), // 4px padding for outer card
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: surface.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header: Date & Visibility/Edit buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: surface.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: surface.border, width: 0.8),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatDate(entry.date),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: surface.foreground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => onShowInfo(entry),
                          icon: Icon(
                            Icons.visibility_outlined,
                            color: surface.foreground,
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: surface.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: BorderSide(
                                color: surface.border,
                                width: 0.8,
                              ),
                            ),
                            fixedSize: const Size(38, 38),
                        // Without this, IconButton still reserves Material's
                        // default 48dp minimum tap-target height as invisible
                        // padding around the visually-smaller 38x38 box
                        // (fixedSize alone only caps the visual box, not the
                        // tap target) -- that inflated the header Row's real
                        // height, throwing off the card's top-padding vs.
                        // row-to-content gaps even though both are coded as
                        // the same 4px.
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => onEditBazaar(entry),
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: CottageColors.primary,
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: surface.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: BorderSide(
                                color: surface.border,
                                width: 0.8,
                              ),
                            ),
                            fixedSize: const Size(38, 38),
                        // Without this, IconButton still reserves Material's
                        // default 48dp minimum tap-target height as invisible
                        // padding around the visually-smaller 38x38 box
                        // (fixedSize alone only caps the visual box, not the
                        // tap target) -- that inflated the header Row's real
                        // height, throwing off the card's top-padding vs.
                        // row-to-content gaps even though both are coded as
                        // the same 4px.
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => onDeleteBazaar(entry),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: CottageColors.destructive,
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: surface.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: BorderSide(
                                color: surface.border,
                                width: 0.8,
                              ),
                            ),
                            fixedSize: const Size(38, 38),
                        // Without this, IconButton still reserves Material's
                        // default 48dp minimum tap-target height as invisible
                        // padding around the visually-smaller 38x38 box
                        // (fixedSize alone only caps the visual box, not the
                        // tap target) -- that inflated the header Row's real
                        // height, throwing off the card's top-padding vs.
                        // row-to-content gaps even though both are coded as
                        // the same 4px.
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4), // 4px gap from Figma
                // Card content row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Avatar & Name
                    Container(
                      width: 109,
                      height: 99,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: surface.background,
                        border: Border.all(color: surface.border, width: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 17.5, // 35px diameter
                            backgroundColor: CottageColors.primary.withValues(
                              alpha: 0.1,
                            ),
                            backgroundImage:
                                entry.avatarUrl != null &&
                                    entry.avatarUrl!.isNotEmpty
                                ? NetworkImage(entry.avatarUrl!)
                                : null,
                            child:
                                entry.avatarUrl == null ||
                                    entry.avatarUrl!.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: CottageColors.primary,
                                    size: 20,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.memberName ?? 'Member',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: CottageColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4), // 4px gap in Figma
                    // Right Column: Items speech bubble & Cost Strip
                    // Right Column: Items speech bubble & Cost Strip
                    Expanded(
                      child: SizedBox(
                        height: 99,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Items description speech bubble
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: surface.toneOrangeBg, // Soft peach tint
                                  border: Border.all(
                                    color: surface.border,
                                    width: 0.8,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  (entry.description != null &&
                                          entry.description!.isNotEmpty)
                                      ? entry.description!
                                      : 'No items detailed',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: surface.foreground,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4), // 4px gap in Figma
                            // Cost info strip
                            Container(
                              height: 29, // From Figma
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: surface.background,
                                border: Border.all(
                                  color: surface.border,
                                  width: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    'Total Amount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: CottageColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Container(
                                      height: 21,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: surface.border,
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${entry.amount.toStringAsFixed(0)} tk',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: surface.foreground,
                                    ),
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
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Deposit Tab ---

class _DepositTab extends StatelessWidget {
  final _MealData data;
  final VoidCallback onRefresh;
  final Function(MealDeposit) onEditDeposit;
  final Function(MealDeposit) onDeleteDeposit;

  const _DepositTab({
    required this.data,
    required this.onRefresh,
    required this.onEditDeposit,
    required this.onDeleteDeposit,
  });

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return dateStr;
      final year = parts[0];
      final monthInt = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      if (monthInt < 1 || monthInt > 12) return dateStr;
      return '$day ${months[monthInt - 1]}, $year';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.deposits.isEmpty) {
      return EmptyState(
        icon: Icons.monetization_on_rounded,
        title: 'No deposits recorded',
        subtitle: 'Record roommate meal deposits for this month.',
      );
    }

    final surface = context.surface;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsivePadding,
          vertical: 8,
        ),
        itemCount: data.deposits.length + 1,
        itemBuilder: (context, index) {
          if (index == data.deposits.length) return SizedBox(height: context.bottomNavClearance);
          final entry = data.deposits[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 16), // Gap between cards
            padding: const EdgeInsets.all(4), // 4px padding for outer card
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: surface.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header: Date & Edit button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: surface.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: surface.border, width: 0.8),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatDate(entry.date),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: surface.foreground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => onEditDeposit(entry),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: CottageColors.primary,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: surface.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(color: surface.border, width: 0.8),
                        ),
                        fixedSize: const Size(38, 38),
                        // Without this, IconButton still reserves Material's
                        // default 48dp minimum tap-target height as invisible
                        // padding around the visually-smaller 38x38 box
                        // (fixedSize alone only caps the visual box, not the
                        // tap target) -- that inflated the header Row's real
                        // height, throwing off the card's top-padding vs.
                        // row-to-content gaps even though both are coded as
                        // the same 4px.
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => onDeleteDeposit(entry),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: CottageColors.destructive,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: surface.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(color: surface.border, width: 0.8),
                        ),
                        fixedSize: const Size(38, 38),
                        // Without this, IconButton still reserves Material's
                        // default 48dp minimum tap-target height as invisible
                        // padding around the visually-smaller 38x38 box
                        // (fixedSize alone only caps the visual box, not the
                        // tap target) -- that inflated the header Row's real
                        // height, throwing off the card's top-padding vs.
                        // row-to-content gaps even though both are coded as
                        // the same 4px.
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4), // 4px gap in Figma
                // Card content row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Avatar & Name
                    Container(
                      width: 109,
                      height: 99,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: surface.background,
                        border: Border.all(color: surface.border, width: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 17.5, // 35px diameter
                            backgroundColor: CottageColors.primary.withValues(
                              alpha: 0.1,
                            ),
                            backgroundImage:
                                entry.avatarUrl != null &&
                                    entry.avatarUrl!.isNotEmpty
                                ? NetworkImage(entry.avatarUrl!)
                                : null,
                            child:
                                entry.avatarUrl == null ||
                                    entry.avatarUrl!.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: CottageColors.primary,
                                    size: 20,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.memberName ?? 'Member',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: CottageColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4), // 4px gap in Figma
                    // Right Column: Note bubble & Amount Strip
                    Expanded(
                      child: SizedBox(
                        height: 99,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Note description bubble
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: surface.background,
                                  border: Border.all(
                                    color: surface.border,
                                    width: 0.8,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  (entry.note != null && entry.note!.isNotEmpty)
                                      ? entry.note!
                                      : 'Manual deposit',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: surface.mutedForeground, // Muted grey
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4), // 4px gap in Figma
                            // Amount info strip
                            Container(
                              height: 29, // From Figma
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: surface.background,
                                border: Border.all(
                                  color: surface.border,
                                  width: 0.8,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    'Total Amount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: CottageColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Container(
                                      height: 21,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: surface.border,
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${entry.amount.toStringAsFixed(0)} tk',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: surface.foreground,
                                    ),
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DynamicMealHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final Widget tabBar;
  final String monthText;
  final VoidCallback onDownload;
  final double safeAreaTop;

  _DynamicMealHeaderDelegate({
    required this.surface,
    required this.tabBar,
    required this.monthText,
    required this.onDownload,
    required this.safeAreaTop,
  });

  @override
  double get minExtent => safeAreaTop + 150.0;

  @override
  double get maxExtent => safeAreaTop + 234.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: Orange top, White bottom
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height:
              safeAreaTop +
              56 -
              (shrinkOffset * 1.5).clamp(0, safeAreaTop + 56),
          child: Container(color: CottageColors.primary),
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

        // Expanded Content (Fades out)
        if (progress < 1.0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 1.0 - progress,
              child: IgnorePointer(
                ignoring: progress > 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Orange Header Content
                    Container(
                      height: safeAreaTop + 56,
                      padding: EdgeInsets.only(
                        top: safeAreaTop,
                        left: context.responsivePadding,
                        right: context.responsivePadding,
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Monthly Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 11), // Figma: gap-11
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(36),
                            ),
                            child: Text(
                              monthText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: CottageColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // White Card Content (Details)
                    Padding(
                      padding: EdgeInsets.only(
                        left: context.responsivePadding,
                        right: context.responsivePadding,
                        top: 16,
                      ),
                      child: Text(
                        "Full meal, deposit and cost records for every member in the active month.",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: surface.foreground,
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Collapsed Content (Fades in)
        if (progress > 0.0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: progress,
              child: IgnorePointer(
                ignoring: progress < 0.5,
                child: Container(
                  padding: EdgeInsets.only(
                    top: safeAreaTop + 8,
                    left: context.responsivePadding,
                    right: context.responsivePadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Monthly Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: surface.foreground,
                            ),
                          ),
                          const SizedBox(width: 11), // Figma: gap-11
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: CottageColors.primary,
                              borderRadius: BorderRadius.circular(36),
                            ),
                            child: Text(
                              monthText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Common bottom elements (Download Button & TabBar)
        Positioned(
          left: context.responsivePadding,
          right: context.responsivePadding,
          bottom: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onDownload,
                    icon: Icon(
                      Icons.download_rounded,
                      color: surface.foreground,
                      size: 18,
                    ),
                    label: Text(
                      'Download',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: surface.foreground,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: surface.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(1000),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              tabBar,
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DynamicMealHeaderDelegate oldDelegate) {
    return true;
  }
}

// --- Shared "Add X" drawer building blocks (Figma node 75:1127: "Add Meal
// - Drawer" / "Add Deposit - Drawer" / "Add Bazar Cost - Drawer") ---

/// Slightly darker orange used by every drawer's primary Save button, per
/// the Figma spec (#d1593b) -- distinct from [CottageColors.primary] used
/// on the tab bar/member-initial chips.
const _kDrawerAccent = Color(0xFFD1593B);

BoxDecoration _drawerFieldDecoration(CottageSurface surface) => BoxDecoration(
  color: surface.background,
  border: Border.all(color: surface.border),
  borderRadius: BorderRadius.circular(10),
);

/// Drag handle (rendered by [showCottageSheet]) + icon/title/close row
/// shared by every "Add X" drawer.
class _DrawerHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onClose;
  const _DrawerHeader({
    required this.icon,
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Row(
      children: [
        Icon(icon, size: 20, color: surface.foreground),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: surface.foreground,
            ),
          ),
        ),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: surface.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.close, size: 16, color: surface.foreground),
          ),
        ),
      ],
    );
  }
}

class _DrawerFieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _DrawerFieldLabel(this.text, {this.required = true});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: TextStyle(fontSize: 13, color: surface.foreground)),
        if (required) ...[
          const SizedBox(width: 2),
          const Text(
            '*',
            style: TextStyle(fontSize: 13, color: Color(0xFFCC4F4F)),
          ),
        ],
      ],
    );
  }
}

class _DrawerDateField extends StatelessWidget {
  final String label;
  final String date;
  final VoidCallback onTap;
  const _DrawerDateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DrawerFieldLabel(label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: _drawerFieldDecoration(surface),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: surface.foreground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date,
                    style: TextStyle(fontSize: 13, color: surface.foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tappable "Select member" box (opens [_MealScreenState._pickMember])
/// rather than a native dropdown, matching the flat Figma field style.
class _DrawerMemberField extends StatelessWidget {
  final String label;
  final String? selectedName;
  final VoidCallback onTap;
  const _DrawerMemberField({
    required this.label,
    required this.selectedName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DrawerFieldLabel(label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: _drawerFieldDecoration(surface),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedName ?? 'Select member',
                    style: TextStyle(
                      fontSize: 13,
                      color: selectedName == null
                          ? surface.mutedForeground
                          : surface.foreground,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: surface.foreground,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawerTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? prefixText;
  final bool required;
  const _DrawerTextField({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.prefixText,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DrawerFieldLabel(label, required: required),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: _drawerFieldDecoration(surface),
          child: Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (prefixText != null) ...[
                Text(
                  prefixText!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: surface.mutedForeground,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  style: TextStyle(fontSize: 13, color: surface.foreground),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: surface.mutedForeground,
                    ),
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DrawerSaveButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _DrawerSaveButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _kDrawerAccent,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

/// Member row in the "Add Meal" drawer: initial-avatar chip + name +
/// minus/count/plus stepper (replacing the old lunch/dinner split inputs --
/// the Figma design and the underlying `daily_meals.count` column are both
/// a single per-member count, so the stepper is the more faithful UI).
class _MemberMealRow extends StatefulWidget {
  final Profile member;
  final double count;
  final ValueChanged<double> onChanged;
  const _MemberMealRow({
    required this.member,
    required this.count,
    required this.onChanged,
  });

  @override
  State<_MemberMealRow> createState() => _MemberMealRowState();
}

class _MemberMealRowState extends State<_MemberMealRow> {
  late final _controller = TextEditingController(text: _format(widget.count));
  final _focusNode = FocusNode();

  static String _format(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _MemberMealRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only resync the field's text from the parent's value while it isn't
    // being actively typed into, so a +/- tap (which changes widget.count
    // from outside this State) updates the display without clobbering
    // whatever the user is mid-typing.
    if (!_focusNode.hasFocus && oldWidget.count != widget.count) {
      _controller.text = _format(widget.count);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = double.tryParse(_controller.text);
    if (parsed == null || parsed < 0) {
      _controller.text = _format(widget.count);
      return;
    }
    _controller.text = _format(parsed);
    if (parsed != widget.count) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final member = widget.member;
    final count = widget.count;
    final initial = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _drawerFieldDecoration(surface),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: surface.toneOrangeBg,
              borderRadius: BorderRadius.circular(16),
              image: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(member.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (member.avatarUrl != null && member.avatarUrl!.isNotEmpty)
                ? null
                : Text(
                    initial,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: CottageColors.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              member.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: surface.foreground,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.remove,
            // Steps by half a meal, not a whole one -- meal counts are
            // commonly fractional here (skip dinner but eat lunch = 0.5),
            // so stepping by 1 could never reach a half-meal value at all.
            onTap: count > 0 ? () => widget.onChanged(count - 0.5) : null,
          ),
          SizedBox(
            width: 40,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              // Free typing for any count (e.g. 1.25) -- the +/- buttons
              // above only step by 0.5, this is the direct-entry path for
              // anything else, per the ask to keep both.
              onSubmitted: (_) => _commit(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: surface.foreground,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
                // Overrides the app-wide InputDecorationTheme's
                // filled:true/fillColor default -- this field sits inside
                // the row's own field background, so it should read as
                // plain inline text, not a nested filled box.
                filled: false,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            onTap: () => widget.onChanged(count + 0.5),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surface.muted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? surface.mutedForeground : surface.foreground,
        ),
      ),
    );
  }
}
