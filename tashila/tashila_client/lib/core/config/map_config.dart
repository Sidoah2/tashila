import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class MapConfig {
  const MapConfig._();

  static const _androidKey = 'AIzaSyCHmAnPG06Vm2V5XPDsQYmfzHy13ICCDtM';
  static const _iosKey = 'AIzaSyDOxXdhOejrci6fERrxrA5NE2C0P60PlJg';

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
