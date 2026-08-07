import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Full utility-expenses screen with tabs for Expenses, Deposits, and Member Dues.
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
    } else if (action == 'member-deposit' || action == 'cottage-deposit') {
      _showAddDeposit(data);
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
    final dues = await _utilityService.getMemberDues(profile.cottageId, monthKey, members);

    return _UtilityData(
      profile: profile,
      monthKey: monthKey,
      members: members,
      expenses: expenses,
      deposits: deposits,
      dues: dues,
    );
  }

  void _refresh() => setState(() => _future = _load());

  void _showAddExpense(_UtilityData data) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? category;
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

  void _showAddDeposit(_UtilityData data) {
    final amountCtrl = TextEditingController();
    String? selectedUserId = data.profile.id;

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => CottageSheetContent(
          title: 'Add Deposit',
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (selectedUserId == null || amount <= 0) return;
                Navigator.pop(context);
                await _utilityService.addDeposit(
                  cottageId: data.profile.cottageId,
                  userId: selectedUserId!,
                  monthKey: data.monthKey,
                  amount: amount,
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
          Expanded(child: _buildTabItem(0, 'Expenses', Icons.receipt_long_outlined, surface)),
          const SizedBox(width: 3.2),
          Expanded(child: _buildTabItem(1, 'Deposits', Icons.account_balance_wallet_outlined, surface)),
          const SizedBox(width: 3.2),
          Expanded(child: _buildTabItem(2, 'Dues', Icons.groups_outlined, surface)),
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
                fontFamily: 'Poppins',
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
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

    return FutureBuilder<_UtilityData>(
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

        return Scaffold(
          backgroundColor: CottageColors.primary,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                const Text(
                  'Utility Overview',
                  style: TextStyle(
                    fontFamily: 'Poppins',
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
                    _formatMonth(data.monthKey),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: CottageColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          body: Column(
            children: [
              // Extra space for peach header branding
              const SizedBox(height: 12),
              // Main white card body
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // White Card Header Section
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.responsivePadding,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Full utility, deposit and dues records for every member in the active month.",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color: surface.foreground.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Download button row
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    showToast(context, 'Summary report downloaded successfully');
                                  },
                                  icon: Icon(Icons.download_rounded, color: surface.foreground, size: 18),
                                  label: Text(
                                    'Download',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
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
                            // Segmented TabBar
                            _buildTabBar(surface),
                          ],
                        ),
                      ),
                      // Scrollable content area
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _ExpensesTab(data: data, onRefresh: _refresh, onAdd: () => _showAddExpense(data)),
                            _DepositsTab(data: data, onRefresh: _refresh, onAdd: () => _showAddDeposit(data)),
                            _DuesTab(data: data, onRefresh: _refresh),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
  final List<MemberUtilityDue> dues;

  const _UtilityData({
    required this.profile,
    required this.monthKey,
    required this.members,
    required this.expenses,
    required this.deposits,
    required this.dues,
  });
}

class _ExpensesTab extends StatelessWidget {
  final _UtilityData data;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _ExpensesTab({required this.data, required this.onRefresh, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (data.expenses.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No expenses this month',
        subtitle: 'Add shared cottage expenses here.',
      );
    }

    final surface = context.surface;
    final total = data.expenses.fold<double>(0, (s, e) => s + e.amount);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: context.responsivePadding, vertical: 8),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: surface.border, width: 0.8),
            ),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: CottageColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: const Text(
                        'Total Expenses',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, color: Colors.white.withValues(alpha: 0.3)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        '${total.toStringAsFixed(2)} tk',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...data.expenses.map((e) {
            String title = e.category ?? 'Other';
            title = title[0].toUpperCase() + title.substring(1);
            if (title == 'House_rent') title = 'House Rent';

            String formattedDate = e.expenseDate;
            try {
              final d = DateTime.parse(e.expenseDate);
              const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
              formattedDate = '${d.day} ${months[d.month - 1]}, ${d.year}';
            } catch (_) {}

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surface.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: surface.border, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Box 1: Date
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: surface.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: surface.border, width: 0.8),
                    ),
                    child: Text(
                      formattedDate,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: surface.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Box 2: Category & Member
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: surface.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: surface.border, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: CottageColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.payerName ?? 'Member',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: surface.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Box 3: Payment Source
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: surface.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: surface.border, width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payment Source',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: surface.mutedForeground,
                          ),
                        ),
                        Text(
                          'Cottage Balance',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: surface.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Box 4: Total Amount
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: surface.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: surface.border, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: CottageColors.primary,
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, color: surface.border),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              '${e.amount.toStringAsFixed(2)} tk',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: surface.foreground,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _DepositsTab extends StatelessWidget {
  final _UtilityData data;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const _DepositsTab({required this.data, required this.onRefresh, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (data.deposits.isEmpty) {
      return const EmptyState(
        icon: Icons.payments_rounded,
        title: 'No deposits this month',
        subtitle: 'Record member utility payments here.',
      );
    }

    final surface = context.surface;
    final total = data.deposits.fold<double>(0, (s, d) => s + d.amount);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: context.responsivePadding, vertical: 8),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: surface.border, width: 0.8),
            ),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: CottageColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'Total Collected',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, color: Colors.white.withValues(alpha: 0.3)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        '${total.toStringAsFixed(2)} tk',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...data.deposits.map((d) {
            String name = d.memberName ?? 'Member';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: surface.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: surface.border, width: 0.8),
              ),
              child: Row(
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
                          radius: 17.5,
                          backgroundColor: CottageColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: CottageColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
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
                  const SizedBox(width: 4),
                  // Right Column: Note bubble & Amount Strip
                  Expanded(
                    child: SizedBox(
                      height: 99,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDEFEC),
                                border: Border.all(color: surface.border, width: 0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerLeft,
                              child: const Text(
                                'No notes detailed',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: Color(0xFF404040),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 29,
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
                                    fontFamily: 'Poppins',
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
                                  '${d.amount.toStringAsFixed(0)} tk',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
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
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _DuesTab extends StatelessWidget {
  final _UtilityData data;
  final VoidCallback onRefresh;

  const _DuesTab({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (data.dues.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_rounded,
        title: 'No due information',
        subtitle: 'Utility adjustments will appear here once configured.',
      );
    }

    final surface = context.surface;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: context.responsivePadding, vertical: 8),
        children: [
          ...data.dues.map((due) {
            final isPaid = due.total > 0 && due.due <= 0;
            final hasDebt = due.due > 0;
            String name = due.memberName.isNotEmpty ? due.memberName : 'Unknown';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: surface.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: surface.border, width: 0.8),
              ),
              child: Column(
                children: [
                  // Header Row: Avatar, Name, Status Badge
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: surface.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: surface.border, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: CottageColors.primary.withValues(alpha: 0.1),
                          backgroundImage: due.avatarUrl != null ? NetworkImage(due.avatarUrl!) : null,
                          child: due.avatarUrl == null
                              ? Text(
                                  name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: CottageColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: surface.foreground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0x1A059669),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Paid',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (hasDebt)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: CottageColors.destructive.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Due',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: CottageColors.destructive,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 2x2 Grid for amounts
                  Row(
                    children: [
                      Expanded(child: _DueField(label: 'Rent', value: '${due.rent.toStringAsFixed(0)} tk', surface: surface)),
                      const SizedBox(width: 4),
                      Expanded(child: _DueField(label: 'Expenses', value: '${due.expenses.toStringAsFixed(0)} tk', surface: surface)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: _DueField(label: 'Paid', value: '${due.paid.toStringAsFixed(0)} tk', surface: surface)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _DueField(
                          label: hasDebt ? 'Remaining' : 'Advance',
                          value: '${due.due.abs().toStringAsFixed(0)} tk',
                          surface: surface,
                          valueColor: hasDebt ? CottageColors.destructive : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _DueField extends StatelessWidget {
  final String label;
  final String value;
  final CottageSurface surface;
  final Color? valueColor;

  const _DueField({
    required this.label,
    required this.value,
    required this.surface,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surface.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: surface.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: surface.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? surface.foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
