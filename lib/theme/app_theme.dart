import 'package:flutter/material.dart';

class AppTheme {
  static const Color background    = Color(0xFFF5F7FA);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceCard   = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF8FAFC);
  static const Color border        = Color(0xFFEAECF0);
  static const Color borderLight   = Color(0xFFF1F5F9);

  static const Color accent        = Color(0xFF2563EB);
  static const Color accentLight   = Color(0xFFEFF6FF);
  static const Color accentBorder  = Color(0xFFBFDBFE);

  static const Color success       = Color(0xFF16A34A);
  static const Color successLight  = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFFBBF7D0);

  static const Color warning       = Color(0xFFD97706);
  static const Color warningLight  = Color(0xFFFFF7ED);
  static const Color warningBorder = Color(0xFFFED7AA);

  static const Color error         = Color(0xFFDC2626);
  static const Color errorLight    = Color(0xFFFEF2F2);
  static const Color errorBorder   = Color(0xFFFECACA);

  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted     = Color(0xFF9CA3AF);
  static const Color textDisabled  = Color(0xFFD1D5DB);

  static const List<Color> zoneColors = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFF059669),
  ];
  static const List<Color> zoneColorsBg = [
    Color(0xFFEFF6FF),
    Color(0xFFF5F3FF),
    Color(0xFFECFEFF),
    Color(0xFFECFDF5),
  ];

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      surface: surface,
      primary: accent,
      secondary: success,
      error: error,
      onSurface: textPrimary,
      onPrimary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: textSecondary),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: textDisabled,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceSubtle,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: textDisabled, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
            (s) => Colors.white,
      ),
      trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? accent : textDisabled,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: border,
      thumbColor: Colors.white,
      trackHeight: 4,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 9),
    ),
    dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      subtitleTextStyle: TextStyle(color: textMuted, fontSize: 12),
    ),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -1),
      displayMedium:  TextStyle(color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineLarge:  TextStyle(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      headlineSmall:  TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      titleLarge:     TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.2),
      titleMedium:    TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
      titleSmall:     TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
      bodyLarge:      TextStyle(color: textPrimary, fontSize: 15),
      bodyMedium:     TextStyle(color: textSecondary, fontSize: 14),
      bodySmall:      TextStyle(color: textMuted, fontSize: 12),
      labelLarge:     TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.1),
      labelMedium:    TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
      labelSmall:     TextStyle(color: textMuted, fontWeight: FontWeight.w600, fontSize: 10, letterSpacing: 0.3),
    ),
  );
}

class SS {
  static BoxDecoration card({Color? accentColor, bool elevated = false}) => BoxDecoration(
    color: AppTheme.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: accentColor != null ? accentColor.withOpacity(0.35) : AppTheme.border,
      width: accentColor != null ? 1.5 : 1,
    ),
    boxShadow: accentColor != null
        ? [
      BoxShadow(color: accentColor.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
    ]
        : elevated
        ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))]
        : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
  );

  static BoxDecoration glowCard({Color? glowColor}) => card(accentColor: glowColor);

  static BoxDecoration tile() => BoxDecoration(
    color: AppTheme.surfaceSubtle,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppTheme.borderLight),
  );

  static BoxDecoration pill({Color? color}) => BoxDecoration(
    color: (color ?? AppTheme.accent).withOpacity(0.08),
    borderRadius: BorderRadius.circular(100),
    border: Border.all(color: (color ?? AppTheme.accent).withOpacity(0.2)),
  );

  static BoxDecoration iconBox({required Color color}) => BoxDecoration(
    color: color.withOpacity(0.10),
    borderRadius: BorderRadius.circular(10),
  );
}