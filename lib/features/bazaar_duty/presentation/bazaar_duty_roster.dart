import 'package:flutter/material.dart';
import '../data/bazaar_duty_models.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _formatDate(String iso) {
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
    
    return '$day$suffix ${_months[month - 1]}';
  } catch (_) {
    return iso;
  }
}

/// Every member's upcoming/current bazaar duty, one shared roster instead of
/// each member only seeing their own -- a compact list of avatar rows.
/// Mirrors BazaarDutyRoster in
/// src/app/(house)/dashboard/BazaarDutyRoster.tsx.
class BazaarDutyRoster extends StatelessWidget {
  final List<BazaarDuty> duties;
  final Map<String, Profile> membersById;
  final String currentUserId;

  const BazaarDutyRoster({
    super.key,
    required this.duties,
    required this.membersById,
    required this.currentUserId,
  });

  /// One row per member instead of one per duty row -- [duties] holds every
  /// duty ever assigned (past, active, and upcoming), so a member with a
  /// long history would otherwise show up here once per past duty. Picks
  /// each member's current duty if they're on duty today, else their
  /// nearest upcoming one, else falls back to their most recent past one so
  /// they still appear somewhere in the shared roster.
  List<BazaarDuty> _oncePerMember(List<BazaarDuty> duties) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final byUser = <String, List<BazaarDuty>>{};
    for (final d in duties) {
      byUser.putIfAbsent(d.userId, () => []).add(d);
    }

    final result = <BazaarDuty>[];
    for (final userDuties in byUser.values) {
      userDuties.sort((a, b) => a.startDate.compareTo(b.startDate));
      final active = userDuties.where(
        (d) => d.startDate.compareTo(today) <= 0 && today.compareTo(d.endDate) <= 0,
      );
      if (active.isNotEmpty) {
        result.add(active.first);
        continue;
      }
      final upcoming = userDuties.where((d) => d.startDate.compareTo(today) > 0);
      if (upcoming.isNotEmpty) {
        result.add(upcoming.first);
        continue;
      }
      result.add(userDuties.last);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (duties.isEmpty) return const SizedBox.shrink();

    final sortedDuties = _oncePerMember(duties)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8E3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFC85A3F)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bazar Duty Roster',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1E1E1E)),
          ),
          const SizedBox(height: 20),
          for (final d in sortedDuties) _DutyRow(duty: d, member: membersById[d.userId], isMe: d.userId == currentUserId),
        ],
      ),
    );
  }
}

class _DutyRow extends StatelessWidget {
  final BazaarDuty duty;
  final Profile? member;
  final bool isMe;

  const _DutyRow({required this.duty, required this.member, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final status = bazaarDutyStatus(duty.startDate, duty.endDate);
    final name = member?.displayName ?? 'Member';
    final initial = (member?.firstName.isNotEmpty ?? false) ? member!.firstName[0].toUpperCase() : '?';
    // Highlight follows who's actually on duty right now (matches the
    // Figma spec's bg/border tint), not who's viewing the roster --
    // "(you)" is a separate, always-shown suffix when it applies.
    final highlighted = status == BazaarDutyStatus.active;

    void showDetails(BuildContext context) {
      final statusStr = status == BazaarDutyStatus.active
          ? 'On Duty'
          : status == BazaarDutyStatus.today
              ? 'Today'
              : status == BazaarDutyStatus.upcoming
                  ? 'Upcoming'
                  : 'Completed';

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
                  const Icon(Icons.shopping_basket_outlined, color: CottageColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Bazaar Duty Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: surface.foreground,
                    ),
                  ),
                  const Spacer(),
                  if (status == BazaarDutyStatus.active)
                    const _StatusBadge(text: 'On Duty', color: Color(0xFF289029)),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: surface.accent,
                  backgroundImage: member?.avatarUrl != null && member!.avatarUrl!.isNotEmpty
                      ? NetworkImage(member!.avatarUrl!)
                      : null,
                  child: member?.avatarUrl == null || member!.avatarUrl!.isEmpty
                      ? Text(initial, style: const TextStyle(fontWeight: FontWeight.bold))
                      : null,
                ),
                title: Text(name + (isMe ? ' (You)' : ''), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Status: $statusStr'),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Start Date:', style: TextStyle(color: Colors.grey)),
                  Text(_formatDate(duty.startDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('End Date:', style: TextStyle(color: Colors.grey)),
                  Text(_formatDate(duty.endDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              if (duty.note != null && duty.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Note:', style: TextStyle(fontWeight: FontWeight.bold, color: surface.foreground)),
                const SizedBox(height: 4),
                Text(duty.note!, style: TextStyle(color: surface.mutedForeground)),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => showDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFFFF7F5) : const Color(0xFFFAFAFA),
          border: Border.all(
            color: highlighted ? const Color(0xFFE47A5A) : const Color(0xFFEEEEEE),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 52,
                height: 52,
                child: member?.avatarUrl != null && member!.avatarUrl!.isNotEmpty
                    ? Image.network(
                        member!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _AvatarInitial(initial: initial),
                      )
                    : _AvatarInitial(initial: initial),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        const Text('(you)', style: TextStyle(fontSize: 16, color: Color(0xFF9CA3AF))),
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(duty.startDate)} – ${_formatDate(duty.endDate)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            if (status == BazaarDutyStatus.active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('On Duty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;
  const _AvatarInitial({required this.initial});

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

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
