import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cottage/models/profile.dart';
import 'package:cottage/constants/theme.dart';
import 'package:cottage/common_widgets/responsive_utils.dart';
import 'package:cottage/common_widgets/cottage_bottom_sheet.dart';
import 'package:cottage/common_widgets/empty_state.dart';
import 'package:cottage/common_widgets/password_confirm_dialog.dart';
import 'package:cottage/helpers/ui_helpers.dart';
import 'package:cottage/helpers/utility_categories.dart';
import '../../menu/data/member_service.dart';
import '../data/default_cost_models.dart';
import '../data/default_cost_service.dart';

/// Icon + tint per category -- mirrors CATEGORY_STYLE in
/// src/app/(house)/settings/rent/page.tsx.
class _CategoryStyle {
  final IconData icon;
  final Color tint;
  const _CategoryStyle(this.icon, this.tint);
}

const _kCategoryStyles = {
  'house_rent': _CategoryStyle(LucideIcons.house, Color(0xFF5B8DEF)),
  'electricity': _CategoryStyle(LucideIcons.zap, Color(0xFFFA9033)),
  'gas': _CategoryStyle(LucideIcons.flame, Color(0xFFFF4F4F)),
  'servant': _CategoryStyle(LucideIcons.userCheck, Color(0xFF63B64E)),
  'trash': _CategoryStyle(LucideIcons.trash, Color(0xFF8B909A)),
  'internet': _CategoryStyle(LucideIcons.wifi, Color(0xFF7192FF)),
  'filter_kit': _CategoryStyle(LucideIcons.filter, Color(0xFFA276D6)),
  'other': _CategoryStyle(LucideIcons.circleDollarSign, Color(0xFFDE7356)),
};

_CategoryStyle _styleFor(String category) =>
    _kCategoryStyles[category] ?? _kCategoryStyles['other']!;

/// "Default Cost" -- Figma node 217:1767: fixed per-member monthly amounts
/// (rent, and any other utility that's the same every month) that auto-fill
/// when generating a Utility Statement. Page shell copies
/// _DynamicMealHeaderDelegate's shrink-on-scroll mechanics (see
/// meal_screen.dart), same as ProfileScreen -- just a collapsing title, no
/// tab bar or bottom-pinned row (this page has neither, per Figma). Only
/// a super admin can manage this (mirrors requireSuperAdmin in
/// src/app/(house)/settings/rent/page.tsx and every default_costs RLS
/// write policy).
class DefaultCostScreen extends StatefulWidget {
  final Profile viewer;
  const DefaultCostScreen({super.key, required this.viewer});

  @override
  State<DefaultCostScreen> createState() => _DefaultCostScreenState();
}

class _DefaultCostData {
  final List<Profile> members;
  final List<DefaultCostCategory> categories;
  const _DefaultCostData({required this.members, required this.categories});
}

class _DefaultCostScreenState extends State<DefaultCostScreen> {
  final _service = DefaultCostService();
  final _memberService = MemberService();
  late Future<_DefaultCostData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DefaultCostData> _load() async {
    final members = await _memberService.getActiveMembers(
      widget.viewer.cottageId,
    );
    final categories = await _service.getDefaultCosts(widget.viewer.cottageId);
    return _DefaultCostData(members: members, categories: categories);
  }

  void _refresh() => setState(() {
    _future = _load();
  });

  Map<String, String> get _memberDisplayName => {
    for (final m in (_currentMembers ?? const <Profile>[])) m.id: m.displayName,
  };

  List<Profile>? _currentMembers;

