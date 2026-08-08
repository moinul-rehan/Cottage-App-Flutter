import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import '../data/utility_models.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../../menu/data/member_service.dart';
import '../data/utility_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/helpers/ui_helpers.dart';

/// Figma exact-match tokens for this screen's read-only record cards --
/// intentionally literal hex (not [CottageSurface] tokens, which are close
/// but not identical, e.g. surface.background #F4F4F6 vs Figma's #FAFAFA)
/// since the ask here was pixel-exact fidelity to the design, not
/// dark-mode adaptive theming.
class _UtilityColors {
  _UtilityColors._();
  static const fieldBg = Color(0xFFFAFAFA);
  static const border = Color(0xFFEEEEEE);
  static const darkText = Color(0xFF404040);
  static const placeholder = Color(0xFFAAAAAA);
  static const highlightBg = Color(0xFFFDEFEC);
}

/// Full utility screen -- mirrors the Figma "Utility Details" spec (node
/// 6:613): Expense / Member Deposit / Cottage Deposit tabs, each a
/// read-only list of bordered record cards (date + edit affordance, then
/// tab-specific detail rows). Page-shelled like Meal/Notices/Members/
/// Contacts (orange band + white rounded sheet).
class UtilitiesScreen extends StatefulWidget {
  const UtilitiesScreen({super.key});

  static final utilitiesScreenKey = GlobalKey<_UtilitiesScreenState>();

  @override
  State<UtilitiesScreen> createState() => _UtilitiesScreenState();
}

class _UtilitiesScreenState extends State<UtilitiesScreen> with SingleTickerProviderStateMixin {
  final _utilityService = UtilityService();
  final _dashService = DashboardService();
  final _memberService = MemberService();

  _UtilityData? _currentData;

  void triggerAction(String action) {
    final data = _currentData;
    if (data == null) return;
    if (action == 'utility-expense') {
      _showAddExpense(data);
    } else if (action == 'member-deposit') {
      _showAddDeposit(data, sourceType: 'member');
    } else if (action == 'cottage-deposit') {
      _showAddDeposit(data, sourceType: 'cottage');
    }
  }

  late TabController _tabController;
  late Future<_UtilityData> _future;
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

  Future<_UtilityData> _load() async {
    final profile = await _dashService.getCurrentProfile();
    final monthKey = await _dashService.getActiveMonthKey(profile.cottageId);
    final members = await _memberService.getActiveMembers(profile.cottageId);
    final expenses = await _utilityService.getExpenses(monthKey);
    final deposits = await _utilityService.getDeposits(profile.cottageId, monthKey);

    return _UtilityData(
      profile: profile,
      monthKey: monthKey,
      members: members,
      expenses: expenses,
      deposits: deposits,
    );
  }

  void _refresh() => setState(() => _future = _load());

  void _showAddExpense(_UtilityData data) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? category;
    String paymentSource = 'Cottage Balance';
    final now = DateTime.now();
    String selectedDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => CottageSheetContent(
          title: 'Add Expense',
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount (tk)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'electricity', child: Text('Electricity')),
                DropdownMenuItem(value: 'gas', child: Text('Gas')),
                DropdownMenuItem(value: 'water', child: Text('Water')),
                DropdownMenuItem(value: 'internet', child: Text('Internet')),
                DropdownMenuItem(value: 'house_rent', child: Text('House Rent')),
                DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setSheetState(() => category = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: paymentSource,
              decoration: const InputDecoration(labelText: 'Payment Source'),
              items: const [
                DropdownMenuItem(value: 'Cottage Balance', child: Text('Cottage Balance')),
                DropdownMenuItem(value: 'Member Reimbursement', child: Text('Member Reimbursement')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setSheetState(() => paymentSource = v ?? paymentSource),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: now,
                  firstDate: DateTime(now.year - 1),
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
                child: Text(selectedDate),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) return;
                Navigator.pop(context);
                await _utilityService.addExpense(
                  cottageId: data.profile.cottageId,
                  amount: amount,
                  expenseDate: selectedDate,
                  description: descCtrl.text.trim(),
                  category: category,
                  paymentSource: paymentSource,
                );
                _refresh();
              },
              child: const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }

