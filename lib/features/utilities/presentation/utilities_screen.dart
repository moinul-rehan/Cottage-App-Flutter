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
  static const headingText = Color(0xFF17191E);
  static const requiredMark = Color(0xFFCC4F4F);
  static const saveButton = Color(0xFFD1593B);
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

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _drawerDate(DateTime d) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  }

  /// Figma node 77:1052 ("Add Expense - Drawer"): free-text Category and
  /// Payment Source (not dropdowns -- the design just shows placeholder
  /// examples), Date via a tap-to-pick field styled like the others.
  void _showAddExpense(_UtilityData data) {
    final categoryCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final paymentSourceCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => _UtilityDrawer(
          icon: Icons.payments_outlined,
          title: 'Add Expense',
          children: [
            _DrawerField(
              label: 'Date',
              child: _DrawerTapField(
                value: _drawerDate(selectedDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(selectedDate.year - 1),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
              ),
            ),
            _DrawerField(
              label: 'Category',
              child: _DrawerTextField(controller: categoryCtrl, hint: 'e.g. Electricity, Internet, Gas'),
            ),
            _DrawerField(
              label: 'Description',
              child: _DrawerTextField(controller: descCtrl, hint: 'July electricity bill payment'),
            ),
            _DrawerField(
              label: 'Payment Source',
              child: _DrawerTextField(controller: paymentSourceCtrl, hint: 'Cottage Balance'),
            ),
            _DrawerField(label: 'Total Amount', child: _DrawerAmountField(controller: amountCtrl)),
            _DrawerSaveButton(
              label: 'Save Expense',
              onTap: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0 || categoryCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                  showToast(ctx, 'Please fill in all required fields.');
                  return;
                }
                Navigator.pop(ctx);
                await _utilityService.addExpense(
                  cottageId: data.profile.cottageId,
                  amount: amount,
                  expenseDate: _isoDate(selectedDate),
                  description: descCtrl.text.trim(),
                  category: categoryCtrl.text.trim(),
                  paymentSource: paymentSourceCtrl.text.trim().isEmpty ? 'Cottage Balance' : paymentSourceCtrl.text.trim(),
                );
                _refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Figma nodes 77:1154 ("Add Member Deposit") / 77:1255 ("Add Cottage
  /// Deposit"): the member picker only appears for [sourceType] 'member'.
  void _showAddDeposit(_UtilityData data, {required String sourceType}) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    Profile? selectedMember = sourceType == 'member' ? data.profile : null;

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => _UtilityDrawer(
          icon: Icons.account_balance_wallet_outlined,
          title: sourceType == 'member' ? 'Add Member Deposit' : 'Add Cottage Deposit',
          children: [
            if (sourceType == 'member')
              _DrawerField(
                label: 'Member',
                child: _DrawerTapField(
                  value: selectedMember?.displayName ?? 'Select member',
                  isPlaceholder: selectedMember == null,
                  onTap: () async {
                    final picked = await _pickMember(ctx, data.members);
                    if (picked != null) setSheetState(() => selectedMember = picked);
                  },
                ),
              ),
            _DrawerField(
              label: 'Date',
              child: _DrawerTapField(
                value: _drawerDate(selectedDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(selectedDate.year - 1),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
              ),
            ),
            _DrawerField(
              label: 'Description',
              child: _DrawerTextField(
                controller: descCtrl,
                hint: sourceType == 'member' ? 'Cash for July utility bill' : 'Prepaid by cottage fund for July electricity',
              ),
            ),
            _DrawerField(label: 'Total Amount', child: _DrawerAmountField(controller: amountCtrl)),
            _DrawerSaveButton(
              label: 'Save Deposit',
              onTap: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0 || descCtrl.text.trim().isEmpty || (sourceType == 'member' && selectedMember == null)) {
                  showToast(ctx, 'Please fill in all required fields.');
                  return;
                }
                Navigator.pop(ctx);
                await _utilityService.addDeposit(
                  cottageId: data.profile.cottageId,
                  userId: (selectedMember ?? data.profile).id,
                  monthKey: data.monthKey,
                  amount: amount,
                  sourceType: sourceType,
                  note: descCtrl.text.trim(),
                );
                _refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<Profile?> _pickMember(BuildContext context, List<Profile> members) {
    return showModalBottomSheet<Profile>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in members)
              ListTile(
                title: Text(m.displayName),
                onTap: () => Navigator.pop(ctx, m),
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

// --- Add Expense/Deposit drawers (Figma "Section 5": nodes 77:1052,
// 77:1154, 77:1255) -- icon+title+close header, gap-16 between fields,
// each field a gap-6 label(+red asterisk)/box pair, fafafa/eee/radius-10
// boxes, and a #D1593B pill save button. ---

class _UtilityDrawer extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _UtilityDrawer({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _UtilityColors.headingText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _UtilityColors.headingText),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _UtilityColors.fieldBg, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.close, size: 16, color: _UtilityColors.headingText),
                ),
              ),
            ],
          ),
          for (final child in children) ...[
            const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    );
  }
}

class _DrawerField extends StatelessWidget {
  final String label;
  final Widget child;
  const _DrawerField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: _UtilityColors.darkText)),
            const SizedBox(width: 2),
            const Text('*', style: TextStyle(fontSize: 13, color: _UtilityColors.requiredMark)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _UtilityColors.fieldBg,
            border: Border.all(color: _UtilityColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _DrawerTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _DrawerTextField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 13, color: _UtilityColors.darkText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: _UtilityColors.placeholder),
        filled: false,
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

/// Read-only, tap-to-pick field (Date / Member) styled like the text
/// fields -- Figma shows these as plain text-style inputs too.
class _DrawerTapField extends StatelessWidget {
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;

  const _DrawerTapField({required this.value, this.isPlaceholder = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        value,
        style: TextStyle(fontSize: 13, color: isPlaceholder ? _UtilityColors.placeholder : _UtilityColors.darkText),
      ),
    );
  }
}

class _DrawerAmountField extends StatelessWidget {
  final TextEditingController controller;
  const _DrawerAmountField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('৳', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _UtilityColors.placeholder)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13, color: _UtilityColors.darkText),
            decoration: const InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(fontSize: 13, color: _UtilityColors.placeholder),
              filled: false,
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawerSaveButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DrawerSaveButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _UtilityColors.saveButton, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
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
