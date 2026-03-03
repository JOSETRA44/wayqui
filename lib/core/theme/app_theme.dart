import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../extensions/wayqui_colors.dart';

/// Sistema de temas de Wayqui.
/// Acceder a colores semánticos:
///   Theme.of(context).extension<WayquiColors>()!.positive
class AppTheme {
  AppTheme._();

  // ── Paleta Light ──────────────────────────────────────────────
  static const _lPrimary   = Color(0xFF5B3FE8);
  static const _lSecondary = Color(0xFFFF6B35);
  static const _lSurface   = Color(0xFFFFFDF7);
  static const _lOnSurface = Color(0xFF1A1A2E);
  static const _lOutline   = Color(0xFF1A1A2E);
  static const _lError     = Color(0xFFE53935);

  // ── Paleta Dark ───────────────────────────────────────────────
  static const _dPrimary   = Color(0xFF7C6FF7);
  static const _dSecondary = Color(0xFFFF8C5A);
  static const _dSurface   = Color(0xFF0F172A);
  static const _dOnSurface = Color(0xFFF1F5F9);
  static const _dOutline   = Color(0xFF475569);
  static const _dError     = Color(0xFFEF4444);

  // ─────────────────────────────────────────────────────────────
  static ThemeData get light => _build(
        brightness: Brightness.light,
        primary: _lPrimary,
        onPrimary: Colors.white,
        secondary: _lSecondary,
        onSecondary: Colors.white,
        surface: _lSurface,
        onSurface: _lOnSurface,
        outline: _lOutline,
        error: _lError,
        wayquiColors: WayquiColors.light,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        primary: _dPrimary,
        onPrimary: Colors.white,
        secondary: _dSecondary,
        onSecondary: Colors.white,
        surface: _dSurface,
        onSurface: _dOnSurface,
        outline: _dOutline,
        error: _dError,
        wayquiColors: WayquiColors.dark,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color surface,
    required Color onSurface,
    required Color outline,
    required Color error,
    required WayquiColors wayquiColors,
    required SystemUiOverlayStyle systemOverlayStyle,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      error: error,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.3),
    );

    final text = _buildTextTheme(onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: text,
      scaffoldBackgroundColor: surface,
      extensions: [wayquiColors],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: onSurface,
        systemOverlayStyle: systemOverlayStyle,
        titleTextStyle: GoogleFonts.bangers(
          fontSize: 24,
          letterSpacing: 1.0,
          color: onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical: AppConstants.spacing16,
        ),
        border: _inputBorder(outline),
        enabledBorder: _inputBorder(outline),
        focusedBorder: _inputBorder(primary, width: AppConstants.borderWidth),
        errorBorder: _inputBorder(error),
        focusedErrorBorder: _inputBorder(error, width: AppConstants.borderWidth),
        errorStyle: GoogleFonts.nunito(fontSize: 12, color: error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            side: BorderSide(color: outline, width: AppConstants.borderWidth),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacing24,
            vertical: AppConstants.spacing16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(color: outline, width: AppConstants.borderWidth),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: 0.15),
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(color: outline, width: AppConstants.borderWidthList),
        ),
        contentTextStyle: GoogleFonts.nunito(fontSize: 14),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color,
      {double width = AppConstants.borderWidth}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _buildTextTheme(Color onSurface) {
    return TextTheme(
      displayLarge: GoogleFonts.bangers(
          fontSize: 57, letterSpacing: 2.0, color: onSurface),
      displayMedium: GoogleFonts.bangers(
          fontSize: 45, letterSpacing: 1.5, color: onSurface),
      displaySmall: GoogleFonts.bangers(
          fontSize: 36, letterSpacing: 1.5, color: onSurface),
      headlineLarge: GoogleFonts.bangers(
          fontSize: 32, letterSpacing: 1.5, color: onSurface),
      headlineMedium: GoogleFonts.bangers(
          fontSize: 28, letterSpacing: 1.0, color: onSurface),
      headlineSmall: GoogleFonts.bangers(
          fontSize: 24, letterSpacing: 1.0, color: onSurface),
      titleLarge: GoogleFonts.nunito(
          fontSize: 22, fontWeight: FontWeight.w700, color: onSurface),
      titleMedium: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w700, color: onSurface),
      titleSmall: GoogleFonts.nunito(
          fontSize: 14, fontWeight: FontWeight.w700, color: onSurface),
      bodyLarge: GoogleFonts.nunito(fontSize: 16, color: onSurface),
      bodyMedium: GoogleFonts.nunito(fontSize: 14, color: onSurface),
      bodySmall: GoogleFonts.nunito(fontSize: 12, color: onSurface),
      labelLarge: GoogleFonts.nunito(
          fontSize: 15, fontWeight: FontWeight.w700, color: onSurface),
      labelMedium: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w600, color: onSurface),
      labelSmall: GoogleFonts.nunito(
          fontSize: 11, fontWeight: FontWeight.w600, color: onSurface),
    );
  }
}
