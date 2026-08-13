import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/bazaar_duty_models.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

// Sunday-first, matching the Figma week strip ("S M T W T F S").
const _weekdayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

String _daySuffix(int day) {
  if (day % 10 == 1 && day != 11) return 'st';
  if (day % 10 == 2 && day != 12) return 'nd';
  if (day % 10 == 3 && day != 13) return 'rd';
  return 'th';
}

String _formatDate(String iso) {
  try {
    final parts = iso.split('-');
    if (parts.length < 3) return iso;
    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    if (month < 1 || month > 12) return iso;
    return '$day${_daySuffix(day)} ${_months[month - 1]}, $year';
  } catch (_) {
    return iso;
  }
}

enum _RowStatus { onGoing, complete, next }

_RowStatus _rowStatus(BazaarDuty duty) {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  if (duty.startDate.compareTo(today) <= 0 && today.compareTo(duty.endDate) <= 0) {
    return _RowStatus.onGoing;
  }
  if (duty.endDate.compareTo(today) < 0) return _RowStatus.complete;
  return _RowStatus.next;
}

class _RowColors {
  final Color background;
  final Color avatarBackground;
  final Color statusColor;
  const _RowColors({
    required this.background,
    required this.avatarBackground,
    required this.statusColor,
  });
}

const _purple = _RowColors(
  background: Color(0xFFF9F3FF),
  avatarBackground: Color(0xFF7035BA),
  statusColor: Color(0xFF63B64E),
);
const _blue = _RowColors(
  background: Color(0xFFEEF2FF),
  avatarBackground: Color(0xFF7192FF),
  statusColor: Color(0xFF63B64E),
);
const _green = _RowColors(
  background: Color(0xFFE5FFDF),
  avatarBackground: Color(0xFF63B64E),
  statusColor: Color(0xFF63B64E),
);
const _orange = _RowColors(
  background: Color(0xFFFFF3EF),
  avatarBackground: Color(0xFFF3C5BB),
  statusColor: Color(0xFFFFAB99),
);

/// Every member's upcoming/current bazaar duty, one shared roster instead of
/// each member only seeing their own. Pixel-matches the Figma "Bazaar Duty"
/// card (node 177:1655): tinted pill rows for completed/upcoming duty, and
/// an expanded pill with a mini week-calendar strip for whoever is on duty
/// right now. Mirrors BazaarDutyRoster in
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

    final rows = <Widget>[];
    var completeIndex = 0;
    for (final duty in sortedDuties) {
      final status = _rowStatus(duty);
      final member = membersById[duty.userId];
      final isMe = duty.userId == currentUserId;

      if (status == _RowStatus.onGoing) {
        rows.add(_OnGoingCard(duty: duty, member: member, isMe: isMe, colors: _green));
        continue;
      }

      final colors = status == _RowStatus.complete
          ? (completeIndex.isEven ? _purple : _blue)
          : _orange;
      if (status == _RowStatus.complete) completeIndex++;
      final label = status == _RowStatus.complete ? 'Complete' : 'Next';
      rows.add(
        _DutyPillRow(duty: duty, member: member, isMe: isMe, colors: colors, statusLabel: label),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C202B).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bazar Duty Roster',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
              ),
              Text(
                'Edit',
                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF7238BD)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

/// Shared avatar/name/status/date-range block used by both the pill rows and
/// the expanded on-going card.
class _DutyInfo extends StatelessWidget {
  final BazaarDuty duty;
  final Profile? member;
  final bool isMe;
  final String statusLabel;
  final Color statusColor;

