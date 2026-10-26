import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Converts Arabic-Indic and Eastern Arabic-Indic digits to Latin 0–9.
String westernDigits(String input) {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  const easternArabic = '۰۱۲۳۴۵۶۷۸۹';
  final buf = StringBuffer();
  for (final rune in input.runes) {
    final c = String.fromCharCode(rune);
    var d = arabicIndic.indexOf(c);
    if (d < 0) d = easternArabic.indexOf(c);
    if (d >= 0) {
      buf.write('$d');
    } else {
      buf.write(c);
    }
  }
  return buf.toString();
}

/// Wraps numeric text in LTR isolates so digits stay left-to-right in RTL UI.
String ltrNumber(String input) => '\u2066${westernDigits(input)}\u2069';

bool _isArabic([BuildContext? context]) {
  if (context != null) {
    try {
      if (context.locale.languageCode == 'ar') return true;
    } catch (_) {}
  }
  final def = Intl.defaultLocale;
  if (def != null && def.toLowerCase().startsWith('ar')) return true;
  try {
    final sym = 'dzd_currency'.tr();
    if (sym == 'دج' || sym == 'د.ج') return true;
  } catch (_) {}
  return false;
}

/// Algerian dinar (DZD) using Latin digits regardless of UI locale.
/// Formats as 'دج ' when in Arabic locale, and 'DZD ' otherwise.
NumberFormat dzdCurrency({int decimalDigits = 0, BuildContext? context}) {
  final sym = _isArabic(context) ? '\u200E\u2067دج\u2069 ' : 'DZD ';
  return NumberFormat.currency(
    locale: 'en',
    symbol: sym,
    decimalDigits: decimalDigits,
  );
}

/// Formatted trip price with western digits and LTR isolation for RTL layouts.
String formatTripPrice(double amount, [BuildContext? context]) {
  return ltrNumber(dzdCurrency(context: context).format(amount));
}

/// Format dates with the given locale (month/weekday names) but Latin numerals.
String formatDateWesternDigits(String pattern, DateTime date, String locale) {
  return westernDigits(DateFormat(pattern, locale).format(date));
}

/// Formats distance with unit localized. In Arabic, unit appears on the left: 'كم 12.3'.
String formatDistanceKm(double km, [BuildContext? context]) {
  final d = westernDigits(km.toStringAsFixed(1));
  if (_isArabic(context)) {
    return '\u200E\u2067كم\u2069 $d';
  }
  return '$d km';
}

/// Localizes generic fallback locations like 'Custom Pickup Point' or 'Custom Drop-off Point'.
String formatLocationName(String location, [BuildContext? context]) {
  final trimmed = location.trim();
  final lower = trimmed.toLowerCase();
  if (lower == 'custom pickup point' || lower == 'custom pickup location') {
    return 'custom_pickup_point'.tr();
  }
  if (lower == 'custom drop-off point' ||
      lower == 'custom drop-off location' ||
      lower == 'custom dropoff point' ||
      lower == 'custom dropoff location') {
    return 'custom_dropoff_point'.tr();
  }
  return location;
}
