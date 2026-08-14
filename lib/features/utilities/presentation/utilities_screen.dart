import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cottage/models/profile.dart';
import '../data/utility_models.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../../menu/data/member_service.dart';
import '../data/utility_service.dart';
import 'utility_statement_screen.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import 'package:cottage/helpers/utility_categories.dart';

/// Was a set of literal Figma-exact hex constants (pixel-perfect in light
/// mode, but the same fixed light colors in dark mode too -- e.g. a
/// near-white #FAFAFA chip background never changed, which is exactly why
/// this whole page still "looked like light mode" after switching to dark).
/// Now each one resolves through [CottageSurface] so it adapts per theme;
/// only [requiredMark]/[saveButton] (brand/semantic accents, not
/// surface-dependent) stay fixed.
class _UtilityColors {
  _UtilityColors._();
  static Color fieldBg(BuildContext context) => context.surface.background;
  static Color border(BuildContext context) => context.surface.border;
  static Color darkText(BuildContext context) => context.surface.foreground;
  static Color placeholder(BuildContext context) =>
      context.surface.mutedForeground;
  static Color highlightBg(BuildContext context) => context.surface.accent;
  static Color headingText(BuildContext context) => context.surface.foreground;
  static const requiredMark = CottageColors.destructive;
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

class _UtilitiesScreenState extends State<UtilitiesScreen>
    with SingleTickerProviderStateMixin {
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
    } else if (action == 'utility-statement') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const UtilityStatementScreen()));
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
    final deposits = await _utilityService.getDeposits(
      profile.cottageId,
      monthKey,
    );

    return _UtilityData(
      profile: profile,
      monthKey: monthKey,
      members: members,
      expenses: expenses,
      deposits: deposits,
    );
  }

  // Block body -- see contacts_screen.dart's _refresh for why the arrow
  // form is a real bug (setState() callback implicitly returning a Future).
  void _refresh() => setState(() {
    _future = _load();
  });

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _drawerDate(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  }

  /// Figma node 77:1052 ("Add Expense - Drawer"): free-text Category, Date
  /// via a tap-to-pick field styled like the others. Payment Source is a
  /// 3-way picker (Member / Cottage Balance / None) matching the web app's
  /// AddExpenseForm radio group exactly -- it's not just a label, each
  /// choice drives a real side effect (see UtilityService.addExpense), so
  /// it can't be free text.
  void _showAddExpense(_UtilityData data) {
    final customCategoryCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String category = 'electricity';
    String paymentSource = 'cottage_balance';
    Profile? paidByMember;

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
                  if (picked != null) {
                    setSheetState(() => selectedDate = picked);
                  }
                },
              ),
            ),
            _DrawerField(
              label: 'Category',
              child: _DrawerTapField(
                value: utilityCategoryLabels[category]!,
                onTap: () async {
                  final picked = await _pickCategory(ctx);
                  if (picked != null) {
                    setSheetState(() => category = picked);
                  }
                },
              ),
            ),
            if (category == 'other')
              _DrawerField(
                label: 'Custom Category Name',
                child: _DrawerTextField(
                  controller: customCategoryCtrl,
                  hint: 'e.g. Gas cylinder',
                ),
              ),
            _DrawerField(
              label: 'Description',
              child: _DrawerTextField(
                controller: descCtrl,
                hint: 'July electricity bill payment',
              ),
            ),
            Text(
              'Payment Source',
              style: TextStyle(fontSize: 13, color: _UtilityColors.darkText(context)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _PaymentSourceOption(
                    label: 'Member',
                    selected: paymentSource == 'member',
                    onTap: () => setSheetState(() => paymentSource = 'member'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PaymentSourceOption(
                    label: 'Cottage Balance',
                    selected: paymentSource == 'cottage_balance',
                    onTap: () =>
                        setSheetState(() => paymentSource = 'cottage_balance'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PaymentSourceOption(
                    label: 'None',
                    selected: paymentSource == 'none',
                    onTap: () => setSheetState(() => paymentSource = 'none'),
                  ),
                ),
              ],
            ),
            Text(
              switch (paymentSource) {
                'member' =>
                  'That member already paid the vendor directly — reduces their Utility Due. Cottage Balance is unaffected.',
                'cottage_balance' =>
                  'Paid from the shared fund — Cottage Balance decreases by this amount.',
                _ => 'Recorded only. No balance or due changes.',
              },
              style: TextStyle(
                fontSize: 11,
                color: _UtilityColors.placeholder(context),
              ),
            ),
            if (paymentSource == 'member')
              _DrawerField(
                label: 'Which Member Paid',
                child: _DrawerTapField(
                  value: paidByMember?.displayName ?? 'Select member',
                  isPlaceholder: paidByMember == null,
                  onTap: () async {
                    final picked = await _pickMember(ctx, data.members);
                    if (picked != null) {
                      setSheetState(() => paidByMember = picked);
                    }
                  },
                ),
              ),
            _DrawerField(
              label: 'Total Amount',
              child: _DrawerAmountField(controller: amountCtrl),
            ),
            _DrawerSaveButton(
              label: 'Save Expense',
              onTap: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                final resolvedCategory = category == 'other'
                    ? customCategoryCtrl.text.trim()
                    : category;
                if (amount <= 0 ||
                    resolvedCategory.isEmpty ||
                    descCtrl.text.trim().isEmpty) {
                  showToast(ctx, 'Please fill in all required fields.');
                  return;
                }
                if (paymentSource == 'member' && paidByMember == null) {
                  showToast(ctx, 'Select which member paid.');
                  return;
                }
                Navigator.pop(ctx);
                await _utilityService.addExpense(
                  cottageId: data.profile.cottageId,
                  createdBy: data.profile.id,
                  monthKey: data.monthKey,
                  amount: amount,
                  expenseDate: _isoDate(selectedDate),
                  description: descCtrl.text.trim(),
                  category: resolvedCategory,
                  paymentSource: paymentSource,
                  paidByMemberId: paymentSource == 'member'
                      ? paidByMember!.id
                      : null,
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
    // 'addition' matches the DB's utility_deposits.source_type check
    // constraint (migration 0016) -- the literal 'cottage' passed in by
    // callers isn't a valid value there.
    final depositSourceType = sourceType == 'member' ? 'member' : 'addition';
    Profile? selectedMember = sourceType == 'member' ? data.profile : null;

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => _UtilityDrawer(
          icon: Icons.account_balance_wallet_outlined,
          title: sourceType == 'member'
              ? 'Add Member Deposit'
              : 'Add Cottage Deposit',
          children: [
            if (sourceType == 'member')
              _DrawerField(
                label: 'Member',
                child: _DrawerTapField(
                  value: selectedMember?.displayName ?? 'Select member',
                  isPlaceholder: selectedMember == null,
                  onTap: () async {
                    final picked = await _pickMember(ctx, data.members);
                    if (picked != null) {
                      setSheetState(() => selectedMember = picked);
                    }
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
                  if (picked != null) {
                    setSheetState(() => selectedDate = picked);
                  }
                },
              ),
            ),
            _DrawerField(
              label: 'Description',
              child: _DrawerTextField(
                controller: descCtrl,
                hint: sourceType == 'member'
                    ? 'Cash for July utility bill'
                    : 'Prepaid by cottage fund for July electricity',
              ),
            ),
            _DrawerField(
              label: 'Total Amount',
              child: _DrawerAmountField(controller: amountCtrl),
            ),
            _DrawerSaveButton(
              label: 'Save Deposit',
              onTap: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0 ||
                    descCtrl.text.trim().isEmpty ||
                    (sourceType == 'member' && selectedMember == null)) {
                  showToast(ctx, 'Please fill in all required fields.');
                  return;
                }
                Navigator.pop(ctx);
                await _utilityService.addDeposit(
                  cottageId: data.profile.cottageId,
                  userId: sourceType == 'member' ? selectedMember!.id : null,
                  monthKey: data.monthKey,
                  amount: amount,
                  sourceType: depositSourceType,
                  note: descCtrl.text.trim(),
                  createdBy: data.profile.id,
                  depositDate: _isoDate(selectedDate),
                );
                _refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Category + description + date + amount -- same fields as
  /// [_showAddExpense] minus Payment Source, which `updateExpense` never
  /// touches (mirrors EditExpenseDialog.tsx exactly).
  void _showEditExpense(Expense expense) {
    final knownCategory =
        expense.category != null &&
        utilityCategoryLabels.containsKey(expense.category) &&
        expense.category != 'other';
    String category = knownCategory ? expense.category! : 'other';
    final customCategoryCtrl = TextEditingController(
      text: knownCategory ? '' : (expense.category ?? ''),
    );
    final descCtrl = TextEditingController(text: expense.description ?? '');
    final amountCtrl = TextEditingController(
      text: expense.amount.toStringAsFixed(2),
    );
    DateTime selectedDate =
        DateTime.tryParse(expense.expenseDate) ?? DateTime.now();

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => _UtilityDrawer(
          icon: Icons.edit_outlined,
          title: 'Edit Expense',
          children: [
            _DrawerField(
              label: 'Category',
              child: _DrawerTapField(
                value: utilityCategoryLabels[category]!,
                onTap: () async {
                  final picked = await _pickCategory(ctx);
                  if (picked != null) {
                    setSheetState(() => category = picked);
                  }
                },
              ),
            ),
            if (category == 'other')
              _DrawerField(
                label: 'Custom Category Name',
                child: _DrawerTextField(
                  controller: customCategoryCtrl,
                  hint: 'e.g. Gas cylinder',
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
                  if (picked != null) {
                    setSheetState(() => selectedDate = picked);
                  }
                },
              ),
            ),
            _DrawerField(
              label: 'Description',
              child: _DrawerTextField(
                controller: descCtrl,
                hint: 'July electricity bill payment',
              ),
            ),
            _DrawerField(
              label: 'Total Amount',
              child: _DrawerAmountField(controller: amountCtrl),
            ),
            _DrawerSaveButton(
              label: 'Save Changes',
              onTap: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                final resolvedCategory = category == 'other'
                    ? customCategoryCtrl.text.trim()
                    : category;
                if (amount <= 0 || resolvedCategory.isEmpty) {
                  showToast(ctx, 'Please fill in all required fields.');
                  return;
                }
                Navigator.pop(ctx);
                await _utilityService.updateExpense(
                  id: expense.id,
                  category: resolvedCategory,
                  amount: amount,
                  description: descCtrl.text.trim(),
                  expenseDate: _isoDate(selectedDate),
                );
                _refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteExpense(Expense expense) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: const Text(
          'This also removes any linked Cottage Balance transaction or member due-credit. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _utilityService.deleteExpense(expense.id);
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

  /// Amount + date + note -- same shape for both the Member and Cottage
  /// Deposit tabs (mirrors EditMemberDepositDialog.tsx /
  /// EditCottageDepositDialog.tsx, which are identical besides their
  /// default reason text).
  void _showEditDeposit(UtilityDeposit deposit) {
    final amountCtrl = TextEditingController(
      text: deposit.amount.toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController(text: deposit.note ?? '');
    DateTime selectedDate =
        DateTime.tryParse(deposit.depositDate) ?? DateTime.now();
    final defaultReason = deposit.isMemberDeposit
        ? 'Member Utility Deposit'
        : 'Cottage Deposit';

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => _UtilityDrawer(
          icon: Icons.edit_outlined,
          title: deposit.isMemberDeposit
              ? 'Edit Member Deposit'
              : 'Edit Cottage Deposit',
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
                  if (picked != null) {
                    setSheetState(() => selectedDate = picked);
                  }
                },
              ),
            ),
            _DrawerField(
              label: 'Note',
              child: _DrawerTextField(controller: noteCtrl, hint: 'Optional'),
            ),
            _DrawerField(
              label: 'Total Amount',
              child: _DrawerAmountField(controller: amountCtrl),
            ),
            _DrawerSaveButton(
              label: 'Save Changes',
              onTap: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) {
                  showToast(ctx, 'Enter a valid amount.');
                  return;
                }
                Navigator.pop(ctx);
                await _utilityService.updateDeposit(
                  id: deposit.id,
                  amount: amount,
                  depositDate: _isoDate(selectedDate),
                  note: noteCtrl.text.trim(),
                  defaultReason: defaultReason,
                );
                _refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDeposit(UtilityDeposit deposit) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete this ${deposit.isMemberDeposit ? 'member' : 'cottage'} deposit?',
        ),
        content: const Text(
          'This also removes the linked Cottage Balance transaction. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _utilityService.deleteDeposit(deposit.id);
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

  Future<Profile?> _pickMember(BuildContext context, List<Profile> members) {
    return showModalBottomSheet<Profile>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

  /// Same fixed category list as the web app's AddExpenseForm Select
  /// (every UTILITY_CATEGORY_LABELS entry except 'other', which sits last
  /// as its own option so picking it can reveal the custom-name field).
  Future<String?> _pickCategory(BuildContext context) {
    final options = [
      ...utilityCategoryLabels.keys.where((k) => k != 'other'),
      'other',
    ];
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final key in options)
              ListTile(
                title: Text(utilityCategoryLabels[key]!),
                onTap: () => Navigator.pop(ctx, key),
              ),
          ],
        ),
      ),
    );
  }

  /// Mirrors the web's payment_source display: 'cottage_balance' -> "Cottage
  /// Balance", 'member' -> "Member - {name}", everything else (including
  /// null/'none') -> "None". [_ExpenseTab] used to just show the raw DB
  /// literal (e.g. "cottage_balance") verbatim.
  static String _paymentSourceLabel(Expense e) {
    switch (e.paymentSource) {
      case 'cottage_balance':
        return 'Cottage Balance';
      case 'member':
        return 'Member${e.payerName != null ? ' - ${e.payerName}' : ''}';
      default:
        return 'None';
    }
  }

  /// Shares a plain-text summary of whichever tab is currently active --
  /// same rationale/pattern as UtilityStatementScreen._download (no PDF
  /// pipeline in this app yet, so a text export is the closest faithful
  /// port of the web's `/utilities/history/pdf` download).
  void _download(_UtilityData data) {
    final monthLabel = _formatMonth(data.monthKey);
    final buffer = StringBuffer();
    switch (_activeTabIndex) {
      case 0:
        buffer.writeln('Utility Expenses -- $monthLabel\n');
        if (data.expenses.isEmpty) buffer.writeln('No utility expenses yet.');
        for (final e in data.expenses) {
          buffer.writeln(
            '${e.expenseDate}  ${utilityCategoryLabel(e.category ?? 'other')}',
          );
          if (e.description?.isNotEmpty ?? false) {
            buffer.writeln('  ${e.description}');
          }
          buffer.writeln('  Payment Source: ${_paymentSourceLabel(e)}');
          buffer.writeln('  Amount: ${e.amount.toStringAsFixed(2)} tk\n');
        }
        break;
      case 1:
        final memberDeposits = data.deposits
            .where((d) => d.isMemberDeposit)
            .toList();
        buffer.writeln('Member Utility Deposits -- $monthLabel\n');
        if (memberDeposits.isEmpty) {
          buffer.writeln('No Member Utility Deposits yet.');
        }
        for (final d in memberDeposits) {
          buffer.writeln('${d.depositDate}  ${d.memberName ?? 'Member'}');
          if (d.note?.isNotEmpty ?? false) buffer.writeln('  ${d.note}');
          buffer.writeln('  Amount: ${d.amount.toStringAsFixed(2)} tk\n');
        }
        break;
      default:
        final cottageDeposits = data.deposits
            .where((d) => !d.isMemberDeposit)
            .toList();
        buffer.writeln('Cottage Deposits -- $monthLabel\n');
        if (cottageDeposits.isEmpty) buffer.writeln('No Cottage Deposits yet.');
        for (final d in cottageDeposits) {
          buffer.writeln(d.depositDate);
          if (d.note?.isNotEmpty ?? false) buffer.writeln('  ${d.note}');
          buffer.writeln('  Amount: ${d.amount.toStringAsFixed(2)} tk\n');
        }
    }
    Share.share(buffer.toString(), subject: 'Utility Details - $monthLabel');
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

  // --- Segmented TabBar (Figma: p-3.217 gap-3.217 rounded-10; each item
  // rounded-8.043, py-6.434 px-9.651 -- labels can wrap to 2 lines, so
  // items size to content rather than a fixed single-line height). ---

  Widget _buildTabBar() {
    return IntrinsicHeight(
      child: Container(
        padding: const EdgeInsets.all(3.217),
        decoration: BoxDecoration(
          color: context.surface.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _UtilityColors.border(context), width: 0.8),
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
          color: active ? CottageColors.primary : _UtilityColors.fieldBg(context),
          borderRadius: BorderRadius.circular(8.043),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: active ? Colors.white : _UtilityColors.darkText(context),
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
                    const Icon(
                      Icons.error_outline,
                      size: 40,
                      color: CottageColors.destructive,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load utilities.\n${snapshot.error}',
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
        final memberDeposits = data.deposits
            .where((d) => d.isMemberDeposit)
            .toList();
        final cottageDeposits = data.deposits
            .where((d) => !d.isMemberDeposit)
            .toList();
        // Mirrors the web: expense edit/delete needs super admin OR
        // can_add_expenses (updateExpense/deleteExpense's own check);
        // deposit edit/delete and the PDF download are super-admin only
        // (addMemberUtilityDeposit/updateCottageDeposit/the pdf route all
        // require profile.role === "super_admin", except the download route
        // which also allows can_add_expenses).
        final canEditExpenses =
            data.profile.isSuperAdmin || data.profile.canAddExpenses;
        final canEditDeposits = data.profile.isSuperAdmin;
        final canDownload = canEditExpenses;

        return Scaffold(
          backgroundColor: CottageColors.primary,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DynamicUtilityDetailsHeaderDelegate(
                    surface: surface,
                    tabBar: _buildTabBar(),
                    monthText: _formatMonth(data.monthKey),
                    canDownload: canDownload,
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
                  _ExpenseTab(
                    expenses: data.expenses,
                    onRefresh: _refresh,
                    onEdit: canEditExpenses ? _showEditExpense : null,
                    onDelete: canEditExpenses ? _confirmDeleteExpense : null,
                  ),
                  _MemberDepositTab(
                    deposits: memberDeposits,
                    onRefresh: _refresh,
                    onEdit: canEditDeposits ? _showEditDeposit : null,
                    onDelete: canEditDeposits ? _confirmDeleteDeposit : null,
                  ),
                  _CottageDepositTab(
                    deposits: cottageDeposits,
                    onRefresh: _refresh,
                    onEdit: canEditDeposits ? _showEditDeposit : null,
                    onDelete: canEditDeposits ? _confirmDeleteDeposit : null,
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

/// Collapsing header for [UtilitiesScreen] -- same mechanics as
/// _DynamicMealHeaderDelegate (meal_screen.dart): the orange band retreats
/// into a compact pinned bar as the tab content below scrolls, with the
/// description + Download button + tab bar always pinned to the header's
/// bottom edge.
class _DynamicUtilityDetailsHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final Widget tabBar;
  final String monthText;
  final bool canDownload;
  final VoidCallback onDownload;
  final double safeAreaTop;

  _DynamicUtilityDetailsHeaderDelegate({
    required this.surface,
    required this.tabBar,
    required this.monthText,
    required this.canDownload,
    required this.onDownload,
    required this.safeAreaTop,
  });

  // A member without download permission doesn't see the Download button
  // (see the `if (canDownload)` below) -- shrink the reserved height by its
  // footprint the same way _DynamicMembersHeaderDelegate does for its
  // "Add Member" button, so hiding it doesn't leave a big empty gap above
  // the tab bar.
  static const _downloadRowFootprint = 48.0;
  static const _noButtonTrailingGap = 8.0;
  double get _heightAdjustment =>
      canDownload ? 0 : (_downloadRowFootprint - _noButtonTrailingGap);

  @override
  double get minExtent => safeAreaTop + 150.0 - _heightAdjustment;

  @override
  double get maxExtent => safeAreaTop + 234.0 - _heightAdjustment;

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

        // Expanded Content (Fades out) -- clipped in an OverflowBox since
        // the enclosing box keeps shrinking continuously as the header
        // collapses, so partway through the scroll it's already smaller
        // than this Column's fixed content height; without this a
        // RenderFlex overflow banner shows mid-scroll.
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
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
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
                                'Utility Details',
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
                        // White Card Content (Description)
                        Padding(
                          padding: EdgeInsets.only(
                            left: context.responsivePadding,
                            right: context.responsivePadding,
                            top: 16,
                          ),
                          child: Text(
                            'Read-only record of every utility expense and deposit. No calculations happen here.',
                            style: TextStyle(
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
                            'Utility Details',
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
              if (canDownload)
                Row(
                  children: [
                    GestureDetector(
                      onTap: onDownload,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: context.surface.card,
                          border: Border.all(color: _UtilityColors.border(context)),
                          borderRadius: BorderRadius.circular(1000),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.download_rounded,
                              size: 20,
                              color: _UtilityColors.darkText(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Download',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _UtilityColors.darkText(context),
                              ),
                            ),
                          ],
                        ),
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
  bool shouldRebuild(
    covariant _DynamicUtilityDetailsHeaderDelegate oldDelegate,
  ) {
    return true;
  }
}

// --- Add Expense/Deposit drawers (Figma "Section 5": nodes 77:1052,
// 77:1154, 77:1255) -- icon+title+close header, gap-16 between fields,
// each field a gap-6 label(+red asterisk)/box pair, fafafa/eee/radius-10
// boxes, and a #D1593B pill save button. ---

class _UtilityDrawer extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _UtilityDrawer({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    // Scrollable, like CottageSheetContent, so a full form (all fields plus
    // the keyboard covering half the screen) scrolls instead of overflowing
    // -- showCottageSheet only caps the sheet's max height, it doesn't make
    // its content scrollable on its own.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _UtilityColors.headingText(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _UtilityColors.headingText(context),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _UtilityColors.fieldBg(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: _UtilityColors.headingText(context),
                  ),
                ),
              ),
            ],
          ),
          for (final child in children) ...[const SizedBox(height: 16), child],
        ],
      ),
    );
  }
}

/// One choice in the Payment Source picker (Member / Cottage Balance /
/// None) -- mirrors the web app's AddExpenseForm radio group, styled as a
/// pill to match this drawer's other toggle-like controls.
class _PaymentSourceOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentSourceOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _UtilityColors.saveButton : _UtilityColors.fieldBg(context),
          border: Border.all(
            color: selected
                ? _UtilityColors.saveButton
                : _UtilityColors.border(context),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _UtilityColors.darkText(context),
          ),
        ),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: _UtilityColors.darkText(context),
              ),
            ),
            const SizedBox(width: 2),
            const Text(
              '*',
              style: TextStyle(
                fontSize: 13,
                color: _UtilityColors.requiredMark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _UtilityColors.fieldBg(context),
            border: Border.all(color: _UtilityColors.border(context)),
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
      style: TextStyle(fontSize: 13, color: _UtilityColors.darkText(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: _UtilityColors.placeholder(context),
        ),
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

  const _DrawerTapField({
    required this.value,
    this.isPlaceholder = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: isPlaceholder
              ? _UtilityColors.placeholder(context)
              : _UtilityColors.darkText(context),
        ),
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
        Text(
          '৳',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _UtilityColors.placeholder(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 13,
              color: _UtilityColors.darkText(context),
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                fontSize: 13,
                color: _UtilityColors.placeholder(context),
              ),
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
        decoration: BoxDecoration(
          color: _UtilityColors.saveButton,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

String _formatCardDate(String isoDate) {
  try {
    final d = DateTime.parse(isoDate);
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
    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  } catch (_) {
    return isoDate;
  }
}

/// Figma "Self driver requirement" card shell: white, border #eee, radius
/// 8, p-4, gap-4 column of [date row, ...content].
class _UtilityCard extends StatelessWidget {
  final String date;
  // Only rendered when non-null -- mirrors UtilityDetailsMobile.tsx's
  // `canEditExpenses && (<Edit.../><Delete.../>)`: a viewer without
  // permission sees a plain read-only card with no action boxes at all,
  // not a disabled/no-op button.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget content;

  const _UtilityCard({
    required this.date,
    this.onEdit,
    this.onDelete,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surface.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _UtilityColors.border(context), width: 0.8),
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
                    color: _UtilityColors.fieldBg(context),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _UtilityColors.border(context),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    _formatCardDate(date),
                    style: TextStyle(
                      fontSize: 14,
                      color: _UtilityColors.darkText(context),
                    ),
                  ),
                ),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 4),
                _UtilityIconBox(icon: Icons.edit_outlined, onTap: onEdit!),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                _UtilityIconBox(
                  icon: Icons.delete_outline,
                  iconColor: CottageColors.destructive,
                  onTap: onDelete!,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          content,
        ],
      ),
    );
  }
}

class _UtilityIconBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _UtilityIconBox({
    required this.icon,
    this.iconColor = CottageColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _UtilityColors.fieldBg(context),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _UtilityColors.border(context), width: 0.8),
        ),
        child: Icon(icon, size: 18, color: iconColor),
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

  const _UtilityInfoRow({
    required this.label,
    required this.value,
    this.boldValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _UtilityColors.fieldBg(context),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _UtilityColors.border(context), width: 0.8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: CottageColors.primary),
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 1,
                height: 21,
                color: _UtilityColors.border(context),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: boldValue ? FontWeight.bold : FontWeight.w400,
              color: _UtilityColors.darkText(context),
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
        color: _UtilityColors.fieldBg(context),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _UtilityColors.border(context), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: _UtilityColors.placeholder(context)),
      ),
    );
  }
}

// --- Expense Tab (Figma "Utility Details - Expense") ---

class _ExpenseTab extends StatelessWidget {
  final List<Expense> expenses;
  final VoidCallback onRefresh;
  final void Function(Expense)? onEdit;
  final void Function(Expense)? onDelete;

  const _ExpenseTab({
    required this.expenses,
    required this.onRefresh,
    this.onEdit,
    this.onDelete,
  });

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
        padding: EdgeInsets.fromLTRB(
          context.responsivePadding,
          0,
          context.responsivePadding,
          context.bottomNavClearance,
        ),
        itemCount: expenses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final e = expenses[index];
          final title = utilityCategoryLabel(e.category ?? 'other');

          return _UtilityCard(
            date: e.expenseDate,
            onEdit: onEdit != null ? () => onEdit!(e) : null,
            onDelete: onDelete != null ? () => onDelete!(e) : null,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _UtilityColors.highlightBg(context),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _UtilityColors.border(context),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CottageColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (e.description?.isNotEmpty ?? false)
                            ? e.description!
                            : title,
                        style: TextStyle(
                          fontSize: 14,
                          color: _UtilityColors.darkText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _UtilityInfoRow(
                  label: 'Payment Source',
                  value: _UtilitiesScreenState._paymentSourceLabel(e),
                ),
                const SizedBox(height: 4),
                _UtilityInfoRow(
                  label: 'Total Amount',
                  value: '${e.amount.toStringAsFixed(2)} tk',
                  boldValue: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Member Deposit row's avatar chip -- a plain [CircleAvatar] with
/// `backgroundImage: NetworkImage(...)` used to have no failure handling at
/// all: a broken/corrupt/oversized image (this URL comes straight from
/// whatever a member uploaded as their profile photo, unvalidated) could
/// crash image decoding hard enough to take the whole app process down
/// with it (seen as a native tombstone in logcat, not a catchable Dart
/// exception) -- reported when opening this tab specifically, since it's
/// the one place these avatars render as `backgroundImage` decode failures
/// rather than via `Image.network`'s own error-safe loading elsewhere.
/// [onBackgroundImageError] can't stop a native decoder crash, but it does
/// stop the ordinary "bad/unreachable URL" case from ever reaching that
/// code path a second time, and reliably falls back to initials instead of
/// leaving a permanently-broken image widget in the tree.
class _DepositMemberAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String name;
  const _DepositMemberAvatar({required this.avatarUrl, required this.name});

  @override
  State<_DepositMemberAvatar> createState() => _DepositMemberAvatarState();
}

class _DepositMemberAvatarState extends State<_DepositMemberAvatar> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final hasUrl = (widget.avatarUrl?.isNotEmpty ?? false) && !_failed;
    return CircleAvatar(
      radius: 13.5,
      backgroundColor: CottageColors.primary.withValues(alpha: 0.1),
      backgroundImage: hasUrl ? NetworkImage(widget.avatarUrl!) : null,
      onBackgroundImageError: hasUrl
          ? (_, _) {
              if (mounted) setState(() => _failed = true);
            }
          : null,
      child: hasUrl
          ? null
          : Text(
              widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: CottageColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
    );
  }
}

// --- Member Deposit Tab (Figma "Utility Details - Member Deposit") ---

class _MemberDepositTab extends StatelessWidget {
  final List<UtilityDeposit> deposits;
  final VoidCallback onRefresh;
  final void Function(UtilityDeposit)? onEdit;
  final void Function(UtilityDeposit)? onDelete;

  const _MemberDepositTab({
    required this.deposits,
    required this.onRefresh,
    this.onEdit,
    this.onDelete,
  });

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
        padding: EdgeInsets.fromLTRB(
          context.responsivePadding,
          0,
          context.responsivePadding,
          context.bottomNavClearance,
        ),
        itemCount: deposits.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final d = deposits[index];
          final name = d.memberName ?? 'Member';

          return _UtilityCard(
            date: d.depositDate,
            onEdit: onEdit != null ? () => onEdit!(d) : null,
            onDelete: onDelete != null ? () => onDelete!(d) : null,
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 109,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _UtilityColors.fieldBg(context),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _UtilityColors.border(context),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DepositMemberAvatar(avatarUrl: d.avatarUrl, name: name),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _UtilityNoteRow(
                        (d.note?.isNotEmpty ?? false)
                            ? d.note!
                            : 'No notes detailed',
                      ),
                      const SizedBox(height: 4),
                      _UtilityInfoRow(
                        label: 'Total Amount',
                        value: '${d.amount.toStringAsFixed(2)} tk',
                        boldValue: true,
                      ),
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
  final void Function(UtilityDeposit)? onEdit;
  final void Function(UtilityDeposit)? onDelete;

  const _CottageDepositTab({
    required this.deposits,
    required this.onRefresh,
    this.onEdit,
    this.onDelete,
  });

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
        padding: EdgeInsets.fromLTRB(
          context.responsivePadding,
          0,
          context.responsivePadding,
          context.bottomNavClearance,
        ),
        itemCount: deposits.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final d = deposits[index];

          return _UtilityCard(
            date: d.depositDate,
            onEdit: onEdit != null ? () => onEdit!(d) : null,
            onDelete: onDelete != null ? () => onDelete!(d) : null,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UtilityNoteRow(
                  (d.note?.isNotEmpty ?? false) ? d.note! : 'No notes detailed',
                ),
                const SizedBox(height: 4),
                _UtilityInfoRow(
                  label: 'Total Amount',
                  value: '${d.amount.toStringAsFixed(2)} tk',
                  boldValue: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
