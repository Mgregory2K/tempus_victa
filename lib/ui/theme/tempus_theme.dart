import 'package:flutter/material.dart';

@immutable
class TempusBrand extends ThemeExtension<TempusBrand> {
  final Color surface0; // scaffold background
  final Color surface1; // cards
  final Color surface2; // elevated cards / sheets
  final Color border;
  final Color muted;
  final Color accent; // primary accent (neon green, used sparingly)
  final double radiusLg;
  final double radiusMd;

  const TempusBrand({
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.border,
    required this.muted,
    required this.accent,
    this.radiusLg = 22,
    this.radiusMd = 16,
  });

  @override
  TempusBrand copyWith({
    Color? surface0,
    Color? surface1,
    Color? surface2,
    Color? border,
    Color? muted,
    Color? accent,
    double? radiusLg,
    double? radiusMd,
  }) {
    return TempusBrand(
      surface0: surface0 ?? this.surface0,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusMd: radiusMd ?? this.radiusMd,
    );
  }

  @override
  TempusBrand lerp(ThemeExtension<TempusBrand>? other, double t) {
    if (other is! TempusBrand) return this;
    Color lc(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    double ld(double a, double b) => a + (b - a) * t;
    return TempusBrand(
      surface0: lc(surface0, other.surface0),
      surface1: lc(surface1, other.surface1),
      surface2: lc(surface2, other.surface2),
      border: lc(border, other.border),
      muted: lc(muted, other.muted),
      accent: lc(accent, other.accent),
      radiusLg: ld(radiusLg, other.radiusLg),
      radiusMd: ld(radiusMd, other.radiusMd),
    );
  }
}

class TempusTheme {
  // Michael likes neon green; we use it as an accent, not a flood.
  static const Color neonGreen = Color(0xFF39FF14);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    final cs = base.colorScheme.copyWith(
      primary: neonGreen,
      secondary: neonGreen,
      background: const Color(0xFFF3F5F8),
      surface: const Color(0xFFF8FAFC),
      outlineVariant: const Color(0xFFE2E8F0),
    );

    final brand = TempusBrand(
      surface0: const Color(0xFFF3F5F8),
      surface1: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFF8FAFC),
      border: const Color(0xFFE2E8F0),
      muted: const Color(0xFF64748B), // slate-500
      accent: neonGreen,
    );

    final text = base.textTheme.apply(
      bodyColor: const Color(0xFF0F172A), // slate-900
      displayColor: const Color(0xFF0F172A),
    ).copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.25),
      bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.2),
    );

    return base.copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor: brand.surface0,
      extensions: <ThemeExtension<dynamic>>[brand],
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(brand.radiusLg),
          side: BorderSide(color: brand.border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(color: brand.border.withOpacity(.9), thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brand.surface1,
        hintStyle: TextStyle(color: brand.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: BorderSide(color: brand.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: BorderSide(color: brand.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: const BorderSide(color: neonGreen, width: 1.6),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: brand.border),
        labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      textTheme: text,
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    final cs = base.colorScheme.copyWith(
      primary: neonGreen,
      secondary: neonGreen,
      background: const Color(0xFF0B0F14),
      surface: const Color(0xFF0F1620),
      outlineVariant: const Color(0xFF243244),
    );

    final brand = TempusBrand(
      surface0: const Color(0xFF0B0F14),
      surface1: const Color(0xFF0F1620),
      surface2: const Color(0xFF111A25),
      border: const Color(0xFF243244),
      muted: const Color(0xFF9CA3AF), // gray-400
      accent: neonGreen,
    );

    final text = base.textTheme.apply(
      bodyColor: const Color(0xFFE5E7EB),
      displayColor: const Color(0xFFE5E7EB),
    ).copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.25),
      bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.2),
    );

    return base.copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor: brand.surface0,
      extensions: <ThemeExtension<dynamic>>[brand],
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(brand.radiusLg),
          side: BorderSide(color: brand.border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(color: brand.border.withOpacity(.9), thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brand.surface1,
        hintStyle: TextStyle(color: brand.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: BorderSide(color: brand.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: BorderSide(color: brand.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radiusMd),
          borderSide: const BorderSide(color: neonGreen, width: 1.6),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: brand.border),
        labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      textTheme: text,
    );
  }
}

extension TempusBrandX on BuildContext {
  TempusBrand get tv => Theme.of(this).extension<TempusBrand>()!;
}
