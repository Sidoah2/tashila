import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tashila_driver/core/config/api_config.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'driver_service_channel',
    'Tashila Driver Background Service',
    description: 'Keeps driver socket active and tracks locations.',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'driver_service_channel',
      initialNotificationTitle: 'Tashila Driver Active',
      initialNotificationContent: 'Ready to receive ride offers',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  Timer? checkinTimer;
  final dio = Dio(
    BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  void cleanup() {
    checkinTimer?.cancel();
    checkinTimer = null;
  }

  // Periodic background location update via HTTP (preserves battery, avoids duplicate Socket.IO)
  checkinTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final isAuthenticated = prefs.getBool('driver_session') ?? false;
    final availability = prefs.getString('driver_availability') ?? 'offline';
    final token = prefs.getString('accessToken') ?? '';

    if (isAuthenticated && availability == 'online' && token.isNotEmpty) {
      try {
        final hasPermission = await Geolocator.checkPermission();
        if (hasPermission == LocationPermission.always ||
            hasPermission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
          await dio.put<Map<String, dynamic>>(
            '/drivers/me/location',
            data: {
              'lat': pos.latitude,
              'lng': pos.longitude,
              'heading': pos.heading,
              'speed': pos.speed,
            },
            options: Options(
              headers: {'Authorization': 'Bearer $token'},
            ),
          );
        }
      } catch (_) {}
    } else {
      cleanup();
      service.stopSelf();
    }
  });

  service.on('stopService').listen((event) {
    cleanup();
    service.stopSelf();
  });
}
