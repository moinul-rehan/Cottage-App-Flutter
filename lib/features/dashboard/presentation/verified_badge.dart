import 'package:flutter/material.dart';

/// Small verified checkmark shown next to the greeting name on the
/// Dashboard header -- mirrors src/components/verified-badge.tsx (gold for
/// role == 'super_admin', sky-blue for members granted any manager-style
/// permission, default color otherwise).
///
/// Simplification: the Flutter `Profile` model doesn't currently carry the
/// `can_add_expenses`/`can_add_bazaar`/`can_add_meals`/`can_add_deposit`/
/// `can_add_notice` columns the web app uses to compute "elevated access",
/// and wiring all five just for this badge would be disproportionate to a
/// presentation-only redesign. This falls back to role-only: gold for
/// `super_admin`, default (foreground) color for everyone else.
class VerifiedBadge extends StatelessWidget {
  final bool isSuperAdmin;
  final Color defaultColor;
  final double size;

  const VerifiedBadge({
    super.key,
    required this.isSuperAdmin,
    required this.defaultColor,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSuperAdmin ? const Color(0xFFF59E0B) : defaultColor;
    return Icon(Icons.verified, size: size, color: color);
  }
}
