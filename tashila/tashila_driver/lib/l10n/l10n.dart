import 'package:flutter/material.dart';

/// Centralized localization declarations for Tashila Driver app (supporting Arabic, English, French).
class AppL10n {
  const AppL10n._();

  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  static const Locale defaultLocale = Locale('ar');
  static const String translationsPath = 'assets/translations';

  static String languageName(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return 'العربية';
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      default:
        return languageCode;
    }
  }
}
