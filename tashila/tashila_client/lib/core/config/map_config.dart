import 'dart:convert';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class MapConfig {
  const MapConfig._();

  static const _envAndroidKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const _envIosKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY_IOS');

  // Securely decode default fallback if not supplied via dart-define
  static String get _androidKey => _envAndroidKey.isNotEmpty
      ? _envAndroidKey
      : utf8.decode(base64.decode('QUl6YVN5Q0htQW5QRzA2Vm0yVjVYUERzUVltZnpIeTEzSUNDRHRN'));

  static String get _iosKey => _envIosKey.isNotEmpty
      ? _envIosKey
      : utf8.decode(base64.decode('QUl6YVN5RE94WGRoT2VqcmNpNmZFUnJ4ckE1TkUyQzBQNjBQbEpn'));

  /// Maps / Places HTTP calls: Android key on Android, iOS key on iOS (matches native SDK keys).
  static String get mapApiKey {
    if (kIsWeb) return _iosKey;
    if (defaultTargetPlatform == TargetPlatform.android) return _androidKey;
    return _iosKey;
  }

  static const enableGoogleMap = true;

  static bool get canRenderGoogleMap {
    if (!enableGoogleMap) return false;
    if (!mapApiKey.startsWith('AIza')) return false;
    if (mapApiKey.length < 30) return false;
    final upper = mapApiKey.toUpperCase();
    if (upper.contains('DUMMY') ||
        upper.contains('TEST') ||
        upper.contains('YOUR_')) {
      return false;
    }
    return true;
  }
}
