import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:tashila_client/core/config/api_config.dart';
import 'package:tashila_client/core/services/api_client.dart';

typedef TripSocketCallback = void Function(Map<String, dynamic> data);

class TripSocketService {
  TripSocketService(this._apiClient);

  final ApiClient _apiClient;
  io.Socket? _socket;
  Completer<bool>? _connectCompleter;
  String? _pendingJoinTripId;
  bool _intentionalDisconnect = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  TripSocketCallback? _onDriverAssigned;
  TripSocketCallback? _onStatusChanged;
  TripSocketCallback? _onNoDrivers;
  TripSocketCallback? _onDriverLocation;

  Future<bool> connect({
    TripSocketCallback? onDriverAssigned,
    TripSocketCallback? onStatusChanged,
    TripSocketCallback? onNoDrivers,
    TripSocketCallback? onDriverLocation,
  }) async {
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();
    _onDriverAssigned = onDriverAssigned;
    _onStatusChanged = onStatusChanged;
    _onNoDrivers = onNoDrivers;
    _onDriverLocation = onDriverLocation;
    return _openSocket();
  }

  Future<bool> _openSocket() async {
    _socket?.dispose();
    _socket = null;
    _connectCompleter = null;

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
        _reconnectAttempt = 0;
        final pending = _pendingJoinTripId;
        if (pending != null) {
          _socket?.emit('trip:join', {'tripId': pending});
          _pendingJoinTripId = null;
        }
        final completer = _connectCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(true);
        }
      })
      ..onConnectError((_) {
        final completer = _connectCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(false);
        }
      })
      ..onDisconnect((_) {
        if (_intentionalDisconnect) return;
        _scheduleReconnect();
      })
      ..on('trip:driver_assigned', (data) {
        if (data is Map) {
          _onDriverAssigned?.call(Map<String, dynamic>.from(data));
        }
      })
      ..on('trip:status_changed', (data) {
        if (data is Map) {
          _onStatusChanged?.call(Map<String, dynamic>.from(data));
        }
      })
      ..on('trip:no_drivers_found', (data) {
        if (data is Map) _onNoDrivers?.call(Map<String, dynamic>.from(data));
      })
      ..on('trip:driver_location', (data) {
        if (data is Map) {
          _onDriverLocation?.call(Map<String, dynamic>.from(data));
        }
      });

    try {
      return await _connectCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    _reconnectTimer?.cancel();
    final delaySeconds = (2 << _reconnectAttempt).clamp(2, 30);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_intentionalDisconnect) return;
      unawaited(_openSocket());
    });
  }

  Future<void> joinTrip(String tripId) async {
    if (_socket?.connected == true) {
      _socket?.emit('trip:join', {'tripId': tripId});
      return;
    }
    _pendingJoinTripId = tripId;
  }

  void leaveTrip(String tripId) {
    _socket?.emit('trip:leave', {'tripId': tripId});
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _pendingJoinTripId = null;
    _connectCompleter = null;
    _socket?.dispose();
    _socket = null;
  }
}
