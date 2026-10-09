import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class MapConfig {
  const MapConfig._();

  static const _envAndroidKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const _envIosKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY_IOS');

  // Keys must be supplied via --dart-define=GOOGLE_MAPS_API_KEY=... / env
  static String get androidKey => _envAndroidKey;

  static String get iosKey =>
      _envIosKey.isNotEmpty ? _envIosKey : _envAndroidKey;

  static String get mapApiKey {
    if (kIsWeb) return iosKey;
    if (defaultTargetPlatform == TargetPlatform.android) return androidKey;
    return iosKey;
  }

  static const enableGoogleMap = true;

  static bool get canRenderGoogleMap {
    if (!enableGoogleMap) return false;
    if (!mapApiKey.startsWith('AIza')) return false;
    if (mapApiKey.length < 30) return false;
    return true;
  }
}
