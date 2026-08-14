import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/app_toast.dart';
import '../data/cottage_profile_service.dart';

/// "Cottage Profile" -- Figma node 212:1770: a house-icon avatar over three
/// info rows (Cottage Name / Created / Members). Open to every member as a
/// read-only view; only a super admin sees the rename pencil on Cottage
/// Name (the `update_cottage_name` RPC also enforces this server-side, see
/// supabase/migrations/0053, so hiding the pencil here is a UX nicety, not
/// the actual security boundary). Page shell copies
/// _DynamicDefaultCostHeaderDelegate's collapsing-title mechanics.
class CottageProfileScreen extends StatefulWidget {
  final Profile viewer;
  const CottageProfileScreen({super.key, required this.viewer});

  @override
  State<CottageProfileScreen> createState() => _CottageProfileScreenState();
}

class _CottageProfileScreenState extends State<CottageProfileScreen> {
  final _service = CottageProfileService();
  late Future<CottageProfile> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getCottageProfile(widget.viewer.cottageId);
  }

  void _refresh() => setState(() {
    _future = _service.getCottageProfile(widget.viewer.cottageId);
  });

  Future<void> _editName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final surface = ctx.surface;
        return AlertDialog(
          backgroundColor: surface.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Rename Cottage', style: TextStyle(color: surface.foreground)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: surface.foreground),
            decoration: InputDecoration(
              hintText: 'Cottage name',
              filled: true,
              fillColor: surface.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: surface.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: surface.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: CottageColors.primary, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: surface.mutedForeground)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save', style: TextStyle(color: CottageColors.primary)),
            ),
          ],
        );
      },
    );
    if (newName == null || newName.isEmpty || newName == currentName) return;
    try {
      await _service.updateCottageName(newName);
      if (!mounted) return;
      showAppToast(context, title: 'Cottage renamed.', type: ToastType.success);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, title: 'Could not rename cottage. Try again.', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;

    return Scaffold(
      backgroundColor: const Color(0xFFDE7356),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverPersistentHeader(
              pinned: true,
              delegate: _DynamicCottageProfileHeaderDelegate(
                surface: surface,
                safeAreaTop: MediaQuery.of(context).padding.top,
              ),
            ),
          ];
        },
        body: Container(
          color: surface.card,
          child: FutureBuilder<CottageProfile>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Failed to load.\n${snapshot.error}'));
              }
              final cottage = snapshot.data!;
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDE7356).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.house,
                          size: 28,
                          color: Color(0xFFDE7356),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: LucideIcons.house,
                      label: 'Cottage Name',
                      value: cottage.name,
                      trailing: widget.viewer.isSuperAdmin
                          ? GestureDetector(
                              onTap: () => _editName(cottage.name),
                              child: const Icon(
                                LucideIcons.pencil,
                                size: 15,
                                color: Color(0xFFDE7356),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: LucideIcons.calendarDays,
                      label: 'Created',
                      value: _formatCreatedDate(cottage.createdAt),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: LucideIcons.users,
                      label: 'Members',
                      value:
                          '${cottage.memberCount} member${cottage.memberCount == 1 ? '' : 's'}',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

const _kMonthAbbrs = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "12 Jan, 2026" -- matches the Figma copy exactly.
String _formatCreatedDate(DateTime date) {
  return '${date.day} ${_kMonthAbbrs[date.month - 1]}, ${date.year}';
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface.background,
        border: Border.all(color: context.surface.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.surface.mutedForeground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: context.surface.mutedForeground),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.surface.foreground,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _DynamicCottageProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final double safeAreaTop;

  _DynamicCottageProfileHeaderDelegate({
    required this.surface,
    required this.safeAreaTop,
  });

  @override
  double get minExtent => safeAreaTop + 56.0;

  @override
  double get maxExtent => safeAreaTop + 88.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height:
              safeAreaTop + 56 - (shrinkOffset * 1.5).clamp(0, safeAreaTop + 56),
          child: const ColoredBox(color: Color(0xFFDE7356)),
        ),
        Positioned(
          top: (safeAreaTop + 56) * (1 - progress),
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: surface.card,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20 * (1 - progress)),
                topRight: Radius.circular(20 * (1 - progress)),
              ),
            ),
          ),
        ),
        Positioned(
          top: safeAreaTop,
          left: 4,
          right: 16,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back,
                  color: Color.lerp(Colors.white, surface.foreground, progress),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Cottage Profile',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color.lerp(Colors.white, surface.foreground, progress),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DynamicCottageProfileHeaderDelegate oldDelegate) {
    return true;
  }
}
