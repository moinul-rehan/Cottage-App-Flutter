import 'package:flutter/material.dart';

/// Brand constants that stay fixed regardless of light/dark mode -- mirrors
/// the CSS custom properties in the web app's src/app/globals.css :root
/// block, so the native app reads as the same product. Buttons and other
/// "necessary" accented components always use [primary], in both themes.
class CottageColors {
  CottageColors._();

  static const primary = Color(0xFFDE7356);
  static const primaryForeground = Color(0xFFFFFFFF);
  static const destructive = Color(0xFFFF4F4F);
}

/// Everything that flips between light and dark -- surfaces, text, borders,
/// stat-card tone tints. Light values mirror globals.css's :root block;
/// dark values mirror the Figma RumahTara dark-mode variant's design
/// tokens (Background/Main-Backgroud #1e1e1e, Background/Secondary-Background
/// #292929, Text/Main-Text #f6f6f6, Text/Tertiary-Text #888888), with the
/// Figma dark button/accent grays swapped out for the Cottage brand color
/// per product direction (brand color drives buttons/active states only).
class CottageSurface extends ThemeExtension<CottageSurface> {
  final Color background;
  final Color card;
  final Color foreground;
  final Color mutedForeground;
  final Color border;
  final Color accent;
  final Color accentForeground;
  final Color secondary;
  final Color muted;
  final Color navBackground;
  final Color navInactive;
  final Color toneBlueBg;
  final Color toneBlueFg;
  final Color toneGreenBg;
  final Color toneGreenFg;
  final Color toneOrangeBg;
  final Color toneOrangeFg;
  final Color toneRedBg;
  final Color toneRedFg;

  const CottageSurface({
    required this.background,
    required this.card,
    required this.foreground,
    required this.mutedForeground,
    required this.border,
    required this.accent,
    required this.accentForeground,
    required this.secondary,
    required this.muted,
    required this.navBackground,
    required this.navInactive,
    required this.toneBlueBg,
    required this.toneBlueFg,
    required this.toneGreenBg,
    required this.toneGreenFg,
    required this.toneOrangeBg,
    required this.toneOrangeFg,
    required this.toneRedBg,
    required this.toneRedFg,
  });

  static const light = CottageSurface(
    background: Color(0xFFF4F4F6),
    card: Color(0xFFFFFFFF),
    foreground: Color(0xFF17191E),
    mutedForeground: Color(0xFF7A818D),
    border: Color(0xFFE4E5E8),
    accent: Color(0xFFFBEAE5),
    accentForeground: CottageColors.primary,
    secondary: Color(0xFFF4F4F6),
    muted: Color(0xFFE4E5E8),
    navBackground: Color(0xFF171717),
    navInactive: Color(0xFFA3A3A3),
    toneBlueBg: Color(0xFFFBEAE5),
    toneBlueFg: CottageColors.primary,
    toneGreenBg: Color(0x2663B64E),
    toneGreenFg: Color(0xFF63B64E),
    toneOrangeBg: Color(0x26FA9033),
    toneOrangeFg: Color(0xFFFA9033),
    toneRedBg: Color(0x26FF4F4F),
    toneRedFg: Color(0xFFFF4F4F),
  );

  static const dark = CottageSurface(
    background: Color(0xFF1E1E1E),
    card: Color(0xFF292929),
    foreground: Color(0xFFF6F6F6),
    mutedForeground: Color(0xFF888888),
    border: Color(0xFF3D3D3D),
    accent: Color(0x33DE7356),
    accentForeground: CottageColors.primary,
    secondary: Color(0xFF292929),
    muted: Color(0xFF3D3D3D),
    // Web's MobileBottomNav hardcodes `bg-neutral-900`/`text-neutral-400`
    // literally (not a CSS var), so the bar looks identical in light/dark.
    navBackground: Color(0xFF171717),
    navInactive: Color(0xFFA3A3A3),
    toneBlueBg: Color(0x33DE7356),
    toneBlueFg: CottageColors.primary,
    toneGreenBg: Color(0x3363B64E),
    toneGreenFg: Color(0xFF63B64E),
    toneOrangeBg: Color(0x33FA9033),
    toneOrangeFg: Color(0xFFFA9033),
    toneRedBg: Color(0x33FF4F4F),
    toneRedFg: Color(0xFFFF4F4F),
  );

  @override
  CottageSurface copyWith({
    Color? background,
    Color? card,
    Color? foreground,
    Color? mutedForeground,
    Color? border,
    Color? accent,
    Color? accentForeground,
    Color? secondary,
    Color? muted,
    Color? navBackground,
    Color? navInactive,
    Color? toneBlueBg,
    Color? toneBlueFg,
    Color? toneGreenBg,
    Color? toneGreenFg,
    Color? toneOrangeBg,
    Color? toneOrangeFg,
    Color? toneRedBg,
    Color? toneRedFg,
  }) {
    return CottageSurface(
      background: background ?? this.background,
      card: card ?? this.card,
      foreground: foreground ?? this.foreground,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      secondary: secondary ?? this.secondary,
      muted: muted ?? this.muted,
      navBackground: navBackground ?? this.navBackground,
      navInactive: navInactive ?? this.navInactive,
      toneBlueBg: toneBlueBg ?? this.toneBlueBg,
      toneBlueFg: toneBlueFg ?? this.toneBlueFg,
      toneGreenBg: toneGreenBg ?? this.toneGreenBg,
      toneGreenFg: toneGreenFg ?? this.toneGreenFg,
      toneOrangeBg: toneOrangeBg ?? this.toneOrangeBg,
      toneOrangeFg: toneOrangeFg ?? this.toneOrangeFg,
      toneRedBg: toneRedBg ?? this.toneRedBg,
      toneRedFg: toneRedFg ?? this.toneRedFg,
    );
  }

  @override
  CottageSurface lerp(ThemeExtension<CottageSurface>? other, double t) {
    if (other is! CottageSurface) return this;
    return t < 0.5 ? this : other;
  }
}

/// Convenience accessor: `context.surface.card` instead of the verbose
/// `Theme.of(context).extension<CottageSurface>()!.card`.
extension CottageSurfaceContext on BuildContext {
  CottageSurface get surface => Theme.of(this).extension<CottageSurface>()!;
}

ThemeData buildCottageTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final surface = isDark ? CottageSurface.dark : CottageSurface.light;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: CottageColors.primary,
    brightness: brightness,
    primary: CottageColors.primary,
    onPrimary: CottageColors.primaryForeground,
    surface: surface.card,
    error: CottageColors.destructive,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: surface.background,
    fontFamily: 'Roboto',
    extensions: [surface],
    cardTheme: CardThemeData(
      color: surface.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: surface.border),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: surface.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CottageColors.primary,
        foregroundColor: CottageColors.primaryForeground,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? CottageColors.primaryForeground : surface.card,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? CottageColors.primary : surface.muted,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface.background,
      foregroundColor: surface.foreground,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: surface.foreground),
      titleLarge: TextStyle(color: surface.foreground, fontWeight: FontWeight.w700),
    ),
  );
}
