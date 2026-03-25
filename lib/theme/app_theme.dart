import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg       = Color(0xFF09090B);
  static const surface  = Color(0xFF111113);
  static const card     = Color(0xFF1A1A1E);
  static const border   = Color(0xFF27272B);

  static const cyan     = Color(0xFF00C8FF);
  static const cyanDim  = Color(0x2600C8FF);
  static const orange   = Color(0xFFFF7043);
  static const orangeDim= Color(0x26FF7043);
  static const green    = Color(0xFF23D18B);
  static const greenDim = Color(0x2623D18B);
  static const red      = Color(0xFFFF4444);
  static const redDim   = Color(0x26FF4444);

  static const textPrimary   = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF71717A);
  static const textMuted     = Color(0xFF3F3F46);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.cyan,
        secondary: AppColors.orange,
        error: AppColors.red,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.dmSans(color: AppColors.textPrimary),
        bodyLarge:    GoogleFonts.dmSans(color: AppColors.textPrimary),
        bodyMedium:   GoogleFonts.dmSans(color: AppColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.dmSans(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.cyan,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.bg;
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.cyan;
          return AppColors.border;
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.cyan,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.cyan,
        overlayColor: AppColors.cyanDim,
        trackHeight: 3,
      ),
    );
  }

  static ThemeData get light => dark;
}

class AppText {
  static TextStyle value(Color color) => GoogleFonts.jetBrainsMono(
    color: color, fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5,
  );

  static TextStyle valueLarge(Color color) => GoogleFonts.jetBrainsMono(
    color: color, fontSize: 40, fontWeight: FontWeight.w500, letterSpacing: -1,
  );

  static final TextStyle label = GoogleFonts.dmSans(
    color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5,
  );

  static final TextStyle title = GoogleFonts.dmSans(
    color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2,
  );

  static final TextStyle body = GoogleFonts.dmSans(
    color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w400,
  );
}