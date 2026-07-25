import 'package:intl/intl.dart';

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

/// Algerian dinar (DZD) using Latin digits regardless of UI locale.
NumberFormat dzdCurrency({int decimalDigits = 0}) {
  return NumberFormat.currency(
    locale: 'en',
    symbol: 'DZD ',
    decimalDigits: decimalDigits,
  );
}

/// Format dates with the given locale (month/weekday names) but Latin numerals.
String formatDateWesternDigits(String pattern, DateTime date, String locale) {
  return westernDigits(DateFormat(pattern, locale).format(date));
}

String ltrNumber(String input) => '\u2066${westernDigits(input)}\u2069';

String formatTripPrice(double amount) {
  return ltrNumber(dzdCurrency().format(amount));
}
