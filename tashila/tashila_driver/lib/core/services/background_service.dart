import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:geolocator/geolocator.dart';
import 'package:tashila_driver/core/config/api_config.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

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
  final backgroundNotifications = FlutterLocalNotificationsPlugin();

  io.Socket? socket;
  Timer? checkinTimer;

  void cleanup() {
    if (socket != null) {
      socket!.emit('driver:offline', {});
      socket!.disconnect();
      socket = null;
    }
    checkinTimer?.cancel();
    checkinTimer = null;
  }

  void connectSocket(String token) {
    if (socket != null && socket!.connected) return;

    socket = io.io(
      kApiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .enableReconnection()
          .build(),
    );

    socket!.onConnect((_) {
      socket!.emit('driver:online', {});
    });

    socket!.on('driver:trip_request', (data) async {
      try {
        FlutterRingtonePlayer().play(
          android: AndroidSounds.ringtone,
          ios: IosSounds.glass,
          looping: false,
          volume: 1.0,
        );
      } catch (_) {}

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'ride_offer_channel',
        'Ride Offers',
        channelDescription: 'Notifications for incoming ride requests.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await backgroundNotifications.show(
        101,
        'New Trip Request Available!',
        'A client requested a trip near you. Open the app to accept.',
        details,
      );
    });
  }

  checkinTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final isAuthenticated = prefs.getBool('driver_session') ?? false;
    final availability = prefs.getString('driver_availability') ?? 'offline';
    final token = prefs.getString('accessToken') ?? '';

    if (isAuthenticated && availability == 'online' && token.isNotEmpty) {
      connectSocket(token);

      try {
        final hasPermission = await Geolocator.checkPermission();
        if (hasPermission == LocationPermission.always ||
            hasPermission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          if (socket != null && socket!.connected) {
            socket!.emit('driver:location_update', {
              'lat': pos.latitude,
              'lng': pos.longitude,
              'heading': pos.heading,
              'speed': pos.speed,
            });
          }
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
