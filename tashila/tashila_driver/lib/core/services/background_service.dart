import 'dart:async';

/// Background service initialization.
///
/// Persistent foreground notification (ID 888) and fullScreenIntent
/// have been eliminated so that:
/// 1. The persistent "Tashila Driver Active" notification is removed.
/// 2. The app does not forcibly hijack the screen or steal focus over
///    other running applications (e.g. Instagram, Facebook).
///
/// All incoming trip notifications are handled natively by FCM
/// (Firebase Cloud Messaging) via [FcmService] with high priority heads-up
/// alerts, sound, vibration, and full Arabic trip details.
Future<void> initializeBackgroundService() async {
  // No-op: Background service disabled in favor of native FCM dispatch.
}
