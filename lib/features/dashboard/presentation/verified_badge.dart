import 'package:flutter/material.dart';

/// Small verified checkmark shown next to a member's name -- mirrors
/// src/components/verified-badge.tsx: gold for role == 'super_admin',
/// sky-blue for a member granted any manager-style permission (see
/// [Profile.hasElevatedAccess]), default color (black/foreground) otherwise.
class VerifiedBadge extends StatelessWidget {
  final bool isSuperAdmin;
  final bool hasElevatedAccess;
  final Color defaultColor;
  final double size;

  const VerifiedBadge({
    super.key,
    required this.isSuperAdmin,
    this.hasElevatedAccess = false,
    required this.defaultColor,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSuperAdmin
        ? const Color(0xFFF59E0B)
        : hasElevatedAccess
        ? const Color(0xFF0EA5E9)
        : defaultColor;
    return Icon(Icons.verified, size: size, color: color);
  }
}
