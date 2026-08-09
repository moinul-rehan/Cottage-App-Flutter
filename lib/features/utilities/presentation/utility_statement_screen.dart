import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'package:cottage/common_widgets/cottage_loader.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../../menu/data/member_service.dart';
import '../data/utility_statement_models.dart';
import '../data/utility_statement_service.dart';

const _fieldBg = Color(0xFFFAFAFA);
const _border = Color(0xFFEEEEEE);
const _darkText = Color(0xFF404040);
const _placeholder = Color(0xFFAAAAAA);
const _headingText = Color(0xFF17191E);
const _requiredMark = Color(0xFFCC4F4F);
const _saveButton = Color(0xFFD1593B);

/// "Utility Statement" page -- Figma node 115:1343: every active member's
/// carry-in + this month's utility_adjustments lines, Assigned Cost/Paid/
/// Remaining Due per member, and (super admin only, matching
/// utility_adjustments' insert RLS) an "Add Adjustment" drawer to add a new
/// line for one member or split across everyone. Pushed from the Utilities
/// tab's speed-dial menu.
class UtilityStatementScreen extends StatefulWidget {
  const UtilityStatementScreen({super.key});

  @override
  State<UtilityStatementScreen> createState() => _UtilityStatementScreenState();
}

class _StatementData {
  final Profile viewer;
  final String monthKey;
  final List<MemberStatement> statements;
  const _StatementData({
    required this.viewer,
    required this.monthKey,
    required this.statements,
  });
}

class _UtilityStatementScreenState extends State<UtilityStatementScreen> {
  final _dashService = DashboardService();
  final _memberService = MemberService();
  final _statementService = UtilityStatementService();
  late Future<_StatementData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatementData> _load() async {
    final viewer = await _dashService.getCurrentProfileFull();
    final monthKey = await _dashService.getActiveMonthKey(viewer.cottageId);
    final members = await _memberService.getActiveMembers(viewer.cottageId);
    final statements = await _statementService.getStatements(
      cottageId: viewer.cottageId,
      monthKey: monthKey,
      members: members,
    );
    return _StatementData(
      viewer: viewer,
      monthKey: monthKey,
      statements: statements,
    );
  }

  void _refresh() => setState(() => _future = _load());

  String _monthLabel(String monthKey) {
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
    final parts = monthKey.split('-');
    final month = int.tryParse(parts[1]) ?? 1;
    return '${months[month - 1]} ${parts[0]}';
  }