  const _DutyInfo({
    required this.duty,
    required this.member,
    required this.isMe,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final name = member?.displayName ?? 'Member';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(you)',
                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF909090)),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Text(
              statusLabel,
              style: GoogleFonts.outfit(fontSize: 13, color: statusColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF909090)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${_formatDate(duty.startDate)}  -  ${_formatDate(duty.endDate)}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF909090)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DutyPillRow extends StatelessWidget {
  final BazaarDuty duty;
  final Profile? member;
  final bool isMe;
  final _RowColors colors;
  final String statusLabel;

  const _DutyPillRow({
    required this.duty,
    required this.member,
    required this.isMe,
    required this.colors,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDutyDetails(
        context,
        duty: duty,
        member: member,
        isMe: isMe,
        statusLabel: statusLabel,
        statusColor: colors.statusColor,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: 10, right: 24, top: 12, bottom: 12),
        decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(100)),
        child: Row(
          children: [
            _Avatar(member: member, background: colors.avatarBackground),
            const SizedBox(width: 16),
            Expanded(
              child: _DutyInfo(
                duty: duty,
                member: member,
                isMe: isMe,
                statusLabel: statusLabel,
                statusColor: colors.statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnGoingCard extends StatelessWidget {
  final BazaarDuty duty;
  final Profile? member;
  final bool isMe;
  final _RowColors colors;

  const _OnGoingCard({
    required this.duty,
    required this.member,
    required this.isMe,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDutyDetails(
        context,
        duty: duty,
        member: member,
        isMe: isMe,
        statusLabel: 'On Going',
        statusColor: colors.statusColor,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(25)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(member: member, background: colors.avatarBackground),
                const SizedBox(width: 16),
                Expanded(
                  child: _DutyInfo(
                    duty: duty,
                    member: member,
                    isMe: isMe,
                    statusLabel: 'On Going',
                    statusColor: colors.statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _WeekStrip(startDate: duty.startDate, endDate: duty.endDate),
          ],
        ),
      ),
    );
  }
}

/// Mini Sunday-first week calendar for the member currently on duty --
/// filled green circles mark the duty's actual days within that calendar
/// week, matching the Figma spec's "S M T W T F S" strip.
class _WeekStrip extends StatelessWidget {
  final String startDate;
  final String endDate;

  const _WeekStrip({required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final daysSinceSunday = start.weekday % 7; // Mon=1..Sun=7 -> Sun=0
    final weekStart = start.subtract(Duration(days: daysSinceSunday));
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    bool isFilled(DateTime d) => !d.isBefore(start) && !d.isAfter(end);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < weekDays.length; i++)
              Text(
                _weekdayLetters[i],
                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFAA84B7)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final d in weekDays)
              isFilled(d)
                  ? Container(
                      width: 37,
                      height: 37,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF63B64E),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 5, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        '${d.day}',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    )
                  : SizedBox(
                      width: 37,
                      height: 37,
                      child: Center(
                        child: Text(
                          '${d.day}',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF414141)),
                        ),
                      ),
                    ),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final Profile? member;
  final Color background;

  const _Avatar({required this.member, required this.background});

  @override
  Widget build(BuildContext context) {
    final initial = (member?.firstName.isNotEmpty ?? false) ? member!.firstName[0].toUpperCase() : '?';
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Center(
        child: ClipOval(
          child: SizedBox(
            width: 34,
            height: 34,
            child: member?.avatarUrl != null && member!.avatarUrl!.isNotEmpty
                ? Image.network(
                    member!.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _AvatarInitial(initial: initial),
                  )
                : _AvatarInitial(initial: initial),
          ),
        ),
      ),
    );
  }
}

void _showDutyDetails(
  BuildContext context, {
  required BazaarDuty duty,
  required Profile? member,
  required bool isMe,
  required String statusLabel,
  required Color statusColor,
}) {
  final surface = context.surface;
  final name = member?.displayName ?? 'Member';
  final initial = (member?.firstName.isNotEmpty ?? false) ? member!.firstName[0].toUpperCase() : '?';

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
              _StatusBadge(text: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: surface.accent,
              backgroundImage: member?.avatarUrl != null && member!.avatarUrl!.isNotEmpty
                  ? NetworkImage(member.avatarUrl!)
                  : null,
              child: member?.avatarUrl == null || member!.avatarUrl!.isEmpty
                  ? Text(initial, style: const TextStyle(fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(name + (isMe ? ' (You)' : ''), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Status: $statusLabel'),
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

class _AvatarInitial extends StatelessWidget {
  final String initial;
  const _AvatarInitial({required this.initial});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    return Container(
      color: surface.accent,
      alignment: Alignment.center,
      child: Text(initial, style: TextStyle(color: surface.accentForeground, fontWeight: FontWeight.w600, fontSize: 14)),
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
