import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/bazaar_duty_models.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import '../../menu/presentation/members_screen.dart';

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

/// A row's tint pair -- a light background that stays legible under
/// [statusColor]/dark body text in light mode, and a low-alpha version of
/// the same accent over the card in dark mode (mirrors [CottageSurface]'s
/// own light/dark tone-pair pattern in theme.dart, just for the extra
/// purple/blue/peach hues this roster needs that theme.dart doesn't model).
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

_RowColors _purple(bool dark) => _RowColors(
      background: dark ? const Color(0x337035BA) : const Color(0xFFF9F3FF),
      avatarBackground: const Color(0xFF7035BA),
      statusColor: const Color(0xFF63B64E),
    );
_RowColors _blue(bool dark) => _RowColors(
      background: dark ? const Color(0x337192FF) : const Color(0xFFEEF2FF),
      avatarBackground: const Color(0xFF7192FF),
      statusColor: const Color(0xFF63B64E),
    );
_RowColors _green(bool dark) => _RowColors(
      background: dark ? const Color(0x3363B64E) : const Color(0xFFE5FFDF),
      avatarBackground: const Color(0xFF63B64E),
      statusColor: const Color(0xFF63B64E),
    );
_RowColors _orange(bool dark) => _RowColors(
      background: dark ? const Color(0x33FFAB99) : const Color(0xFFFFF3EF),
      avatarBackground: const Color(0xFFF3C5BB),
      statusColor: const Color(0xFFFFAB99),
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
  final String cottageId;

  /// Only a super admin can reassign bazaar duties (from the Members
  /// screen), so the "Edit" link is only shown for them -- an ordinary
  /// member tapping it would just land on a screen with nothing they're
  /// allowed to do.
  final bool isSuperAdmin;

  const BazaarDutyRoster({
    super.key,
    required this.duties,
    required this.membersById,
    required this.currentUserId,
    required this.cottageId,
    required this.isSuperAdmin,
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

    final surface = context.surface;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final sortedDuties = _oncePerMember(duties)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final rows = <Widget>[];
    var completeIndex = 0;
    for (final duty in sortedDuties) {
      final status = _rowStatus(duty);
      final member = membersById[duty.userId];
      final isMe = duty.userId == currentUserId;

      if (status == _RowStatus.onGoing) {
        rows.add(_OnGoingCard(duty: duty, member: member, isMe: isMe, colors: _green(dark)));
        continue;
      }

      final colors = status == _RowStatus.complete
          ? (completeIndex.isEven ? _purple(dark) : _blue(dark))
          : _orange(dark);
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
        color: surface.card,
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
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: surface.foreground),
              ),
              if (isSuperAdmin)
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MembersScreen(cottageId: cottageId),
                    ),
                  ),
                  child: Text(
                    'Edit',
                    style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF7238BD)),
                  ),
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

/// Shared padding for every roster row's container -- kept identical across
/// [_DutyPillRow] and [_OnGoingCard] so their status labels (both pushed
/// flush right by a `Spacer()` in [_DutyInfo]) land on the exact same right
/// edge instead of drifting depending on which row shape it is.
const _rowPadding = EdgeInsets.only(left: 10, right: 24, top: 12, bottom: 12);

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
    final surface = context.surface;
    final name = member?.displayName ?? 'Member';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: surface.foreground),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(you)',
                      style: GoogleFonts.outfit(fontSize: 12, color: surface.mutedForeground),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              statusLabel,
              style: GoogleFonts.outfit(fontSize: 13, color: statusColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 12, color: surface.mutedForeground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${_formatDate(duty.startDate)}  -  ${_formatDate(duty.endDate)}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 12, color: surface.mutedForeground),
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
        padding: _rowPadding,
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
        padding: _rowPadding,
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
            _DutyDayStrip(startDate: duty.startDate, endDate: duty.endDate),
          ],
        ),
      ),
    );
  }
}

/// Every day of the duty's own assigned range (start through end inclusive)
/// -- not just whichever single calendar week the start date happens to
/// fall in, since a duty can span a week boundary (e.g. Thu through the
/// following Tue). Wraps onto a second line if the range is long. Days that
/// have already happened (today included) are filled solid green; days
/// still ahead show as an outlined circle so "assigned but not yet done" is
/// visually distinct from "done".
class _DutyDayStrip extends StatelessWidget {
  final String startDate;
  final String endDate;

  const _DutyDayStrip({required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final d in days) _DayCell(date: d, done: !d.isAfter(today), surface: surface),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool done;
  final CottageSurface surface;

  const _DayCell({required this.date, required this.done, required this.surface});

  @override
  Widget build(BuildContext context) {
    final letter = _weekdayLetters[date.weekday % 7];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(letter, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFFAA84B7))),
        const SizedBox(height: 6),
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? const Color(0xFF63B64E) : Colors.transparent,
            shape: BoxShape.circle,
            border: done ? null : Border.all(color: surface.border),
            boxShadow: done
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 5, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            '${date.day}',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: done ? Colors.white : surface.foreground,
            ),
          ),
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
        border: Border.all(color: context.surface.card, width: 3),
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
    backgroundColor: surface.card,
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
            title: Text(
              name + (isMe ? ' (You)' : ''),
              style: TextStyle(fontWeight: FontWeight.bold, color: surface.foreground),
            ),
            subtitle: Text('Status: $statusLabel', style: TextStyle(color: surface.mutedForeground)),
          ),
          Divider(color: surface.border),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Start Date:', style: TextStyle(color: surface.mutedForeground)),
              Text(_formatDate(duty.startDate), style: TextStyle(fontWeight: FontWeight.w600, color: surface.foreground)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('End Date:', style: TextStyle(color: surface.mutedForeground)),
              Text(_formatDate(duty.endDate), style: TextStyle(fontWeight: FontWeight.w600, color: surface.foreground)),
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
