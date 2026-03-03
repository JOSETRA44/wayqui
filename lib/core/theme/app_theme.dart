import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class AppTheme {
  AppTheme._();

  // Paleta Comic — vibrant & bold
  static const Color _primary = Color(0xFF5B3FE8);
  static const Color _onPrimary = Color(0xFFFFFFFF);
  static const Color _secondary = Color(0xFFFF6B35);
  static const Color _onSecondary = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFFFFDF7);
  static const Color _onSurface = Color(0xFF1A1A2E);
  static const Color _outline = Color(0xFF1A1A2E);
  static const Color _error = Color(0xFFE53935);
  static const Color _onError = Color(0xFFFFFFFF);

  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      primary: _primary,
      onPrimary: _onPrimary,
      secondary: _secondary,
      onSecondary: _onSecondary,
      surface: _surface,
      onSurface: _onSurface,
      outline: _outline,
      error: _error,
      onError: _onError,
    );

    final baseText = GoogleFonts.nunitoTextTheme();

    TextTheme textTheme = baseText.copyWith(
      displayLarge: GoogleFonts.bangers(
          fontSize: 57, letterSpacing: 2.0, color: _onSurface),
      displayMedium: GoogleFonts.bangers(
          fontSize: 45, letterSpacing: 1.5, color: _onSurface),
      displaySmall: GoogleFonts.bangers(
          fontSize: 36, letterSpacing: 1.5, color: _onSurface),
      headlineLarge: GoogleFonts.bangers(
          fontSize: 32, letterSpacing: 1.5, color: _onSurface),
      headlineMedium: GoogleFonts.bangers(
          fontSize: 28, letterSpacing: 1.0, color: _onSurface),
      headlineSmall: GoogleFonts.bangers(
          fontSize: 24, letterSpacing: 1.0, color: _onSurface),
      titleLarge: GoogleFonts.nunito(
          fontSize: 22, fontWeight: FontWeight.w700, color: _onSurface),
      titleMedium: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w700, color: _onSurface),
      titleSmall: GoogleFonts.nunito(
          fontSize: 14, fontWeight: FontWeight.w700, color: _onSurface),
      bodyLarge:
          GoogleFonts.nunito(fontSize: 16, color: _onSurface),
      bodyMedium:
          GoogleFonts.nunito(fontSize: 14, color: _onSurface),
      bodySmall:
          GoogleFonts.nunito(fontSize: 12, color: _onSurface),
      labelLarge: GoogleFonts.nunito(
          fontSize: 15, fontWeight: FontWeight.w700, color: _onSurface),
      labelMedium: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w600, color: _onSurface),
      labelSmall: GoogleFonts.nunito(
          fontSize: 11, fontWeight: FontWeight.w600, color: _onSurface),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: _surface,
      appBarTheme: AppBarTheme(
        elevation: AppConstants.elevation,
        backgroundColor: _surface,
        foregroundColor: _onSurface,
        centerTitle: false,
        titleTextStyle: GoogleFonts.bangers(
          fontSize: 24,
          letterSpacing: 1.0,
          color: _onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical: AppConstants.spacing16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(
              color: _outline, width: AppConstants.borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(
              color: _outline, width: AppConstants.borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(
              color: _primary, width: AppConstants.borderWidth),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(
              color: _error, width: AppConstants.borderWidth),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(
              color: _error, width: AppConstants.borderWidth),
        ),
        errorStyle: GoogleFonts.nunito(fontSize: 12, color: _error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppConstants.elevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            side: const BorderSide(
                color: _outline, width: AppConstants.borderWidth),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacing24,
            vertical: AppConstants.spacing16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _primary),
      ),
      cardTheme: CardTheme(
        elevation: AppConstants.elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: const BorderSide(
              color: _outline, width: AppConstants.borderWidth),
        ),
        color: _surface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: const BorderSide(
              color: _outline, width: AppConstants.borderWidthList),
        ),
        contentTextStyle: GoogleFonts.nunito(fontSize: 14),
      ),
    );
  }
}
