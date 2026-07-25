import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:tashila_driver/core/config/api_config.dart';
import 'package:tashila_driver/core/services/api_client.dart';

typedef DriverSocketCallback = void Function(Map<String, dynamic> data);

class DriverSocketService {
  DriverSocketService(this._apiClient);

  final ApiClient _apiClient;
  io.Socket? _socket;
  bool _pendingOnline = false;
  Completer<bool>? _connectCompleter;

  Future<bool> connect({
    DriverSocketCallback? onTripRequest,
    DriverSocketCallback? onOfferExpired,
    DriverSocketCallback? onTripCancelled,
    DriverSocketCallback? onTripError,
    void Function()? onReconnect,
  }) async {
    await disconnect();
    final token = await _apiClient.getAccessToken();
    if (token == null) return false;

    _connectCompleter = Completer<bool>();
    _socket = io.io(
      kApiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        if (_pendingOnline) {
          _socket?.emit('driver:online', {});
          _pendingOnline = false;
        }
        final completer = _connectCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(true);
        } else {
          onReconnect?.call();
        }
      })
      ..onConnectError((_) {
        final completer = _connectCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(false);
        }
      })
      ..on('driver:trip_request', (data) {
        if (data is Map) onTripRequest?.call(Map<String, dynamic>.from(data));
      })
      ..on('driver:offer_expired', (data) {
        if (data is Map) onOfferExpired?.call(Map<String, dynamic>.from(data));
      })
      ..on('driver:trip_cancelled', (data) {
        if (data is Map) onTripCancelled?.call(Map<String, dynamic>.from(data));
      })
      ..on('trip:error', (data) {
        if (data is Map) onTripError?.call(Map<String, dynamic>.from(data));
      });

    try {
      return await _connectCompleter!.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      return false;
    }
  }

  void setOnline(bool online) {
    if (online) {
      if (_socket?.connected == true) {
        _socket?.emit('driver:online', {});
        _pendingOnline = false;
      } else {
        _pendingOnline = true;
      }
      return;
    }
    _pendingOnline = false;
    _socket?.emit('driver:offline', {});
  }

  void sendLocation({
    required double lat,
    required double lng,
    double heading = 0,
    double speed = 0,
  }) {
    _socket?.emit('driver:location_update', {
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
    });
  }

  void respondToTrip(String tripId, {required bool accepted}) {
    _socket?.emit('driver:trip_request_response', {
      'tripId': tripId,
      'accepted': accepted,
    });
  }

  void joinTrip(String tripId) {
    _socket?.emit('trip:join', {'tripId': tripId});
  }

  void leaveTrip(String tripId) {
    _socket?.emit('trip:leave', {'tripId': tripId});
  }

  void updateTripStatus(String tripId, String status) {
    _socket?.emit('trip:status_update', {
      'tripId': tripId,
      'status': status,
    });
  }

  Future<void> disconnect() async {
    _pendingOnline = false;
    _connectCompleter = null;
    _socket?.dispose();
    _socket = null;
  }
}
