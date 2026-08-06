import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class MapConfig {
  const MapConfig._();

  static const androidKey = 'AIzaSyCHmAnPG06Vm2V5XPDsQYmfzHy13ICCDtM';
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
