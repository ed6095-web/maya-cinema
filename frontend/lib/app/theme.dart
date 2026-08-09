// MAYA — Design System & Theme
// All colors, text styles, spacing, and ThemeData in one place.
// Never hardcode colors in widgets — always use MayaColors.*

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================================
// Color System
// ============================================================================

abstract class MayaColors {
  // Backgrounds
  static const Color background = Color(0xFF050505);
  static const Color surface = Color(0xFF0D0D0D);
  static const Color surfaceSecondary = Color(0xFF151515);
  static const Color surfaceElevated = Color(0xFF1C1C1C);
  static const Color surfaceCard = Color(0xFF111111);

  // Text
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFA1A1A1);
  static const Color textMuted = Color(0xFF6F6F6F);
  static const Color textDisabled = Color(0xFF3D3D3D);

  // Accent — muted gold/champagne, matches the MAYA logo
  static const Color accent = Color(0xFFC9A84C);
  static const Color accentDim = Color(0xFF8A6F2E);
  static const Color accentSubtle = Color(0xFF2A2218);

  // Semantic
  static const Color error = Color(0xFFCF6679);
  static const Color success = Color(0xFF5C9E6B);
  static const Color warning = Color(0xFFD4A84B);

  // Dividers & Borders
  static const Color divider = Color(0xFF1E1E1E);
  static const Color border = Color(0xFF252525);
  static const Color borderFocus = Color(0xFF3A3A3A);

  // Player overlay
  static const Color playerOverlay = Color(0xCC000000);
}

// ============================================================================
// Spacing System
// ============================================================================

abstract class MayaSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const double cardRadius = 8.0;
  static const double dialogRadius = 12.0;
  static const double buttonRadius = 6.0;
  static const double inputRadius = 6.0;
}

// ============================================================================
// Text Styles
// ============================================================================

abstract class MayaTextStyles {
  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: MayaColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get displayMedium => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: MayaColors.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: MayaColors.textPrimary,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: MayaColors.textPrimary,
      );

  static TextStyle get titleSmall => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: MayaColors.textPrimary,
        letterSpacing: 0.1,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: MayaColors.textSecondary,
        height: 1.6,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: MayaColors.textSecondary,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: MayaColors.textMuted,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: MayaColors.textPrimary,
        letterSpacing: 0.5,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: MayaColors.textMuted,
        letterSpacing: 0.5,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: MayaColors.textMuted,
        letterSpacing: 0.8,
      );

  // Accent variant
  static TextStyle get accentLabel => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: MayaColors.accent,
        letterSpacing: 1.2,
      );

  static TextStyle get logoText => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: MayaColors.accent,
        letterSpacing: 6,
      );
}

// ============================================================================
// ThemeData
// ============================================================================

class MayaTheme {
  MayaTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: MayaColors.background,
      colorScheme: const ColorScheme.dark(
        surface: MayaColors.surface,
        primary: MayaColors.accent,
        onPrimary: MayaColors.background,
        secondary: MayaColors.accentDim,
        onSecondary: MayaColors.textPrimary,
        error: MayaColors.error,
        onSurface: MayaColors.textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: MayaColors.textSecondary,
        displayColor: MayaColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: MayaColors.background,
        foregroundColor: MayaColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: MayaTextStyles.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardTheme(
        color: MayaColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MayaSpacing.cardRadius)),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: MayaColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MayaColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MayaSpacing.inputRadius),
          borderSide: const BorderSide(color: MayaColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MayaSpacing.inputRadius),
          borderSide: const BorderSide(color: MayaColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MayaSpacing.inputRadius),
          borderSide: const BorderSide(color: MayaColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MayaSpacing.inputRadius),
          borderSide: const BorderSide(color: MayaColors.error),
        ),
        hintStyle: MayaTextStyles.bodyMedium.copyWith(color: MayaColors.textMuted),
        labelStyle: MayaTextStyles.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MayaColors.accent,
          foregroundColor: MayaColors.background,
          elevation: 0,
          textStyle: MayaTextStyles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MayaSpacing.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MayaColors.accent,
          textStyle: MayaTextStyles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MayaSpacing.buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MayaColors.textPrimary,
          side: const BorderSide(color: MayaColors.border),
          textStyle: MayaTextStyles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MayaSpacing.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: MayaColors.surface,
        selectedItemColor: MayaColors.accent,
        unselectedItemColor: MayaColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: MayaColors.surface,
        indicatorColor: MayaColors.accentSubtle,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: MayaColors.accent);
          }
          return const IconThemeData(color: MayaColors.textMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return MayaTextStyles.labelSmall.copyWith(color: MayaColors.accent);
          }
          return MayaTextStyles.labelSmall;
        }),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: MayaColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MayaSpacing.dialogRadius),
        ),
        titleTextStyle: MayaTextStyles.titleMedium,
        contentTextStyle: MayaTextStyles.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MayaColors.surfaceElevated,
        contentTextStyle: MayaTextStyles.bodyMedium.copyWith(color: MayaColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MayaSpacing.buttonRadius),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
