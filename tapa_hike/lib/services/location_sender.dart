import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'package:tapa_hike/services/socket.dart';
import 'package:tapa_hike/services/location.dart';

/// Periodically sends the device's GPS position to the server.
///
/// Uses the existing [positionStream] (foreground service) and sends
/// updates at a configurable interval via WebSocket.
class LocationSender {
  LocationSender._();
  static final LocationSender instance = LocationSender._();

  Timer? _timer;
  Position? _lastPosition;
  StreamSubscription<Position>? _positionSub;
  int _intervalSeconds = 300; // default 5 minutes
  bool _running = false;

  bool get isRunning => _running;
  int get intervalSeconds => _intervalSeconds;

  /// Start sending location updates every [seconds] seconds.
  void start(int seconds) {
    if (_running) stop();
    _intervalSeconds = seconds;
    _running = true;

    // Track the latest position from the shared stream
    _positionSub = positionStream.listen((Position pos) {
      _lastPosition = pos;
    });

    // Send immediately, then repeat
    _sendLocation();
    _timer = Timer.periodic(Duration(seconds: _intervalSeconds), (_) {
      _sendLocation();
    });
  }

  /// Update the sending interval without restarting the position listener.
  void updateInterval(int seconds) {
    if (seconds == _intervalSeconds) return;
    _intervalSeconds = seconds;

    // Restart the timer with the new interval
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: _intervalSeconds), (_) {
      _sendLocation();
    });
  }

  /// Stop sending location updates.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _lastPosition = null;
    _running = false;
  }

  void _sendLocation() {
    final pos = _lastPosition;
    if (pos == null) return;

    socketConnection.sendJson({
      "endpoint": "updateLocation",
      "data": {
        "lat": pos.latitude,
        "lng": pos.longitude,
      },
    });
  }
}
