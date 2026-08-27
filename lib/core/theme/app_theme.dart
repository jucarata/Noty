import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:noty/core/theme/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final interTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.blanco,
      colorScheme: const ColorScheme.light(
        primary: AppColors.azulNoty,
        secondary: AppColors.verde,
        tertiary: AppColors.aquaSuave,
        surface: AppColors.blanco,
        onPrimary: AppColors.blanco,
        onSecondary: AppColors.blanco,
        onSurface: AppColors.grisOscuro,
        outline: AppColors.grisClaro,
      ),
      textTheme: interTextTheme.copyWith(
        displayLarge: GoogleFonts.poppins(
          color: AppColors.azulNoty,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: GoogleFonts.poppins(
          color: AppColors.azulNoty,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.poppins(
          color: AppColors.azulNoty,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.poppins(
          color: AppColors.azulNoty,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: GoogleFonts.poppins(
          color: AppColors.azulNoty,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.poppins(
          color: AppColors.grisOscuro,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.poppins(
          color: AppColors.grisOscuro,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: GoogleFonts.poppins(
          color: AppColors.grisOscuro,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
        ),
        labelMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
        ),
        labelSmall: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.azulNoty,
          foregroundColor: AppColors.blanco,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
