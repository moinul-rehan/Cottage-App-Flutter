import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import '../data/dashboard_data.dart';
import 'utility_breakdown_sheet.dart';

MemberMealRow? _findMyMealRow(List<MemberMealRow> rows, String profileId) {
  for (final row in rows) {
    if (row.id == profileId) return row;
  }
  return null;
}

/// Large white floating card combining "your meal" and "your utility"
/// summaries -- mirrors src/app/(house)/dashboard/MobileDashboardHero.tsx's
/// `SummaryGroup` rows (meal cost/deposit/balance, then assigned
/// cost/paid/remaining due), restyled per the Rento Figma kit as bordered
/// pill rows instead of the web's borderless `bg-muted/40` rows.
class DashboardSummaryCard extends StatelessWidget {
  final Profile profile;
  final DashboardData data;

  const DashboardSummaryCard({super.key, required this.profile, required this.data});

  String _tk(double value) => '${value.toStringAsFixed(2)} tk';

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final myMeal = _findMyMealRow(data.memberMealRows, profile.id);
    final balancePositive = (myMeal?.balance ?? 0) >= 0;
    final due = data.myDue.due;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupLabel('YOUR MEAL'),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.restaurant_outlined,
            label: 'Meal Cost',
            value: _tk(myMeal?.cost ?? 0),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            icon: Icons.savings_outlined,
            label: 'Deposit',
            value: _tk(myMeal?.deposit ?? 0),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Balance',
            value: _tk(myMeal?.balance ?? 0),
            valueColor: balancePositive ? const Color(0xFF16A34A) : CottageColors.destructive,
          ),
          const SizedBox(height: 16),
          Divider(color: surface.border, height: 1),
          const SizedBox(height: 16),
          _GroupLabel('YOUR UTILITY'),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.receipt_long_outlined,
            label: 'Assign Cost',
            value: _tk(data.myAssignedCost),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            icon: Icons.payments_outlined,
            label: 'Paid',
            value: _tk(data.myDue.paid),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            icon: Icons.account_balance_wallet_outlined,
            label: due < 0 ? 'Advance Balance' : 'Remaining Due',
            value: _tk(due.abs()),
            valueColor: due > 0 ? CottageColors.destructive : const Color(0xFF16A34A),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => showUtilityBreakdownSheet(context, profile: profile, data: data),
              style: TextButton.styleFrom(
                foregroundColor: CottageColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Text('See details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              label: const Icon(Icons.arrow_forward, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.surface.mutedForeground),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: surface.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: CottageColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: surface.mutedForeground))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor ?? surface.foreground)),
        ],
      ),
    );
  }
}
