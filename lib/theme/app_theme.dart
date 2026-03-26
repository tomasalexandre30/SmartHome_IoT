import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds
  static const bg      = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const card    = Color(0xFFFFFFFF);
  static const border  = Color(0xFFEAECF0);

  // Accent — índigo vivo
  static const indigo    = Color(0xFF4F6EF7);
  static const indigoDim = Color(0x184F6EF7);
  static const indigoLight = Color(0xFFEEF1FE);

  // Semânticos
  static const teal    = Color(0xFF0EA5A0);
  static const tealDim = Color(0x180EA5A0);
  static const amber   = Color(0xFFF59E0B);
  static const amberDim= Color(0x18F59E0B);
  static const rose    = Color(0xFFEF4444);
  static const roseDim = Color(0x18EF4444);
  static const green   = Color(0xFF10B981);
  static const greenDim= Color(0x1810B981);

  // Texto
  static const textPrimary   = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFFD1D5DB);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        surface: AppColors.surface,
        primary: AppColors.indigo,
        secondary: AppColors.teal,
        error: AppColors.rose,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(color: AppColors.textPrimary),
        bodyLarge:    GoogleFonts.inter(color: AppColors.textPrimary),
        bodyMedium:   GoogleFonts.inter(color: AppColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.indigo,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return AppColors.indigo;
          return AppColors.border;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.indigo,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.indigo,
        overlayColor: AppColors.indigoDim,
        trackHeight: 4,
      ),
    );
  }

  static ThemeData get dark => light;
}

class AppText {
  static TextStyle value(Color color) => GoogleFonts.inter(
    color: color, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5,
  );

  static TextStyle valueLarge(Color color) => GoogleFonts.inter(
    color: color, fontSize: 42, fontWeight: FontWeight.w700, letterSpacing: -1,
  );

  static final TextStyle label = GoogleFonts.inter(
    color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  static final TextStyle title = GoogleFonts.inter(
    color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static final TextStyle body = GoogleFonts.inter(
    color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w400,
  );
}