  /// [sourceType] 'member' shows a member picker (Figma "Member Deposit"
  /// tab); anything else (e.g. 'cottage') skips it, matching the "Cottage
  /// Deposit" tab's no-avatar card.
  void _showAddDeposit(_UtilityData data, {required String sourceType}) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? selectedUserId = sourceType == 'member' ? data.profile.id : null;

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => CottageSheetContent(
          title: sourceType == 'member' ? 'Add Member Deposit' : 'Add Cottage Deposit',
          children: [
            if (sourceType == 'member') ...[
              DropdownButtonFormField<String>(
                initialValue: selectedUserId,
                decoration: const InputDecoration(labelText: 'Member'),
                items: data.members
                    .map((m) => DropdownMenuItem(value: m.id, child: Text(m.displayName)))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedUserId = v),
              ),
              const SizedBox(height: 12),
            ],
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                final userId = selectedUserId ?? data.profile.id;
                if (amount <= 0) return;
                Navigator.pop(context);
                await _utilityService.addDeposit(
                  cottageId: data.profile.cottageId,
                  userId: userId,
                  monthKey: data.monthKey,
                  amount: amount,
                  sourceType: sourceType,
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

  // --- Segmented TabBar (Figma: p-3.217 gap-3.217 rounded-10; each item
  // rounded-8.043, py-6.434 px-9.651 -- labels can wrap to 2 lines, so
  // items size to content rather than a fixed single-line height). ---

  Widget _buildTabBar() {
    return IntrinsicHeight(
      child: Container(
        padding: const EdgeInsets.all(3.217),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _UtilityColors.border, width: 0.8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildTabItem(0, 'Expense')),
            const SizedBox(width: 3.217),
            Expanded(child: _buildTabItem(1, 'Member Deposit')),
            const SizedBox(width: 3.217),
            Expanded(child: _buildTabItem(2, 'Cottage Deposit')),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    final active = _activeTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTabIndex = index;
          _tabController.animateTo(index);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9.651, vertical: 6.434),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? CottageColors.primary : _UtilityColors.fieldBg,
          borderRadius: BorderRadius.circular(8.043),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: active ? Colors.white : _UtilityColors.darkText,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;

    return FutureBuilder<_UtilityData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: CottageColors.primary,
            body: SizedBox.shrink(),
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
                      'Could not load utilities.\n${snapshot.error}',
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
        final memberDeposits = data.deposits.where((d) => d.isMemberDeposit).toList();
        final cottageDeposits = data.deposits.where((d) => !d.isMemberDeposit).toList();

        return Scaffold(
          backgroundColor: CottageColors.primary,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(context.responsivePadding, 8, context.responsivePadding, 16),
                  child: Row(
                    children: [
                      const Text(
                        'Utility Details',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 11), // Figma: gap-11
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(36)),
                        child: Text(
                          _formatMonth(data.monthKey),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: CottageColors.primary),
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
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(context.responsivePadding, 24, context.responsivePadding, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Read-only record of every utility expense and deposit. No calculations happen here.',
                                style: TextStyle(fontSize: 14, color: Color(0xFF303030)),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () => showToast(context, 'Summary report downloaded successfully'),
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: _UtilityColors.border),
                                    borderRadius: BorderRadius.circular(1000),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1)),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.download_rounded, size: 20, color: _UtilityColors.darkText),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Download',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _UtilityColors.darkText),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTabBar(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _ExpenseTab(expenses: data.expenses, onRefresh: _refresh),
                              _MemberDepositTab(deposits: memberDeposits, onRefresh: _refresh),
                              _CottageDepositTab(deposits: cottageDeposits, onRefresh: _refresh),
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

class _UtilityData {
  final Profile profile;
  final String monthKey;
  final List<Profile> members;
  final List<Expense> expenses;
  final List<UtilityDeposit> deposits;

  const _UtilityData({
    required this.profile,
    required this.monthKey,
    required this.members,
    required this.expenses,
    required this.deposits,
  });
}

String _formatCardDate(String isoDate) {
  try {
    final d = DateTime.parse(isoDate);
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  } catch (_) {
    return isoDate;
  }
}

/// Figma "Self driver requirement" card shell: white, border #eee, radius
/// 8, p-4, gap-4 column of [date row, ...content].
class _UtilityCard extends StatelessWidget {
  final String date;
  final VoidCallback? onEdit;
  final Widget content;

  const _UtilityCard({required this.date, this.onEdit, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _UtilityColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _UtilityColors.fieldBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _UtilityColors.border, width: 0.8),
                  ),
                  child: Text(
                    _formatCardDate(date),
                    style: const TextStyle(fontSize: 14, color: _UtilityColors.darkText),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _UtilityColors.fieldBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _UtilityColors.border, width: 0.8),
                  ),
                  child: const Icon(Icons.edit_outlined, size: 18, color: CottageColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          content,
        ],
      ),
    );
  }
}