  void _showSaveSheet(
    _DefaultCostData data, {
    String? editingCategory,
  }) {
    final availableCategories = utilityCategoryLabels.keys
        .where((k) => k != 'other')
        .toList();
    String category = editingCategory ?? availableCategories.first;
    final existing = editingCategory == null
        ? null
        : data.categories.firstWhere(
            (c) => c.category == editingCategory,
            orElse: () => DefaultCostCategory(category: editingCategory, rows: []),
          );
    final controllers = <String, TextEditingController>{
      for (final m in data.members)
        m.id: TextEditingController(
          text:
              existing?.rows
                  .where((r) => r.userId == m.id)
                  .map((r) => r.amount)
                  .firstOrNull
                  ?.toStringAsFixed(2) ??
              '',
        ),
    };

    showCottageSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => CottageSheetContent(
          title: editingCategory == null
              ? 'Add Default Cost'
              : 'Edit Default Cost',
          children: [
            Text(
              'Category',
              style: TextStyle(fontSize: 13, color: ctx.surface.mutedForeground),
            ),
            const SizedBox(height: 6),
            if (editingCategory != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: ctx.surface.background,
                  border: Border.all(color: ctx.surface.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  utilityCategoryLabel(category),
                  style: TextStyle(fontSize: 14, color: ctx.surface.foreground),
                ),
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  final picked = await showModalBottomSheet<String>(
                    context: ctx,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (sheetCtx) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final key in availableCategories)
                            ListTile(
                              title: Text(utilityCategoryLabels[key]!),
                              onTap: () => Navigator.pop(sheetCtx, key),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (picked != null) {
                    setSheetState(() => category = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: ctx.surface.background,
                    border: Border.all(color: ctx.surface.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          utilityCategoryLabel(category),
                          style: TextStyle(
                            fontSize: 14,
                            color: ctx.surface.foreground,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.expand_more,
                        color: ctx.surface.mutedForeground,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Split among members',
              style: TextStyle(fontSize: 13, color: ctx.surface.mutedForeground),
            ),
            const SizedBox(height: 8),
            for (final m in data.members) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        m.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          color: ctx.surface.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: controllers[m.id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          isDense: true,
                          filled: true,
                          fillColor: ctx.surface.background,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: ctx.surface.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: ctx.surface.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: CottageColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final amounts = <String, double>{
                  for (final e in controllers.entries)
                    e.key: double.tryParse(e.value.text.trim()) ?? 0,
                };
                if (amounts.values.every((v) => v <= 0)) {
                  showToast(ctx, 'Enter at least one member amount.');
                  return;
                }
                Navigator.pop(ctx);
                await _service.saveDefaultCost(
                  cottageId: widget.viewer.cottageId,
                  category: category,
                  setBy: widget.viewer.id,
                  amountsByUserId: amounts,
                );
                _refresh();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CottageColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'Save default cost',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String category) async {
    final confirmed = await showPasswordConfirmDialog(
      context,
      title: 'Delete this default cost?',
      message:
          'This removes ${utilityCategoryLabel(category)} for every member. Enter your password to confirm.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    await _service.deleteCategory(
      cottageId: widget.viewer.cottageId,
      category: category,
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;

    if (!widget.viewer.isSuperAdmin) {
      return Scaffold(
        backgroundColor: CottageColors.primary,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 15),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Default Cost',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: surface.card,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: const EmptyState(
                    icon: Icons.lock_outline,
                    title: 'Super admins only',
                    subtitle:
                        'Only a super admin can view or manage default costs.',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CottageColors.primary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverPersistentHeader(
              pinned: true,
              delegate: _DynamicDefaultCostHeaderDelegate(
                surface: surface,
                safeAreaTop: MediaQuery.of(context).padding.top,
              ),
            ),
          ];
        },
        body: Container(
          color: surface.card,
          child: FutureBuilder<_DefaultCostData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Failed to load.\n${snapshot.error}'),
                );
              }
              final data = snapshot.data!;
              _currentMembers = data.members;

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    context.responsivePadding,
                    0,
                    context.responsivePadding,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    Text(
                      'Fixed monthly costs that auto-fill each Utility Statement.',
                      style: TextStyle(
                        fontSize: 12,
                        color: surface.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _showSaveSheet(data),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: CottageColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Add Default Cost',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (data.categories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: EmptyState(
                          icon: Icons.savings_outlined,
                          title: 'No default costs set yet',
                          subtitle: 'Tap "Add Default Cost" to get started.',
                        ),
                      )
                    else
                      for (final c in data.categories) ...[
                        _CategoryCard(
                          category: c,
                          memberName: (userId) =>
                              _memberDisplayName[userId] ?? 'Former member',
                          onEdit: () => _showSaveSheet(
                            data,
                            editingCategory: c.category,
                          ),
                          onDelete: () => _confirmDelete(c.category),
                        ),
                        const SizedBox(height: 14),
                      ],
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

class _CategoryCard extends StatelessWidget {
  final DefaultCostCategory category;
  final String Function(String userId) memberName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.memberName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final style = _styleFor(category.category);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface.background,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.tint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(style.icon, size: 16, color: style.tint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  utilityCategoryLabel(category.category),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: surface.foreground,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: surface.mutedForeground,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.delete_outline,
                  size: 15,
                  color: CottageColors.destructive,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: surface.border),
          const SizedBox(height: 10),
          for (final row in category.rows) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    memberName(row.userId),
                    style: TextStyle(
                      fontSize: 12,
                      color: surface.mutedForeground,
                    ),
                  ),
                  Text(
                    '${row.amount.toStringAsFixed(2)} tk',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: surface.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: surface.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: surface.foreground,
                  ),
                ),
                Text(
                  '${category.total.toStringAsFixed(2)} tk',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: surface.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicDefaultCostHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CottageSurface surface;
  final double safeAreaTop;

  _DynamicDefaultCostHeaderDelegate({
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
          child: Container(color: CottageColors.primary),
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
                'Default Cost',
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
  bool shouldRebuild(covariant _DynamicDefaultCostHeaderDelegate oldDelegate) {
    return true;
  }
}
