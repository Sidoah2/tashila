import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class MapConfig {
  const MapConfig._();

  static const _envAndroidKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const _envIosKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY_IOS');

  // Keys must be supplied via --dart-define=GOOGLE_MAPS_API_KEY=... / env
  static String get _androidKey => _envAndroidKey;

  static String get _iosKey =>
      _envIosKey.isNotEmpty ? _envIosKey : _envAndroidKey;

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