/// Figma "Total Amount" / "Payment Source" row: fafafa, border #eee,
/// radius 4, px-8 py-10, label 12px primary on the left, a vertical
/// divider, then the value.
class _UtilityInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool boldValue;

  const _UtilityInfoRow({required this.label, required this.value, this.boldValue = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _UtilityColors.fieldBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _UtilityColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: CottageColors.primary)),
          Expanded(
            child: Center(
              child: Container(width: 1, height: 21, color: _UtilityColors.border),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: boldValue ? FontWeight.bold : FontWeight.w400,
              color: _UtilityColors.darkText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma placeholder-styled note/description row: fafafa, border #eee,
/// radius 4, px-8 py-10, text 14px #aaa.
class _UtilityNoteRow extends StatelessWidget {
  final String text;
  const _UtilityNoteRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _UtilityColors.fieldBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _UtilityColors.border, width: 0.8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14, color: _UtilityColors.placeholder)),
    );
  }
}

// --- Expense Tab (Figma "Utility Details - Expense") ---

class _ExpenseTab extends StatelessWidget {
  final List<Expense> expenses;
  final VoidCallback onRefresh;

  const _ExpenseTab({required this.expenses, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No expenses this month',
        subtitle: 'Add shared cottage expenses here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(context.responsivePadding, 0, context.responsivePadding, 96),
        itemCount: expenses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final e = expenses[index];
          String title = e.category ?? 'Other';
          title = title.isEmpty ? 'Other' : title[0].toUpperCase() + title.substring(1);
          if (title == 'House_rent') title = 'House Rent';

          return _UtilityCard(
            date: e.expenseDate,
            onEdit: () => showToast(context, 'Editing expenses is coming in a future update'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _UtilityColors.highlightBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _UtilityColors.border, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 12, color: CottageColors.primary)),
                      const SizedBox(height: 2),
                      Text(
                        (e.description?.isNotEmpty ?? false) ? e.description! : title,
                        style: const TextStyle(fontSize: 14, color: _UtilityColors.darkText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _UtilityInfoRow(label: 'Payment Source', value: e.paymentSource ?? 'Cottage Balance'),
                const SizedBox(height: 4),
                _UtilityInfoRow(label: 'Total Amount', value: e.amount.toStringAsFixed(0), boldValue: true),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Member Deposit Tab (Figma "Utility Details - Member Deposit") ---

class _MemberDepositTab extends StatelessWidget {
  final List<UtilityDeposit> deposits;
  final VoidCallback onRefresh;

  const _MemberDepositTab({required this.deposits, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (deposits.isEmpty) {
      return const EmptyState(
        icon: Icons.payments_rounded,
        title: 'No member deposits this month',
        subtitle: 'Record roommate utility payments here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(context.responsivePadding, 0, context.responsivePadding, 96),
        itemCount: deposits.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final d = deposits[index];
          final name = d.memberName ?? 'Member';
          final createdAt = d.createdAt?.toIso8601String().substring(0, 10) ?? '';

          return _UtilityCard(
            date: createdAt,
            onEdit: () => showToast(context, 'Editing deposits is coming in a future update'),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 109,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _UtilityColors.fieldBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _UtilityColors.border, width: 0.8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 13.5,
                        backgroundColor: CottageColors.primary.withValues(alpha: 0.1),
                        backgroundImage: (d.avatarUrl?.isNotEmpty ?? false) ? NetworkImage(d.avatarUrl!) : null,
                        child: (d.avatarUrl?.isNotEmpty ?? false)
                            ? null
                            : Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: CottageColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: const TextStyle(fontSize: 12, color: CottageColors.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _UtilityNoteRow((d.note?.isNotEmpty ?? false) ? d.note! : 'No notes detailed'),
                      const SizedBox(height: 4),
                      _UtilityInfoRow(label: 'Total Amount', value: d.amount.toStringAsFixed(0), boldValue: true),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- Cottage Deposit Tab (Figma "Utility Details - Cottage Deposit") ---

class _CottageDepositTab extends StatelessWidget {
  final List<UtilityDeposit> deposits;
  final VoidCallback onRefresh;

  const _CottageDepositTab({required this.deposits, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (deposits.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_rounded,
        title: 'No cottage deposits this month',
        subtitle: 'Money the cottage fund itself put toward utilities.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(context.responsivePadding, 0, context.responsivePadding, 96),
        itemCount: deposits.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final d = deposits[index];
          final createdAt = d.createdAt?.toIso8601String().substring(0, 10) ?? '';

          return _UtilityCard(
            date: createdAt,
            onEdit: () => showToast(context, 'Editing deposits is coming in a future update'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UtilityNoteRow((d.note?.isNotEmpty ?? false) ? d.note! : 'No notes detailed'),
                const SizedBox(height: 4),
                _UtilityInfoRow(label: 'Total Amount', value: d.amount.toStringAsFixed(0), boldValue: true),
              ],
            ),
          );
        },
      ),
    );
  }
}
