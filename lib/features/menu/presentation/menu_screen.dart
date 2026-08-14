import 'package:flutter/material.dart';
import 'package:cottage/models/profile.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../data/member_service.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/app_scaffold.dart';
import '../../contacts/presentation/contacts_screen.dart';
import '../../months/presentation/months_screen.dart';
import 'members_screen.dart';
import 'feedback_screen.dart';
import 'settings_screen.dart';

/// Root of the bottom nav's "Menu" tab -- purely a data/navigation host, not
/// a page anyone actually sees: tapping this tab immediately pops open the
/// speed dial (Notice Board / Settings / Contact / Months / Members /
/// Feedback, see BottomNavShellState._handleTabTap), which is the only way
/// any of this screen's destinations get reached. This widget's own body is
/// never actually shown on screen: [BottomNavShellState.openTab] always
/// redirects the *visible* tab to Home (index 0) before calling
/// [triggerAction], specifically so backing out of Settings/Contacts/
/// Months/Members/Feedback reveals the Dashboard underneath, not a blank
/// page here -- this class exists purely to hold [_currentData] (fetched
/// once, silently) for [triggerAction] to hand off to whichever screen the
/// dial opens, kept alive offstage in the tab IndexedStack.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  static final menuScreenKey = GlobalKey<_MenuScreenState>();

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _dashService = DashboardService();
  final _memberService = MemberService();

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
    } else if (action == 'feedback') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeedbackScreen(profile: data.profile),
        ),
      );
    } else if (action == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SettingsScreen(
            profile: data.profile,
            cottageName: data.cottageName,
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Fire-and-forget: nothing in the UI awaits this, it just populates
  // _currentData for triggerAction by the time the speed dial is opened.
  Future<void> _load() async {
    try {
      final profile = await _dashService.getCurrentProfile();
      final cottageName = await _memberService.getCottageName(
        profile.cottageId,
      );
      final monthKey = await _dashService.getActiveMonthKey(
        profile.cottageId,
      );
      if (!mounted) return;
      _currentData = _MenuData(
        profile: profile,
        cottageName: cottageName,
        monthKey: monthKey,
      );
    } catch (_) {
      // Left null -- triggerAction no-ops until a retry (e.g. re-entering
      // this tab) succeeds. Nothing here is worth a visible error state for
      // a screen with no visible content of its own.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kept as AppScaffold (not a bare Container) purely so Sign Out --
    // AppScaffold's built-in logout button -- stays reachable; it's the
    // only place in the app that lives. The body itself has nothing in it.
    return AppScaffold(
      title: 'Menu',
      showLogout: true,
      body: Container(color: context.surface.background),
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
