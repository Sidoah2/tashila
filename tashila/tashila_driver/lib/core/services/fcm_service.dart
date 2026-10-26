import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tashila_driver/core/models/models.dart';
import 'package:tashila_driver/core/router/app_router.dart';
import 'package:tashila_driver/core/services/api_client.dart';
import 'package:tashila_driver/core/state/driver_app_state.dart';

import 'package:shared_preferences/shared_preferences.dart';

const AndroidNotificationChannel kTripOfferChannel = AndroidNotificationChannel(
  'driver_trip_offers',
  'Trip Offers',
  description: 'High-priority notifications for new incoming trip requests',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

const AndroidNotificationChannel kInactivityChannel = AndroidNotificationChannel(
  'driver_inactivity_check',
  'Inactivity Reminders',
  description: 'Notifications checking if driver is still available',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

const String kActionStayOnline = 'ACTION_STAY_ONLINE';
const String kActionGoOffline = 'ACTION_GO_OFFLINE';
const String kActionPortName = 'driver_notification_action_port';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final sendPort = IsolateNameServer.lookupPortByName(kActionPortName);
    sendPort?.send(response.actionId);
  } catch (_) {}
  await _processNotificationAction(
    actionId: response.actionId,
    payload: response.payload,
  );
}

Future<void> _processNotificationAction({
  required String? actionId,
  required String? payload,
  WidgetRef? ref,
}) async {
  try {
    await _localNotifications.cancel(999);
  } catch (_) {}

  final targetRef = ref ?? FcmService.instance._ref;

  if (actionId == kActionGoOffline) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kAvailability, AvailabilityStatus.offline.name);
    } catch (_) {}

    if (targetRef != null) {
      try {
        await targetRef
            .read(driverAppStateProvider.notifier)
            .setAvailability(AvailabilityStatus.offline);
        return;
      } catch (_) {}
    }

    try {
      final client = ApiClient();
      await client.put(
        '/drivers/me/availability',
        data: {'availability': 'offline'},
      );
    } catch (_) {}
  } else if (actionId == kActionStayOnline) {
    if (targetRef != null) {
      try {
        final client = targetRef.read(apiClientProvider);
        await client.post('/drivers/me/heartbeat');
        return;
      } catch (_) {}
    }

    try {
      final client = ApiClient();
      await client.post('/drivers/me/heartbeat');
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    final data = message.data;

    if (data['type'] == 'driver_inactivity_check') {
      const title = 'هل ما زلت متاحاً للعمل؟';
      const body = 'أنت متصل في وضع الاستعداد منذ 15 دقيقة دون نشاط في التطبيق.';
      await _localNotifications.show(
        999,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'driver_inactivity_check',
            'Inactivity Reminders',
            channelDescription:
                'Notifications checking if driver is still available',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            actions: [
              AndroidNotificationAction(
                kActionStayOnline,
                'أنا متاح',
                showsUserInterface: true,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                kActionGoOffline,
                'تحويل إلى غير متصل',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'INACTIVITY_CHECK',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'driver_inactivity_check',
      );
      return;
    }

    if (data['type'] == 'trip_request' && message.notification == null) {
      final pickup = (data['pickupAddress'] as String?)?.trim();
      final dropoff = (data['dropoffAddress'] as String?)?.trim();
      final fare = (data['fare'] as String?)?.trim();
      final String body;
      if (dropoff != null && dropoff.isNotEmpty) {
        body = 'الانطلاق: ${pickup ?? "نقطة الانطلاق"}\nالوصول: $dropoff\nالسعر: ${fare ?? ""} دج';
      } else {
        body = 'الانطلاق: ${pickup ?? "نقطة الانطلاق"}\nالسعر: ${fare ?? ""} دج';
      }
      const title = 'طلب رحلة جديد';
      final bigTextStyle = BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'عرض رحلة جديد',
      );
      await _localNotifications.show(
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
            styleInformation: bigTextStyle,
          ),
        ),
        payload: data['tripId'] ?? 'trip_request',
      );
    }
  } catch (_) {}
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _initialized = false;
  WidgetRef? _ref;

  Future<void> initialize(WidgetRef ref) async {
    _ref = ref;
    if (_initialized) return;
    _initialized = true;

    // Listen to background isolate notification actions in real time
    try {
      IsolateNameServer.removePortNameMapping(kActionPortName);
      final port = ReceivePort();
      IsolateNameServer.registerPortWithName(port.sendPort, kActionPortName);
      port.listen((message) {
        if (message is String) {
          _processNotificationAction(actionId: message, payload: null, ref: ref);
        }
      });
    } catch (_) {}

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

    // 2. Setup Android notification channels
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(kTripOfferChannel);
    await androidPlugin?.createNotificationChannel(kInactivityChannel);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    final darwinCategories = <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        'INACTIVITY_CHECK',
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain(
            kActionStayOnline,
            'أنا متاح',
            options: {DarwinNotificationActionOption.foreground},
          ),
          DarwinNotificationAction.plain(
            kActionGoOffline,
            'تحويل إلى غير متصل',
            options: {DarwinNotificationActionOption.destructive},
          ),
        ],
        options: <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
        },
      ),
    ];

    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: darwinCategories,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.actionId != null && response.actionId!.isNotEmpty) {
          await _processNotificationAction(
            actionId: response.actionId,
            payload: response.payload,
            ref: ref,
          );
        } else {
          _handleNotificationTap(ref, response.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
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
      final title = 'طلب رحلة جديد';
      final pickup = (data['pickupAddress'] as String?)?.trim();
      final dropoff = (data['dropoffAddress'] as String?)?.trim();
      final fare = (data['fare'] as String?)?.trim();

      final String body;
      if (dropoff != null && dropoff.isNotEmpty) {
        body = 'الانطلاق: ${pickup ?? "نقطة الانطلاق"}\nالوصول: $dropoff\nالسعر: ${fare ?? ""} دج';
      } else {
        body = 'الانطلاق: ${pickup ?? "نقطة الانطلاق"}\nالسعر: ${fare ?? ""} دج';
      }

      final bigTextStyle = BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'عرض رحلة جديد',
      );

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
            styleInformation: bigTextStyle,
          ),
        ),
        payload: data['tripId'] ?? 'trip_request',
      );
    } else if (type == 'driver_inactivity_check') {
      showInactivityCheckNotification();
    }
  }

  Future<void> showInactivityCheckNotification() async {
    const title = 'هل ما زلت متاحاً للعمل؟';
    const body = 'أنت متصل في وضع الاستعداد منذ 15 دقيقة دون نشاط في التطبيق.';
    try {
      await _localNotifications.show(
        999,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'driver_inactivity_check',
            'Inactivity Reminders',
            channelDescription:
                'Notifications checking if driver is still available',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            actions: [
              AndroidNotificationAction(
                kActionStayOnline,
                'أنا متاح',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                kActionGoOffline,
                'تحويل إلى غير متصل',
                showsUserInterface: false,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'INACTIVITY_CHECK',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'driver_inactivity_check',
      );
    } catch (_) {}
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
      final bigTextStyle = BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'عرض رحلة جديد',
      );
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
            styleInformation: bigTextStyle,
          ),
        ),
        payload: tripId,
      );
    } catch (_) {}
  }
}
