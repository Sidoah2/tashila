import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tashila_client/core/theme/app_colors.dart';

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.brandOrange,
    primary: AppColors.brandOrange,
  );

  final seed = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
  );

  var textTheme = GoogleFonts.tajawalTextTheme(seed.textTheme);

  double bump(double? size, double delta) => (size ?? 14) + delta;

  textTheme = textTheme.copyWith(
    displayLarge: textTheme.displayLarge?.copyWith(fontSize: bump(textTheme.displayLarge?.fontSize, 2)),
    displayMedium: textTheme.displayMedium?.copyWith(fontSize: bump(textTheme.displayMedium?.fontSize, 2)),
    displaySmall: textTheme.displaySmall?.copyWith(fontSize: bump(textTheme.displaySmall?.fontSize, 2)),
    headlineLarge: textTheme.headlineLarge?.copyWith(fontSize: bump(textTheme.headlineLarge?.fontSize, 2)),
    headlineMedium: textTheme.headlineMedium?.copyWith(fontSize: bump(textTheme.headlineMedium?.fontSize, 1.5)),
    headlineSmall: textTheme.headlineSmall?.copyWith(fontSize: bump(textTheme.headlineSmall?.fontSize, 1.5)),
    titleLarge: textTheme.titleLarge?.copyWith(fontSize: bump(textTheme.titleLarge?.fontSize, 1.5)),
    titleMedium: textTheme.titleMedium?.copyWith(fontSize: bump(textTheme.titleMedium?.fontSize, 1.5)),
    titleSmall: textTheme.titleSmall?.copyWith(fontSize: bump(textTheme.titleSmall?.fontSize, 1)),
    bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: bump(textTheme.bodyLarge?.fontSize, 1.5)),
    bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: bump(textTheme.bodyMedium?.fontSize, 1.5)),
    bodySmall: textTheme.bodySmall?.copyWith(fontSize: bump(textTheme.bodySmall?.fontSize, 1)),
    labelLarge: textTheme.labelLarge?.copyWith(fontSize: bump(textTheme.labelLarge?.fontSize, 1.5)),
    labelMedium: textTheme.labelMedium?.copyWith(fontSize: bump(textTheme.labelMedium?.fontSize, 1)),
    labelSmall: textTheme.labelSmall?.copyWith(fontSize: bump(textTheme.labelSmall?.fontSize, 1)),
  );

  const iconTheme = IconThemeData(size: 26, color: AppColors.textPrimary);

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: colorScheme,
    textTheme: textTheme,
    iconTheme: iconTheme,
    primaryIconTheme: iconTheme.copyWith(color: AppColors.brandOrange),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: iconTheme,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandOrange,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        textStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
        iconColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0.5,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: textTheme.bodyMedium,
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    chipTheme: ChipThemeData(
      labelStyle: textTheme.labelLarge,
      secondaryLabelStyle: textTheme.labelMedium,
    ),
    navigationBarTheme: NavigationBarThemeData(
      iconTheme: WidgetStateProperty.resolveWith((_) => iconTheme),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (_) => textTheme.labelMedium ?? const TextStyle(),
      ),
    ),
  );
}
