import 'package:flutter/material.dart';
import '../data/dashboard_data.dart';
import '../data/dashboard_service.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import '../../bazaar_duty/presentation/bazaar_duty_roster.dart';
import 'dashboard_header.dart';
import 'dashboard_summary_card.dart';
import 'member_meal_summary_list.dart';
import 'pin_notice_card.dart';
import 'utility_expense_list.dart';

/// Rento Figma-kit-styled Dashboard/home screen: an orange header band
/// (nav row + centered greeting) bleeding behind a large floating white
/// "your meal" + "your utility" summary card, then Pin Notice, Bazaar Duty
/// Roster, and Utility Expense sections. Presentation-only redesign --
/// still driven by [DashboardService]/[DashboardData], [BazaarDutyRoster]'s
/// own data flow, and (via [PinNoticeCard]) the same notice fetch/filter
/// pipeline as the notices tab. Mirrors
/// src/app/(house)/dashboard/page.tsx + MobileDashboardHero.tsx. The "just
/// posted" notice popup is deferred to a later phase.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final _service = DashboardService();
  late Future<(Profile, DashboardData)> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A request in flight when the OS suspends the app (e.g. phone sleeps
    // overnight) has its socket killed without ever completing or erroring
    // -- the awaiting Future just hangs forever, leaving the screen stuck
    // on its loading spinner. Reloading on resume recovers from that;
    // combined with _load()'s timeout below, the screen can't get stuck
    // for longer than one foreground/background cycle.
    if (state == AppLifecycleState.resumed) _retry();
  }

  Future<(Profile, DashboardData)> _load() async {
    final profile = await _service.getCurrentProfile().timeout(
      const Duration(seconds: 15),
    );
    final data = await _service
        .load(profile)
        .timeout(const Duration(seconds: 15));
    return (profile, data);
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The header band + overlapping card need to run edge-to-edge and
      // control their own top spacing, so the body opts out of AppScaffold's
      // default content padding instead of the ListView carrying it.
      body: FutureBuilder<(Profile, DashboardData)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                      'Could not load the dashboard.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final (profile, data) = snapshot.data!;
          final padding = context.responsivePadding;

          return RefreshIndicator(
            onRefresh: () async => _retry(),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  backgroundColor: CottageColors.primary,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 74,
                  titleSpacing: 0,
                  title: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: DashboardNavRow(profile: profile),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      DashboardGreeting(
                        profile: profile,
                        cottageName: data.cottageName,
                        monthKey: data.monthKey,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: padding),
                        child: DashboardSummaryCard(
                          profile: profile,
                          data: data,
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      PinNoticeCard(profile: profile),
                      const SizedBox(height: 24),
                      _BazaarDutySection(data: data, profile: profile),
                      const SizedBox(height: 24),
                      UtilityExpenseList(data: data, profile: profile),
                      const SizedBox(height: 24),
                      MemberMealSummaryList(
                        rows: data.memberMealRows,
                        bazaarDuties: data.bazaarDuties,
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "Bazaar Duty Roster" section title + icon-in-rounded-square per the
/// spec, wrapping the existing [BazaarDutyRoster] widget/data flow as-is --
/// its current card styling (title + avatar rows + green "On duty" pill)
/// already matches the target design closely enough that only the outer
/// section heading needed to move here from inside the card.
class _BazaarDutySection extends StatelessWidget {
  final DashboardData data;
  final Profile profile;

  const _BazaarDutySection({required this.data, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (data.bazaarDuties.isEmpty) return const SizedBox.shrink();
    return BazaarDutyRoster(
      duties: data.bazaarDuties,
      membersById: data.membersById,
      currentUserId: profile.id,
    );
  }
}
