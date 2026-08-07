import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/helpers/format_month.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import '../../../main.dart';
import '../../notifications/presentation/notification_bell.dart';
import 'verified_badge.dart';

/// The orange band across the top of the Dashboard, styled after the Rento
/// Figma kit's mobile home-screen header: a nav row (logo, decorative
/// language pill, theme toggle, notification bell, avatar) over a centered
/// greeting. Bleeds behind the top half of [DashboardSummaryCard], which
/// overlaps its bottom edge with a negative top margin from the caller.
///
/// The greeting copy/logic ("Welcome, {name}" + cottage name + "Here's
/// where things stand for {month}") mirrors the existing header text this
/// screen already rendered above the stat cards, and the web app's
/// src/app/(house)/dashboard/MobileDashboardHero.tsx -- just restyled to sit
/// centered inside the band instead of as a separate section above it.
class DashboardGreeting extends StatelessWidget {
  final Profile profile;
  final String cottageName;
  final String monthKey;

  const DashboardGreeting({
    super.key,
    required this.profile,
    required this.cottageName,
    required this.monthKey,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: -224, // Extends into the middle of the DashboardSummaryCard
          child: Container(
            decoration: const BoxDecoration(
              color: CottageColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome, ${profile.displayName}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: CottageColors.primaryForeground,
                    ),
                  ),
                  const SizedBox(width: 6),
                  VerifiedBadge(isSuperAdmin: profile.isSuperAdmin, defaultColor: CottageColors.primaryForeground),
                ],
              ),
              if (cottageName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  cottageName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: CottageColors.primaryForeground,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: CottageColors.primaryForeground),
                  children: [
                    const TextSpan(text: "Here's where things stand for "),
                    TextSpan(
                      text: formatMonthKey(monthKey),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DashboardNavRow extends StatefulWidget {
  final Profile profile;
  const DashboardNavRow({super.key, required this.profile});

  @override
  State<DashboardNavRow> createState() => _DashboardNavRowState();
}

class _DashboardNavRowState extends State<DashboardNavRow> {
  String _selectedLang = 'EN';

  void _showLanguagePicker() {
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
            Text(
              'Select Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.language, color: CottageColors.primary),
              title: const Text('English (EN)'),
              trailing: _selectedLang == 'EN'
                  ? const Icon(Icons.check_circle, color: CottageColors.primary)
                  : null,
              onTap: () {
                setState(() => _selectedLang = 'EN');
                Navigator.pop(ctx);
                showToast(context, 'Language set to English');
              },
            ),
            ListTile(
              leading: const Icon(Icons.language, color: CottageColors.primary),
              title: const Text('Bengali (BN)'),
              trailing: _selectedLang == 'BN'
                  ? const Icon(Icons.check_circle, color: CottageColors.primary)
                  : null,
              onTap: () {
                setState(() => _selectedLang = 'BN');
                Navigator.pop(ctx);
                showToast(context, 'Language set to Bengali');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleTheme() {
    final current = themeModeNotifier.value;
    final isDark = current == ThemeMode.dark ||
        (current == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    themeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    showToast(
      context,
      isDark ? 'Switched to Light Theme' : 'Switched to Dark Theme',
      duration: const Duration(seconds: 1),
    );
  }

  void _openProfile() {
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: CottageColors.primary,
                  backgroundImage: widget.profile.avatarUrl != null &&
                          widget.profile.avatarUrl!.isNotEmpty
                      ? NetworkImage(widget.profile.avatarUrl!)
                      : null,
                  child: widget.profile.avatarUrl == null ||
                          widget.profile.avatarUrl!.isEmpty
                      ? Text(
                          widget.profile.firstName.isNotEmpty
                              ? widget.profile.firstName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile.displayName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.profile.isSuperAdmin ? 'Super Admin' : 'Cottage Member',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Full Name'),
              subtitle: Text('${widget.profile.firstName} ${widget.profile.lastName}'),
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Role'),
              subtitle: Text(widget.profile.isSuperAdmin ? 'Super Admin' : 'Member'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.profile.firstName.isNotEmpty
        ? widget.profile.firstName[0].toUpperCase()
        : '?';

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark);

        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Image.asset('assets/images/TopLogo.png', fit: BoxFit.contain),
              ),
            ),
            const Spacer(),
            _Pill(
              onTap: _showLanguagePicker,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language, size: 20, color: context.surface.foreground),
                  const SizedBox(width: 4),
                  Text(
                    _selectedLang,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.surface.foreground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(width: 10),
            _IconPill(
              onTap: _toggleTheme,
              icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              iconColor: context.surface.foreground,
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
              ),
              alignment: Alignment.center,
              child: Theme(
                data: Theme.of(context).copyWith(
                  iconTheme: IconThemeData(color: context.surface.foreground),
                ),
                child: const NotificationBell(bareIcon: true),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _openProfile,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
                ),
                child: CircleAvatar(
                radius: 19,
                backgroundColor: Colors.white,
                backgroundImage: widget.profile.avatarUrl != null &&
                        widget.profile.avatarUrl!.isNotEmpty
                    ? NetworkImage(widget.profile.avatarUrl!)
                    : null,
                child: widget.profile.avatarUrl == null ||
                        widget.profile.avatarUrl!.isEmpty
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: CottageColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      )
                    : null,
              ),
            ),
            ),
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Pill({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
        ),
        child: child,
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  const _IconPill({required this.icon, this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
        ),
        child: Icon(icon, size: 22, color: iconColor ?? CottageColors.primary),
      ),
    );
  }
}
