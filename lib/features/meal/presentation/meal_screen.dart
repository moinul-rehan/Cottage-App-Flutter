import 'package:flutter/material.dart';
import '../data/meal_models.dart';
import '../data/meal_service.dart';
import 'package:cottage/models/profile.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../../menu/data/member_service.dart';
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

class _MealScreenState extends State<MealScreen> with SingleTickerProviderStateMixin {
  final _mealService = MealService();
  final _dashService = DashboardService();
  final _memberService = MemberService();

  _MealData? _currentData;

  void triggerAction(String action) {
    final data = _currentData;
    if (data == null) return;
    if (action == 'add-meal') {
      _showAddMeal(data);
    } else if (action == 'add-bazaar') {
      _showAddBazaar(data);
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

  void _refresh() => setState(() => _future = _load());

  String _formatMonth(String monthKey) {
    try {
      final parts = monthKey.split('-');
      if (parts.length < 2) return monthKey;
      final year = parts[0];
      final monthInt = int.tryParse(parts[1]) ?? 1;
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
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
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      if (monthInt < 1 || monthInt > 12) return dateStr;
      return '$day ${months[monthInt - 1]}, $year';
    } catch (_) {
      return dateStr;
    }
  }

  // --- Meal Add/Edit Modals ---

  void _showAddMeal(_MealData data) {
    final now = DateTime.now();
    String selectedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final surface = context.surface;

    // Map of memberId -> controllers
    final lunchControllers = <String, TextEditingController>{};
    final dinnerControllers = <String, TextEditingController>{};

    for (final member in data.members) {
      lunchControllers[member.id] = TextEditingController(text: '0');
      dinnerControllers[member.id] = TextEditingController(text: '0');
    }

    String formatDateForField(String dateStr) {
      try {
        final parts = dateStr.split('-');
        if (parts.length < 3) return dateStr;
        return '${parts[1]}/${parts[2]}/${parts[0]}';
      } catch (_) {
        return dateStr;
      }
    }

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => CottageSheetContent(
          title: '', // Empty to use custom title row with close button
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '+ Add Meal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: surface.foreground,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final currentParsed = DateTime.tryParse(selectedDate) ?? now;
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: currentParsed,
                  firstDate: DateTime(now.year, now.month, 1),
                  lastDate: now,
                );
                if (picked != null) {
                  setSheetState(() {
                    selectedDate =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: surface.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CottageColors.primary, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatDateForField(selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: surface.foreground,
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 20, color: CottageColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header Row: Member, Lunch, Dinner, Total
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Member',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: surface.mutedForeground,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Lunch',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: surface.mutedForeground,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Dinner',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: surface.mutedForeground,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Total',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: surface.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: surface.border, thickness: 0.8),
            const SizedBox(height: 8),
            // List of member rows
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: data.members.length,
                itemBuilder: (ctx, index) {
                  final member = data.members[index];
                  final lunch = double.tryParse(lunchControllers[member.id]!.text) ?? 0.0;
                  final dinner = double.tryParse(dinnerControllers[member.id]!.text) ?? 0.0;
                  final total = lunch + dinner;

                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: surface.border, width: 0.8),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            member.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: surface.foreground,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Container(
                              width: 70,
                              height: 38,
                              decoration: BoxDecoration(
                                color: surface.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: surface.border, width: 0.8),
                              ),
                              child: TextField(
                                controller: lunchControllers[member.id],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: surface.foreground,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  fillColor: Colors.transparent,
                                  filled: false,
                                ),
                                onChanged: (_) => setSheetState(() {}),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Container(
                              width: 70,
                              height: 38,
                              decoration: BoxDecoration(
                                color: surface.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: surface.border, width: 0.8),
                              ),
                              child: TextField(
                                controller: dinnerControllers[member.id],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: surface.foreground,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  fillColor: Colors.transparent,
                                  filled: false,
                                ),
                                onChanged: (_) => setSheetState(() {}),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            total.toStringAsFixed(total % 1 == 0 ? 0 : 1),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: surface.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                for (final member in data.members) {
                  final lunch = double.tryParse(lunchControllers[member.id]!.text) ?? 0.0;
                  final dinner = double.tryParse(dinnerControllers[member.id]!.text) ?? 0.0;
                  final count = lunch + dinner;

                  await _mealService.upsertMeal(
                    userId: member.id,
                    monthKey: data.monthKey,
                    date: selectedDate,
                    count: count,
                    cottageId: data.profile.cottageId,
                  );
                }
                _refresh();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CottageColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Save meal counts'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMealForDate(String date, List<DailyMeal> mealsForDate, List<Profile> members, String cottageId, String monthKey) {
    final controllers = <String, TextEditingController>{};
    for (final member in members) {
      final meal = mealsForDate.firstWhere(
        (m) => m.userId == member.id,
        orElse: () => DailyMeal(userId: member.id, monthKey: monthKey, date: date, count: 0),
      );
      controllers[member.id] = TextEditingController(
        text: meal.count > 0 ? meal.count.toStringAsFixed(meal.count % 1 == 0 ? 0 : 1) : '0',
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
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: controllers[member.id],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                final count = double.tryParse(controllers[member.id]?.text ?? '0') ?? 0;
                // If count is changed (or is non-zero), upsert it
                await _mealService.upsertMeal(
                  userId: member.id,
                  monthKey: monthKey,
                  date: date,
                  count: count,
                  cottageId: cottageId,
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
    String? selectedUserId = data.profile.id;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final now = DateTime.now();
    String selectedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    bool creditDeposit = false;

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => CottageSheetContent(
          title: 'Add Bazaar Entry',
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedUserId,
              decoration: const InputDecoration(labelText: 'Shopper'),
              items: data.members
                  .map((m) => DropdownMenuItem(value: m.id, child: Text(m.displayName)))
                  .toList(),
              onChanged: (v) => setSheetState(() => selectedUserId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount (tk)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Items (Description)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: now,
                  firstDate: DateTime(now.year, now.month, 1),
                  lastDate: now,
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
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Cost deposit to this member', style: TextStyle(fontSize: 14)),
              value: creditDeposit,
              onChanged: (v) => setSheetState(() => creditDeposit = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: CottageColors.primary,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (selectedUserId == null || amount <= 0) return;
                Navigator.pop(context);
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
              child: const Text('Add Entry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBazaar(BazaarEntry entry) {
    final amountCtrl = TextEditingController(text: entry.amount.toStringAsFixed(0));
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Items (Description)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final currentParsed = DateTime.tryParse(selectedDate) ?? DateTime.now();
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: currentParsed,
                  firstDate: DateTime(currentParsed.year, currentParsed.month, 1),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
            title: const Text('Shopper', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            subtitle: Text(entry.memberName ?? 'Member', style: const TextStyle(fontSize: 15)),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            subtitle: Text('${entry.amount.toStringAsFixed(2)} tk', style: const TextStyle(fontSize: 15)),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            subtitle: Text(_formatDate(entry.date), style: const TextStyle(fontSize: 15)),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text('Items/Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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
    String? selectedUserId = data.profile.id;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final now = DateTime.now();
    String selectedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => CottageSheetContent(
          title: 'Add Meal Deposit',
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedUserId,
              decoration: const InputDecoration(labelText: 'Member'),
              items: data.members
                  .map((m) => DropdownMenuItem(value: m.id, child: Text(m.displayName)))
                  .toList(),
              onChanged: (v) => setSheetState(() => selectedUserId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount (tk)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: now,
                  firstDate: DateTime(now.year, now.month, 1),
                  lastDate: now,
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (selectedUserId == null || amount <= 0) return;
                Navigator.pop(context);
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
              child: const Text('Add Deposit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDeposit(MealDeposit entry) {
    final amountCtrl = TextEditingController(text: entry.amount.toStringAsFixed(0));
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                final currentParsed = DateTime.tryParse(selectedDate) ?? DateTime.now();
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: currentParsed,
                  firstDate: DateTime(currentParsed.year, currentParsed.month, 1),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
          Expanded(child: _buildTabItem(0, 'Meal Details', Icons.restaurant_menu_rounded, surface)),
          const SizedBox(width: 3.2),
          Expanded(child: _buildTabItem(1, 'Bazar', Icons.shopping_basket_outlined, surface)),
          const SizedBox(width: 3.2),
          Expanded(child: _buildTabItem(2, 'Deposit', Icons.account_balance_wallet_outlined, surface)),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon, CottageSurface surface) {
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : surface.foreground,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13, // Slightly smaller to fit with icon
                color: active ? Colors.white : surface.foreground,
              ),
            ),
          ],
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
                    const Icon(Icons.error_outline, size: 40, color: CottageColors.destructive),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load meal data.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: surface.foreground),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
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
                    onDownload: () {
                      showToast(context, 'Summary report downloaded successfully');
                    },
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
                    ),
                  ),
                  _BazaarTab(
                    data: data,
                    onRefresh: _refresh,
                    onEditBazaar: _showEditBazaar,
                    onShowInfo: _showBazaarInfo,
                  ),
                  _DepositTab(
                    data: data,
                    onRefresh: _refresh,
                    onEditDeposit: _showEditDeposit,
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

  const _DailyMealsTab({
    required this.data,
    required this.onRefresh,
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
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
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
        padding: EdgeInsets.symmetric(horizontal: context.responsivePadding, vertical: 8),
        itemCount: dates.length + 1,
        itemBuilder: (context, index) {
          if (index == dates.length) return const SizedBox(height: 80);
          final date = dates[index];
          final entries = grouped[date]!;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16), // Gap between cards
            padding: const EdgeInsets.all(4), // Figma has 4px padding for the card wrapper
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: surface.border, width: 0.8),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatDate(date),
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
                      onPressed: () => onEditMeal(date, entries),
                      icon: const Icon(Icons.edit_outlined, color: CottageColors.primary, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: surface.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: surface.border, width: 0.8),
                        ),
                        fixedSize: const Size(38, 38),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4), // 4px gap in Figma
                // Card Grid of Members & Meal Counts
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 109 / 63, // Exact width/height from Figma
                  ),
                  itemBuilder: (context, idx) {
                    final entry = entries[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: surface.background,
                        border: Border.all(color: surface.border, width: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                          const SizedBox(height: 4),
                          Divider(height: 1, color: surface.border, thickness: 0.8),
                          const SizedBox(height: 4),
                          Text(
                            entry.count.toStringAsFixed(entry.count % 1 == 0 ? 0 : 1),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600, // Matched font weight
                              color: surface.foreground,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              ],
            ),
          );
        },
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

  const _BazaarTab({
    required this.data,
    required this.onRefresh,
    required this.onEditBazaar,
    required this.onShowInfo,
  });

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return dateStr;
      final year = parts[0];
      final monthInt = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
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
        icon: Icons.shopping_basket_rounded,
        title: 'No bazaar entries',
        subtitle: 'Record grocery purchases for this month.',
      );
    }

    final surface = context.surface;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: context.responsivePadding, vertical: 8),
        itemCount: data.bazaar.length + 1,
        itemBuilder: (context, index) {
          if (index == data.bazaar.length) return const SizedBox(height: 80);
          final entry = data.bazaar[index];
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16), // Same gap as Meal Detail
            padding: const EdgeInsets.all(4), // 4px padding for outer card
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(8),
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
                          icon: Icon(Icons.visibility_outlined, color: surface.foreground, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: surface.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: surface.border, width: 0.8),
                            ),
                            fixedSize: const Size(38, 38),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => onEditBazaar(entry),
                          icon: const Icon(Icons.edit_outlined, color: CottageColors.primary, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: surface.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: surface.border, width: 0.8),
                            ),
                            fixedSize: const Size(38, 38),
                          ),
                        ),
                      ],
                    )
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 17.5, // 35px diameter
                            backgroundColor: CottageColors.primary.withValues(alpha: 0.1),
                            backgroundImage: entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                                ? NetworkImage(entry.avatarUrl!)
                                : null,
                            child: entry.avatarUrl == null || entry.avatarUrl!.isEmpty
                                ? const Icon(Icons.person, color: CottageColors.primary, size: 20)
                                : null,
                          ),
                          const SizedBox(height: 8),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDEFEC), // Soft peach tint
                                  border: Border.all(color: surface.border, width: 0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  (entry.description != null && entry.description!.isNotEmpty)
                                      ? entry.description!
                                      : 'No items detailed',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF404040),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: surface.background,
                                border: Border.all(color: surface.border, width: 0.8),
                                borderRadius: BorderRadius.circular(8),
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
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      height: 21,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(color: surface.border, width: 1.2),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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

