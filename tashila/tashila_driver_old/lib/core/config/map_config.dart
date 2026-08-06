import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class MapConfig {
  const MapConfig._();

  static const androidKey = 'AIzaSyBaRXAy9z9IClUJ1jYhYvPexA7rvp-_228';
  static const iosKey = 'AIzaSyDOxXdhOejrci6fERrxrA5NE2C0P60PlJg';

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
