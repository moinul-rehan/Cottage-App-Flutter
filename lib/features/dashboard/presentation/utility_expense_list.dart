import 'package:flutter/material.dart';
import 'package:cottage/constants/theme.dart';
import '../data/dashboard_data.dart';

/// Vertical restyle of the "Utility overview" `StatCard` grid this screen
/// used to render as a 1-3 column grid -- same four metrics
/// (`cottageBalance`/`totalUtilityExpense`/`outstandingFromMembers`/
/// `collectedThisMonth` from [DashboardData]), same tone colors from
/// [CottageSurface], just laid out as a single-column list of rows per the
/// Rento Figma kit's mobile home screen.
import 'utility_breakdown_sheet.dart';
import 'package:cottage/models/profile.dart';

class UtilityExpenseList extends StatelessWidget {
  final DashboardData data;
  final Profile profile;
  const UtilityExpenseList({super.key, required this.data, required this.profile});

  String _tk(double value) => '${value.toStringAsFixed(2)} tk';

  @override
  Widget build(BuildContext context) {
    final rows = [
      _Row(
        icon: Icons.account_balance_wallet_outlined,
        bg: const Color(0xFFFDE8E3),
        fg: const Color(0xFFD46243),
        label: 'Cottage Balance',
        value: _tk(data.cottageBalance),
        onTap: () => showUtilityBreakdownSheet(context, profile: profile, data: data),
      ),
      _Row(
        icon: Icons.receipt_long_outlined,
        bg: const Color(0xFFFEF3E2),
        fg: const Color(0xFFD59C24),
        label: 'Total Utility Expense',
        value: _tk(data.totalUtilityExpense),
        onTap: () => showUtilityBreakdownSheet(context, profile: profile, data: data),
      ),
      _Row(
        icon: Icons.price_check_outlined,
        bg: const Color(0xFFFDE6E7),
        fg: const Color(0xFFD85566),
        label: 'Outstanding From Members',
        value: _tk(data.outstandingFromMembers),
        onTap: () => showUtilityBreakdownSheet(context, profile: profile, data: data),
      ),
      _Row(
        icon: Icons.money_outlined,
        bg: const Color(0xFFEAF5E9),
        fg: const Color(0xFF75B974),
        label: 'Collected This Month',
        value: _tk(data.collectedThisMonth),
        onTap: () => showUtilityBreakdownSheet(context, profile: profile, data: data),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cottage Utility Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1E1E1E))),
        const SizedBox(height: 16),
        for (int i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: fg, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
