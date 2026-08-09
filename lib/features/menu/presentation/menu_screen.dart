import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../data/member_service.dart';
import 'package:cottage/helpers/supabase_service.dart';
import 'package:cottage/helpers/navigation_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/app_scaffold.dart';
import 'package:cottage/common_widgets/confirm_modal.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import '../../auth/presentation/login_screen.dart';
import '../../contacts/presentation/contacts_screen.dart';
import '../../months/presentation/months_screen.dart';
import 'members_screen.dart';

/// Settings / profile screen — profile card, cottage info, navigation menu,
/// and sign-out.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  static final menuScreenKey = GlobalKey<_MenuScreenState>();

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _dashService = DashboardService();
  final _memberService = MemberService();
  late Future<_MenuData> _future;

  _MenuData? _currentData;

  void triggerAction(String action) {
    final data = _currentData;
    if (data == null) return;
    if (action == 'members') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MembersScreen(cottageId: data.profile.cottageId),
        ),
      );
    } else if (action == 'contacts') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ContactsScreen()),
      );
    } else if (action == 'months') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MonthsScreen()),
      );
    } else if (action == 'settings' || action == 'feedback') {
      showToast(
        context,
        '${action[0].toUpperCase()}${action.substring(1)} coming in a future update',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MenuData> _load() async {
    final profile = await _dashService.getCurrentProfile();
    final cottageName = await _memberService.getCottageName(profile.cottageId);
    final monthKey = await _dashService.getActiveMonthKey(profile.cottageId);
    return _MenuData(
      profile: profile,
      cottageName: cottageName,
      monthKey: monthKey,
    );
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmModal(
      context,
      icon: Icons.logout_rounded,
      title: 'Log out?',
      message: "You'll need to sign in again to access your Cottage.",
      confirmLabel: 'Log Out',
    );
    if (!confirmed) return;
    await SupabaseService.signOut();
    NavigationService.popToRoot();
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;

    return AppScaffold(
      title: 'Menu',
      showLogout: false,
      body: FutureBuilder<_MenuData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
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
                    'Failed to load.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          _currentData = data;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: surface.accent,
                        backgroundImage: data.profile.avatarUrl != null
                            ? NetworkImage(data.profile.avatarUrl!)
                            : null,
                        child: data.profile.avatarUrl == null
                            ? Text(
                                data.profile.firstName.isNotEmpty
                                    ? data.profile.firstName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: surface.accentForeground,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.profile.fullName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: surface.foreground,
                              ),
                            ),
                            if (data.profile.email != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                data.profile.email!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: surface.mutedForeground,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: surface.accent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                data.cottageName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: surface.accentForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: surface.toneBlueBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: surface.toneBlueFg,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Month',
                              style: TextStyle(
                                fontSize: 13,
                                color: surface.mutedForeground,
                              ),
                            ),
                            Text(
                              data.monthKey,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: surface.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              _MenuTile(
                icon: Icons.people_rounded,
                label: 'Members',
                surface: surface,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MembersScreen(cottageId: data.profile.cottageId),
                    ),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.history_rounded,
                label: 'History',
                surface: surface,
                onTap: () {
                  showToast(context, 'History coming in a future update');
                },
              ),
              _MenuTile(
                icon: Icons.contact_phone_rounded,
                label: 'Contacts',
                surface: surface,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactsScreen()),
                  );
                },
              ),
              _MenuTile(
                icon: Icons.settings_rounded,
                label: 'Settings',
                surface: surface,
                onTap: () {
                  showToast(context, 'Settings coming in a future update');
                },
              ),

              const SizedBox(height: 16),

              Card(
                child: InkWell(
                  onTap: _logout,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: surface.toneRedBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            color: surface.toneRedFg,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: CottageColors.destructive,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          color: surface.mutedForeground,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  'Cottage v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: surface.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _MenuData {
  final Profile profile;
  final String cottageName;
  final String monthKey;
  const _MenuData({
    required this.profile,
    required this.cottageName,
    required this.monthKey,
  });
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final CottageSurface surface;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.surface,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: surface.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: surface.accentForeground, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: surface.foreground,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: surface.mutedForeground,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