  const _DepositTab({
    required this.data,
    required this.onRefresh,
    required this.onEditDeposit,
  });

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length < 3) return dateStr;
      final year = parts[0];
      final monthInt = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
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
        padding: EdgeInsets.symmetric(horizontal: context.responsivePadding, vertical: 8),
        itemCount: data.deposits.length + 1,
        itemBuilder: (context, index) {
          if (index == data.deposits.length) return const SizedBox(height: 80);
          final entry = data.deposits[index];
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16), // Gap between cards
            padding: const EdgeInsets.all(4), // 4px padding for outer card
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.circular(12),
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
                          borderRadius: BorderRadius.circular(8),
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
                      icon: const Icon(Icons.edit_outlined, color: CottageColors.primary, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: surface.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: surface.border, width: 0.8),
                        ),
                        fixedSize: const Size(38, 38),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 17.5, // 35px diameter
                            backgroundColor: CottageColors.primary.withValues(alpha: 0.1),
                            backgroundImage: entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                                ? NetworkImage(entry.avatarUrl!)
                                : null,
                            child: entry.avatarUrl == null || entry.avatarUrl!.isEmpty
                                ? const Icon(Icons.person, color: CottageColors.primary, size: 20)
                                : null,
                          ),
                          const SizedBox(height: 8),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: surface.background,
                                  border: Border.all(color: surface.border, width: 0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  (entry.note != null && entry.note!.isNotEmpty)
                                      ? entry.note!
                                      : 'Manual deposit',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF888888), // Muted grey
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
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: surface.background,
                                border: Border.all(color: surface.border, width: 0.8),
                                borderRadius: BorderRadius.circular(8),
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
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      height: 21,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(color: surface.border, width: 1.2),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: Orange top, White bottom
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: safeAreaTop + 56 - (shrinkOffset * 1.5).clamp(0, safeAreaTop + 56), 
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
                      padding: EdgeInsets.only(top: safeAreaTop, left: context.responsivePadding, right: context.responsivePadding),
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
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      padding: EdgeInsets.only(left: context.responsivePadding, right: context.responsivePadding, top: 16),
                      child: Text(
                        "Full meal, deposit and cost records for every member in the active month.",
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: surface.foreground.withValues(alpha: 0.8),
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
                  padding: EdgeInsets.only(top: safeAreaTop + 8, left: context.responsivePadding, right: context.responsivePadding),
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
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    icon: Icon(Icons.download_rounded, color: surface.foreground, size: 18),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1000)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