  /// Shares a plain-text summary of every member's statement -- Figma's
  /// "Download" button doesn't specify a file format, and the app already
  /// has no PDF/print pipeline, so this is the simplest faithful "export
  /// this statement" action (mirrors Share.shareXFiles already used for
  /// the personal invoice PNG in utility_breakdown_sheet.dart, just as
  /// text since this is a whole-cottage summary rather than one image).
  void _download(_StatementData data) {
    final monthLabel = _monthLabel(data.monthKey);
    final buffer = StringBuffer('Utility Statement -- $monthLabel\n\n');
    for (final s in data.statements) {
      buffer.writeln(s.profile.displayName);
      for (final line in s.lines) {
        buffer.writeln(
          '  ${line.label}: ${line.amount >= 0 ? '+' : '-'}${line.amount.abs().toStringAsFixed(2)} tk',
        );
      }
      buffer.writeln(
        '  Assigned Cost: ${s.assignedCost.toStringAsFixed(2)} tk',
      );
      buffer.writeln('  Paid: ${s.paid.toStringAsFixed(2)} tk');
      buffer.writeln(
        '  ${s.due < 0 ? 'Advance Balance' : 'Remaining Due'}: ${s.due.abs().toStringAsFixed(2)} tk\n',
      );
    }
    Share.share(buffer.toString(), subject: 'Utility Statement - $monthLabel');
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Scaffold(
      backgroundColor: CottageColors.primary,
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
              child: FutureBuilder<_StatementData>(
                future: _future,
                builder: (context, snapshot) {
                  final monthLabel = snapshot.hasData
                      ? _monthLabel(snapshot.data!.monthKey)
                      : '';
                  // No back arrow -- matches Figma (and this app's other
                  // pushed pages, e.g. ContactsScreen), which rely on the
                  // system back gesture/button instead of an in-header one.
                  return Row(
                    children: [
                      const Text(
                        'Utility Statement',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      if (monthLabel.isNotEmpty) ...[
                        const SizedBox(width: 11),
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
                            monthLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: CottageColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
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
                child: FutureBuilder<_StatementData>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CottageLoader());
                    }
                    if (snapshot.hasError) {
                      return Center(
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
                              'Could not load the statement.\n${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final data = snapshot.data!;
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          context.responsivePadding,
                          24,
                          context.responsivePadding,
                          24,
                        ),
                        children: [
                          Text(
                            'Final utility bill for ${_monthLabel(data.monthKey)} — rent, expenses, carry-in dues and manual adjustments, all distributed to members.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF303030),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _download(data),
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: _border),
                                    borderRadius: BorderRadius.circular(1000),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.06,
                                        ),
                                        blurRadius: 1,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.download_outlined,
                                        size: 18,
                                        color: _darkText,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Download',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: _darkText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (data.viewer.isSuperAdmin)
                                GestureDetector(
                                  onTap: () => _showAddAdjustment(data),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDE7356),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '+',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Add Adjustment',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Member Statements',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _headingText,
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (final s in data.statements)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _MemberStatementCard(statement: s),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _categories = ['electricity', 'internet', 'gas', 'other'];
  static const _categoryLabels = {
    'electricity': 'Electricity',
    'internet': 'Internet',
    'gas': 'Gas',
    'other': 'Other',
  };

  /// Figma "Add Adjustment - Drawer" (node 119:1365) plus its "Other
  /// Category" / "All Members" (equal + custom split) variant states, all
  /// driven by the same form here rather than four separate drawers.
  void _showAddAdjustment(_StatementData data) {
    String category = 'electricity';
    final customCategoryCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool increase = true;
    bool applyToAll = false;
    String? selectedMemberId;
    bool splitEqually = true;
    final customSplitCtrls = {
      for (final m in data.statements)
        m.profile.id: TextEditingController(text: '0'),
    };
    String paymentSource = 'none';
    String? paymentMemberId;
    String paymentLabel = 'None';

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final total = double.tryParse(amountCtrl.text) ?? 0;
          final memberCount = data.statements.length;
          final customSplitSum = customSplitCtrls.values.fold<double>(
            0,
            (s, c) => s + (double.tryParse(c.text) ?? 0),
          );

          Future<void> pickMember() async {
            final picked = await showCottageSheet<String>(
              context: sheetContext,
              builder: (_) => ListView(
                shrinkWrap: true,
                children: [
                  for (final s in data.statements)
                    ListTile(
                      title: Text(s.profile.displayName),
                      trailing: s.profile.id == selectedMemberId
                          ? const Icon(
                              Icons.check,
                              color: CottageColors.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(sheetContext, s.profile.id),
                    ),
                ],
              ),
            );
            if (picked != null) setSheetState(() => selectedMemberId = picked);
          }

          Future<void> pickPaidBy() async {
            final options = <(String, String, String?)>[
              ('None', 'none', null),
              ('Cottage Balance', 'cottage_balance', null),
              for (final s in data.statements)
                (s.profile.displayName, 'member', s.profile.id),
            ];
            final picked = await showCottageSheet<int>(
              context: sheetContext,
              builder: (_) => ListView(
                shrinkWrap: true,
                children: [
                  for (int i = 0; i < options.length; i++)
                    ListTile(
                      title: Text(options[i].$1),
                      onTap: () => Navigator.pop(sheetContext, i),
                    ),
                ],
              ),
            );
            if (picked != null) {
              setSheetState(() {
                paymentLabel = options[picked].$1;
                paymentSource = options[picked].$2;
                paymentMemberId = options[picked].$3;
              });
            }
          }

          return _AdjustmentDrawerShell(
            children: [
              _FieldLabel('Category', required: true),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _categories)
                    _Chip(
                      label: _categoryLabels[c]!,
                      selected: category == c,
                      onTap: () => setSheetState(() => category = c),
                    ),
                ],
              ),
              if (category == 'other') ...[
                const SizedBox(height: 16),
                _FieldLabel('Custom Category Name', required: true),
                const SizedBox(height: 6),
                TextField(
                  controller: customCategoryCtrl,
                  style: const TextStyle(fontSize: 13, color: _darkText),
                  decoration: _fieldDecoration('e.g. Discount, Wi-Fi Router'),
                  textCapitalization: TextCapitalization.words,
                ),
              ],
              const SizedBox(height: 16),
              _FieldLabel('Amount', required: true),
              const SizedBox(height: 6),
              TextField(
                controller: amountCtrl,
                style: const TextStyle(fontSize: 13, color: _darkText),
                decoration: _fieldDecoration('0.00', prefix: '৳'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 16),
              const Text(
                'Adjustment Type',
                style: TextStyle(fontSize: 13, color: _darkText),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ToggleOption(
                      label: 'Increase Due',
                      selected: increase,
                      selectedColor: _requiredMark,
                      onTap: () => setSheetState(() => increase = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ToggleOption(
                      label: 'Reduce Due',
                      selected: !increase,
                      onTap: () => setSheetState(() => increase = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Apply To',
                style: TextStyle(fontSize: 13, color: _darkText),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ToggleOption(
                      label: 'Specific Member',
                      selected: !applyToAll,
                      onTap: () => setSheetState(() => applyToAll = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ToggleOption(
                      label: 'All Members',
                      selected: applyToAll,
                      onTap: () => setSheetState(() => applyToAll = true),
                    ),
                  ),
                ],
              ),
              if (!applyToAll) ...[
                const SizedBox(height: 16),
                _FieldLabel('Member', required: true),
                const SizedBox(height: 6),
                _TapField(
                  value: selectedMemberId == null
                      ? 'Select member'
                      : data.statements
                            .firstWhere((s) => s.profile.id == selectedMemberId)
                            .profile
                            .displayName,
                  isPlaceholder: selectedMemberId == null,
                  onTap: pickMember,
                ),
              ] else ...[
                const SizedBox(height: 16),
                const Text(
                  'Split Mode',
                  style: TextStyle(fontSize: 13, color: _darkText),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _ToggleOption(
                        label: 'Split Equally',
                        selected: splitEqually,
                        onTap: () => setSheetState(() => splitEqually = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ToggleOption(
                        label: 'Custom Split',
                        selected: !splitEqually,
                        onTap: () => setSheetState(() => splitEqually = false),
                      ),
                    ),
                  ],
                ),
                if (splitEqually) ...[
                  const SizedBox(height: 12),
                  Text(
                    memberCount == 0
                        ? 'No active members to split across.'
                        : '${total.toStringAsFixed(2)} tk will be split evenly across all $memberCount members '
                              '(${(total / memberCount).toStringAsFixed(2)} tk each).',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A818D),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  for (final s in data.statements)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.profile.displayName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _darkText,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: customSplitCtrls[s.profile.id],
                              style: const TextStyle(
                                fontSize: 13,
                                color: _darkText,
                              ),
                              decoration: _fieldDecoration('0.00'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setSheetState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Assigned: ${customSplitSum.toStringAsFixed(2)} / ${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: customSplitSum == total
                          ? const Color(0xFF16A34A)
                          : _requiredMark,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              const Text(
                'Paid By (optional)',
                style: TextStyle(fontSize: 13, color: _darkText),
              ),
              const SizedBox(height: 6),
              _TapField(
                value: paymentLabel,
                isPlaceholder: paymentLabel == 'None',
                onTap: pickPaidBy,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saveButton,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                ),
                onPressed: () async {
                  if (total <= 0) {
                    showToast(sheetContext, 'Enter a valid amount.');
                    return;
                  }
                  final resolvedCategory = category == 'other'
                      ? customCategoryCtrl.text.trim()
                      : category;
                  if (resolvedCategory.isEmpty) {
                    showToast(sheetContext, 'Enter a custom category name.');
                    return;
                  }
                  final signed = increase ? total : -total;

                  final Map<String, double> amountsByUser;
                  if (!applyToAll) {
                    if (selectedMemberId == null) {
                      showToast(sheetContext, 'Select a member.');
                      return;
                    }
                    amountsByUser = {selectedMemberId!: signed};
                  } else if (memberCount == 0) {
                    showToast(
                      sheetContext,
                      'No active members to split across.',
                    );
                    return;
                  } else if (splitEqually) {
                    final each = signed / memberCount;
                    amountsByUser = {
                      for (final s in data.statements) s.profile.id: each,
                    };
                  } else {
                    if (customSplitSum != total) {
                      showToast(
                        sheetContext,
                        'Custom split must add up to the total amount.',
                      );
                      return;
                    }
                    amountsByUser = {
                      for (final s in data.statements)
                        s.profile.id:
                            (increase ? 1 : -1) *
                            (double.tryParse(
                                  customSplitCtrls[s.profile.id]!.text,
                                ) ??
                                0),
                    };
                  }

                  Navigator.pop(sheetContext);
                  try {
                    await _statementService.addAdjustment(
                      cottageId: data.viewer.cottageId,
                      monthKey: data.monthKey,
                      amountsByUser: amountsByUser,
                      category: resolvedCategory,
                      paymentSource: paymentSource,
                      paymentMemberId: paymentMemberId,
                      createdBy: data.viewer.id,
                    );
                  } catch (e) {
                    if (mounted) {
                      showToast(context, 'Could not add adjustment: $e');
                    }
                    return;
                  }
                  _refresh();
                },
                child: const Text(
                  'Add Adjustment',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint, {String? prefix}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: _border),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: _placeholder),
    prefixText: prefix,
    prefixStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _placeholder,
    ),
    filled: true,
    fillColor: _fieldBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    isDense: true,
  );
}

class _MemberStatementCard extends StatelessWidget {
  final MemberStatement statement;
  const _MemberStatementCard({required this.statement});

  @override
  Widget build(BuildContext context) {
    final due = statement.due;
    final dueLabel = due < 0 ? 'Advance Balance' : 'Remaining Due';
    final dueColor = due < 0 ? const Color(0xFF16A34A) : _requiredMark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                statement.profile.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _headingText,
                ),
              ),
              if (statement.isSettled) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Paid',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (statement.lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final line in statement.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _fieldBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7A818D),
                          ),
                        ),
                      ),
                      Text(
                        '${line.amount >= 0 ? '+' : '−'}${line.amount.abs().toStringAsFixed(2)} tk',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: line.amount >= 0
                              ? _requiredMark
                              : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Assigned Cost',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: _headingText,
                  ),
                ),
              ),
              Text(
                '${statement.assignedCost.toStringAsFixed(2)} tk',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: _headingText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Paid',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7A818D)),
                ),
              ),
              Text(
                '${statement.paid.toStringAsFixed(2)} tk',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A818D)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  dueLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: dueColor,
                  ),
                ),
              ),
              Text(
                '${due.abs().toStringAsFixed(2)} tk',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: dueColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdjustmentDrawerShell extends StatelessWidget {
  final List<Widget> children;
  const _AdjustmentDrawerShell({required this.children});

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
              const Icon(
                Icons.payments_outlined,
                size: 20,
                color: _headingText,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Add Adjustment',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _headingText,
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
                    color: _fieldBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.close, size: 16, color: _darkText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$text ', style: const TextStyle(fontSize: 13, color: _darkText)),
        if (required)
          const Text('*', style: TextStyle(fontSize: 13, color: _requiredMark)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDE7356) : _fieldBg,
          border: Border.all(
            color: selected ? const Color(0xFFDE7356) : _border,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : _darkText,
          ),
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;
  const _ToggleOption({
    required this.label,
    required this.selected,
    this.selectedColor = const Color(0xFFDE7356),
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
          color: selected ? selectedColor : _fieldBg,
          border: Border.all(color: selected ? selectedColor : _border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _darkText,
          ),
        ),
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;
  const _TapField({
    required this.value,
    this.isPlaceholder = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _fieldBg,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isPlaceholder ? _placeholder : _darkText,
          ),
        ),
      ),
    );
  }
}
