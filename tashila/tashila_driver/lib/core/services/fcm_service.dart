import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tashila_driver/core/router/app_router.dart';
import 'package:tashila_driver/core/services/api_client.dart';
import 'package:tashila_driver/core/state/driver_app_state.dart';

const AndroidNotificationChannel kTripOfferChannel = AndroidNotificationChannel(
  'driver_trip_offers',
  'Trip Offers',
  description: 'High-priority notifications for new incoming trip requests',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _initialized = false;

  Future<void> initialize(WidgetRef ref) async {
    if (_initialized) return;
    _initialized = true;

    // 1. Request notification permissions
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Setup Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(kTripOfferChannel);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(ref, response.payload);
      },
    );

    // 3. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 4. Register push token with backend
    unawaited(syncPushToken(ref));

    messaging.onTokenRefresh.listen((token) async {
      await _sendTokenToBackend(ref, token);
    });

    // 5. Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleIncomingMessage(ref, message, isForeground: true);
    });

    // 6. Handle notification click when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(ref, message.data['tripId'] ?? message.data['type']);
    });

    // 7. Handle notification click when app was terminated
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationTap(
          ref,
          initialMessage.data['tripId'] ?? initialMessage.data['type'],
        );
      });
    }
  }

  Future<void> syncPushToken(dynamic ref) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _sendTokenToBackend(ref, token);
      }
    } catch (_) {}
  }

  Future<void> _sendTokenToBackend(dynamic ref, String token) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.post(
        '/drivers/me/push-token',
        data: {'token': token, 'platform': 'fcm'},
      );
      print('FCM Token registered with backend successfully: ${res.statusCode}');
    } catch (e) {
      print('Failed to register FCM token with backend: $e');
    }
  }

  void _handleIncomingMessage(
    WidgetRef ref,
    RemoteMessage message, {
    required bool isForeground,
  }) {
    final data = message.data;
    final type = data['type'] ?? '';

    if (type == 'trip_request') {
      // Ring and refresh offers
      try {
        FlutterRingtonePlayer().play(
          android: AndroidSounds.notification,
          ios: IosSounds.glass,
          looping: false,
          volume: 1.0,
          asAlarm: false,
        );
      } catch (_) {}

      // Refresh incoming offers to display on screen
      unawaited(
        ref.read(driverAppStateProvider.notifier).refreshIncomingOffers(),
      );

      // Show high-priority local notification
      final notification = message.notification;
      final title = notification?.title ?? 'طلب رحلة جديد';
      final body = notification?.body ??
          '${data['pickupAddress'] ?? 'Pickup'} — ${data['fare'] ?? ''} DZD';

      _localNotifications.show(
        DateTime.now().millisecond,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            kTripOfferChannel.id,
            kTripOfferChannel.name,
            channelDescription: kTripOfferChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
        ),
        payload: data['tripId'] ?? 'trip_request',
      );
    }
  }

  void _handleNotificationTap(WidgetRef ref, String? payload) {
    // Navigate driver to home screen where incoming offer is displayed
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null) {
      try {
        GoRouter.of(ctx).go('/home');
      } catch (_) {}
    }

    // Refresh active offers so the offer sheet opens immediately
    unawaited(
      ref.read(driverAppStateProvider.notifier).refreshIncomingOffers(),
    );
  }

  Future<void> showTripOfferNotification({
    required String title,
    required String body,
    required String tripId,
  }) async {
    try {
      await _localNotifications.show(
        tripId.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            kTripOfferChannel.id,
            kTripOfferChannel.name,
            channelDescription: kTripOfferChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
        ),
        payload: tripId,
      );
    } catch (_) {}
  }
}
