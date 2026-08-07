import 'package:flutter/material.dart';
import 'package:cottage/constants/theme.dart';
import '../data/dashboard_data.dart';
import '../../bazaar_duty/data/bazaar_duty_models.dart';

/// "Member Meal Summary" section added to the Figma spec's second revision:
/// one bordered card per member (avatar/name header, then a Total Meal /
/// Deposit / Meal Cost / Balance 2x2 stat grid) instead of the grid of
/// small `_MemberMealCard`s this screen used to render. Same
/// [MemberMealRow] data (see `getMemberMealSummary` in
/// src/lib/data/meal.ts), just restyled.
class MemberMealSummaryList extends StatelessWidget {
  final List<MemberMealRow> rows;
  final List<BazaarDuty> bazaarDuties;
  const MemberMealSummaryList({super.key, required this.rows, required this.bazaarDuties});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Member Meal Summary',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1E1E1E)),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < rows.length; i++) ...[
          _MemberCard(row: rows[i], bazaarDuties: bazaarDuties),
          if (i < rows.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final MemberMealRow row;
  final List<BazaarDuty> bazaarDuties;
  const _MemberCard({required this.row, required this.bazaarDuties});

  String _tk(double v) => '${v.toStringAsFixed(2)} tk';
  String _count(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1).padLeft(2, '0');

  String _formatDate(String iso) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    try {
      final parts = iso.split('-');
      if (parts.length < 3) return iso;
      final month = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      if (month < 1 || month > 12) return iso;
      
      String suffix = 'th';
      if (day % 10 == 1 && day != 11) {
        suffix = 'st';
      } else if (day % 10 == 2 && day != 12) {
        suffix = 'nd';
      } else if (day % 10 == 3 && day != 13) {
        suffix = 'rd';
      }
      
      return '$day$suffix ${months[month - 1]}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final balancePositive = row.balance >= 0;
    final initial = row.firstName.isNotEmpty ? row.firstName[0].toUpperCase() : '?';

    final myDuties = bazaarDuties.where((d) => d.userId == row.id).toList();
    BazaarDuty? activeOrNextDuty;
    if (myDuties.isNotEmpty) {
      myDuties.sort((a, b) => a.startDate.compareTo(b.startDate));
      activeOrNextDuty = myDuties.firstWhere(
        (d) => bazaarDutyStatus(d.startDate, d.endDate) == BazaarDutyStatus.active,
        orElse: () => myDuties.first,
      );
    }

    void showDetails(BuildContext context) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: row.avatarUrl != null && row.avatarUrl!.isNotEmpty
                          ? Image.network(
                              row.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _Initial(initial: initial),
                            )
                          : _Initial(initial: initial),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.displayName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: surface.foreground),
                      ),
                      Text('Meal Summary Breakdown', style: TextStyle(fontSize: 13, color: surface.mutedForeground)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Total Meals Taken'),
                trailing: Text(_count(row.meals), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Total Deposit Amount'),
                trailing: Text(_tk(row.deposit), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Total Calculated Cost'),
                trailing: Text(_tk(row.cost), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Net Meal Balance'),
                trailing: Text(
                  _tk(row.balance),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: balancePositive ? const Color(0xFF289029) : CottageColors.destructive,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => showDetails(context),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: row.avatarUrl != null && row.avatarUrl!.isNotEmpty
                        ? Image.network(
                            row.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _Initial(initial: initial),
                          )
                        : _Initial(initial: initial),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.displayName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                      ),
                      if (activeOrNextDuty != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_formatDate(activeOrNextDuty.startDate)} - ${_formatDate(activeOrNextDuty.endDate)} (Bazar Duty)',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _Stat(label: 'Total Meal', value: _count(row.meals), surface: surface)),
                Expanded(child: _Stat(label: 'Deposit', value: _tk(row.deposit), surface: surface)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _Stat(label: 'Meal Cost', value: _tk(row.cost), surface: surface)),
                Expanded(
                  child: _Stat(
                    label: 'Balance',
                    value: _tk(row.balance),
                    surface: surface,
                    valueColor: balancePositive ? const Color(0xFF289029) : const Color(0xFFFF0000),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final CottageSurface surface;
  final Color? valueColor;

  const _Stat({required this.label, required this.value, required this.surface, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor ?? const Color(0xFF374151))),
      ],
    );
  }
}

class _Initial extends StatelessWidget {
  final String initial;
  const _Initial({required this.initial});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Container(
      color: surface.accent,
      alignment: Alignment.center,
      child: Text(initial, style: TextStyle(color: surface.accentForeground, fontWeight: FontWeight.w600, fontSize: 18)),
    );
  }
}
