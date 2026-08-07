import 'package:flutter/material.dart';
import 'package:cottage/constants/theme.dart';

enum StatTone { blue, green, orange, red }

/// Mirrors the web app's StatCard component in
/// src/app/(house)/dashboard/page.tsx.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final StatTone tone;
  final bool paid;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
    this.tone = StatTone.blue,
    this.paid = false,
  });

  (Color bg, Color fg) _colors(CottageSurface surface) {
    switch (tone) {
      case StatTone.blue:
        return (surface.toneBlueBg, surface.toneBlueFg);
      case StatTone.green:
        return (surface.toneGreenBg, surface.toneGreenFg);
      case StatTone.orange:
        return (surface.toneOrangeBg, surface.toneOrangeFg);
      case StatTone.red:
        return (surface.toneRedBg, surface.toneRedFg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.surface;
    final (bg, fg) = _colors(surface);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 300;
        final iconSize = isNarrow ? 44.0 : 54.0;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(isNarrow ? 12 : 16),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: fg, size: isNarrow ? 20 : 24),
                ),
                SizedBox(width: isNarrow ? 10 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: isNarrow ? 12 : 13, color: surface.mutedForeground),
                            ),
                          ),
                          if (paid) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0x1A059669),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Paid',
                                style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: isNarrow ? 17 : 20, fontWeight: FontWeight.w600, color: surface.foreground),
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          hint!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: isNarrow ? 11 : 12, color: surface.mutedForeground),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
