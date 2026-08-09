import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/common_widgets/cottage_loader.dart';
import 'package:cottage/common_widgets/password_confirm_dialog.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../data/month_models.dart';
import '../data/months_service.dart';

const _border = Color(0xFFEEEEEE);
const _fieldBg = Color(0xFFFAFAFA);
const _darkText = Color(0xFF404040);
const _placeholder = Color(0xFFAAAAAA);
const _headingText = Color(0xFF17191E);
const _mutedText = Color(0xFF7A818D);
const _dangerRed = Color(0xFFFF4F4F);
const _setActiveButton = Color(0xFFD1593B);

const _months = [
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

String _monthLabel(String monthKey) {
  final parts = monthKey.split('-');
  final month = int.tryParse(parts[1]) ?? 1;
  return '${_months[month - 1]} ${parts[0]}';
}

String _lockedDate(DateTime d) {
  const shortMonths = [
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
  return '${d.day} ${shortMonths[d.month - 1]} ${d.year}';
}

/// "Months" page -- Figma node 126:1504: the active month's cottage-wide
/// totals, a "Set Active Month" field/button, a Danger Zone (reset the
/// active month's Utility/Meal ledgers), and History (locked months, each
/// with Activate/Delete). Backed entirely by the month-management RPCs in
/// supabase/migrations/0007 and 0009. Pushed from the Menu tab's speed
/// dial ('months' action, previously a "coming soon" stub).
class MonthsScreen extends StatefulWidget {
  const MonthsScreen({super.key});

  @override
  State<MonthsScreen> createState() => _MonthsScreenState();
}

class _MonthsData {
  final Profile viewer;
  final MonthStats activeStats;
  final List<MonthHistoryEntry> history;
  const _MonthsData({
    required this.viewer,
    required this.activeStats,
    required this.history,
  });
}

class _MonthsScreenState extends State<MonthsScreen> {
  final _dashService = DashboardService();
  final _monthsService = MonthsService();
  late Future<_MonthsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MonthsData> _load() async {
    final viewer = await _dashService.getCurrentProfileFull();
    final activeMonthKey = await _dashService.getActiveMonthKey(
      viewer.cottageId,
    );
    final activeStats = await _monthsService.getMonthStats(
      viewer.cottageId,
      activeMonthKey,
    );
    final history = await _monthsService.getHistory(viewer.cottageId);
    return _MonthsData(
      viewer: viewer,
      activeStats: activeStats,
      history: history,
    );
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _runConfirmed({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
    bool destructive = true,
  }) async {
    final confirmed = await showPasswordConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );
    if (!confirmed) return;
    try {
      await action();
    } catch (e) {
      if (mounted) showToast(context, '$e');
      return;
    }
    if (mounted) showToast(context, 'Done.');
    _refresh();
  }

  Future<void> _pickMonth(
    void Function(String) onPicked,
    String? current,
  ) async {
    final now = DateTime.now();
    final initial = current != null
        ? DateTime.tryParse('$current-01') ?? now
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Pick a month',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    onPicked(
      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}',
    );
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
              child: const Row(
                children: [
                  Text(
                    'Months',
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
                child: FutureBuilder<_MonthsData>(
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
                              'Could not load months.\n${snapshot.error}',
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
                    return _MonthsBody(
                      data: snapshot.data!,
                      monthsService: _monthsService,
                      onRunConfirmed: _runConfirmed,
                      onPickMonth: _pickMonth,
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
}

typedef _ConfirmedRunner =
    Future<void> Function({
      required String title,
      required String message,
      required String confirmLabel,
      required Future<void> Function() action,
      bool destructive,
    });

class _MonthsBody extends StatefulWidget {
  final _MonthsData data;
  final MonthsService monthsService;
  final _ConfirmedRunner onRunConfirmed;
  final Future<void> Function(void Function(String), String?) onPickMonth;

  const _MonthsBody({
    required this.data,
    required this.monthsService,
    required this.onRunConfirmed,
    required this.onPickMonth,
  });

  @override
  State<_MonthsBody> createState() => _MonthsBodyState();
}

class _MonthsBodyState extends State<_MonthsBody> {
  String? _pickedMonthKey;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isAdmin = data.viewer.isSuperAdmin;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.responsivePadding,
        24,
        context.responsivePadding,
        24,
      ),
      children: [
        const Text(
          'Manage the active month and browse locked history. All actions require your password to confirm.',
          style: TextStyle(fontSize: 14, color: Color(0xFF303030)),
        ),
        const SizedBox(height: 16),
        _MonthCard(
          stats: data.activeStats,
          badgeLabel: 'Active',
          badgeBg: const Color(0xFFE8F5EC),
          badgeFg: const Color(0xFF059669),
        ),
        if (isAdmin) ...[
          const SizedBox(height: 16),
          const Text(
            'Set Active Month',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _headingText,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => widget.onPickMonth(
              (key) => setState(() => _pickedMonthKey = key),
              _pickedMonthKey,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _fieldBg,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _pickedMonthKey == null
                    ? 'Select a month'
                    : _monthLabel(_pickedMonthKey!),
                style: TextStyle(
                  fontSize: 13,
                  color: _pickedMonthKey == null ? _placeholder : _darkText,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickedMonthKey == null
                ? null
                : () => widget.onRunConfirmed(
                    title: 'Set active month?',
                    message:
                        'This locks ${_monthLabel(data.activeStats.monthKey)} and opens ${_monthLabel(_pickedMonthKey!)}.',
                    confirmLabel: 'Set Active Month',
                    destructive: false,
                    action: () =>
                        widget.monthsService.setActiveMonth(_pickedMonthKey!),
                  ),
            child: Container(
              width: double.infinity,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _pickedMonthKey == null
                    ? _setActiveButton.withValues(alpha: 0.5)
                    : _setActiveButton,
                borderRadius: BorderRadius.circular(1000),
              ),
              child: const Text(
                'Set Active Month',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Danger Zone',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _headingText,
            ),
          ),
          const SizedBox(height: 6),
          _DangerButton(
            label: 'Reset current month utilities',
            onTap: () => widget.onRunConfirmed(
              title: 'Reset this month\'s utilities?',
              message:
                  'Deletes every utility expense, settlement, and cottage balance transaction for ${_monthLabel(data.activeStats.monthKey)}. This can\'t be undone.',
              confirmLabel: 'Reset',
              action: widget.monthsService.resetUtilityMonth,
            ),
          ),
          const SizedBox(height: 8),
          _DangerButton(
            label: 'Reset current month meal',
            onTap: () => widget.onRunConfirmed(
              title: 'Reset this month\'s meals?',
              message:
                  'Deletes every bazaar entry, meal deposit, and daily meal count for ${_monthLabel(data.activeStats.monthKey)}. This can\'t be undone.',
              confirmLabel: 'Reset',
              action: widget.monthsService.resetMealMonth,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: _headingText,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Locked months. A month lands here once a different month is set active.',
          style: TextStyle(fontSize: 12, color: _mutedText),
        ),
        const SizedBox(height: 12),
        if (data.history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No locked months yet.',
              style: TextStyle(fontSize: 13, color: _mutedText),
            ),
          )
        else
          for (final entry in data.history)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _MonthCard(
                stats: entry.stats,
                badgeLabel: 'Locked ${_lockedDate(entry.closedAt)}',
                badgeBg: _fieldBg,
                badgeFg: _mutedText,
                actions: isAdmin
                    ? Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onRunConfirmed(
                                title:
                                    'Activate ${_monthLabel(entry.monthKey)}?',
                                message:
                                    'This re-locks ${_monthLabel(data.activeStats.monthKey)} and reopens ${_monthLabel(entry.monthKey)}.',
                                confirmLabel: 'Activate',
                                destructive: false,
                                action: () => widget.monthsService
                                    .activateMonth(entry.monthKey),
                              ),
                              child: Container(
                                height: 40,
                                alignment: Alignment.center,
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
                                  children: const [
                                    Icon(
                                      Icons.download_outlined,
                                      size: 18,
                                      color: _darkText,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Activate',
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
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onRunConfirmed(
                                title: 'Delete ${_monthLabel(entry.monthKey)}?',
                                message:
                                    'Permanently deletes every record for ${_monthLabel(entry.monthKey)}. This can\'t be undone.',
                                confirmLabel: 'Delete',
                                action: () => widget.monthsService.deleteMonth(
                                  entry.monthKey,
                                ),
                              ),
                              child: Container(
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _dangerRed,
                                  borderRadius: BorderRadius.circular(1000),
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
      ],
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DangerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _dangerRed,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final MonthStats stats;
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeFg;
  final Widget? actions;

  const _MonthCard({
    required this.stats,
    required this.badgeLabel,
    required this.badgeBg,
    required this.badgeFg,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
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
              Flexible(
                child: Text(
                  _monthLabel(stats.monthKey),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _headingText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _statRow(
            'Total Utility Due',
            '${stats.totalUtilityDue.toStringAsFixed(2)} tk',
          ),
          const SizedBox(height: 4),
          _statRow(
            'Total Bazaar',
            '${stats.totalBazaar.toStringAsFixed(2)} tk',
          ),
          const SizedBox(height: 4),
          _statRow(
            'Total Meals',
            stats.totalMeals.toStringAsFixed(stats.totalMeals % 1 == 0 ? 0 : 1),
          ),
          const SizedBox(height: 4),
          _statRow('Meal Rate', '${stats.mealRate.toStringAsFixed(2)} tk'),
          if (actions != null) ...[const SizedBox(height: 8), actions!],
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Container(
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
              label,
              style: const TextStyle(fontSize: 12, color: _mutedText),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _headingText,
            ),
          ),
        ],
      ),
    );
  }
}
