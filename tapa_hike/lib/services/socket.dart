import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_client/web_socket_client.dart';

import 'package:tapa_hike/services/location_sender.dart';

// Server hostname:port. Production is the default; override per-run with
//   flutter run --dart-define=WS_DOMAIN=10.0.2.2:8000      (Android emulator)
//   flutter run --dart-define=WS_DOMAIN=127.0.0.1:8000     (iOS sim / host)
// _isLocalDomain below detects the local hosts and switches to plain ws/http.
const String domain = String.fromEnvironment(
  "WS_DOMAIN",
  defaultValue: "app.tapawingo.nl",
);

// Use TLS for any non-localhost host. Required by iOS App Transport Security
// and Android's network security config for production traffic.
bool get _isLocalDomain =>
    domain.startsWith('127.0.0.1') ||
    domain.startsWith('localhost') ||
    domain.startsWith('10.0.2.2'); // Android emulator host
String get wsScheme => _isLocalDomain ? 'ws' : 'wss';
String get httpScheme => _isLocalDomain ? 'http' : 'https';

class SocketConnection {
  late WebSocket socket;
  late Stream mainStream;
  late Map channelMapping;
  String authStr = '';
  bool authResult = false;
  bool messagingEnabled = false;

  final StreamController locationStreamController = StreamController.broadcast();
  Stream get locationStream => locationStreamController.stream;

  final StreamController authStreamController = StreamController.broadcast();
  Stream get authStream => authStreamController.stream;

  final StreamController configStreamController = StreamController.broadcast();
  Stream get configStream => configStreamController.stream;

  final StreamController messageStreamController = StreamController.broadcast();
  Stream get messageStream => messageStreamController.stream;

  final Completer<void> _connectionCompleter = Completer<void>();
  StreamSubscription? _configSubscription;

  /// Fires once on the very first successful connection and stays completed
  /// forever after. DO NOT use this to gate a send/auth after a reconnect —
  /// use [waitUntilConnected] which reflects the live socket state.
  Future<void> get onConnected => _connectionCompleter.future;

  /// Wait until the underlying socket is actually in a Connected/Reconnected
  /// state. Unlike [onConnected] this checks the live connection.state stream
  /// every time, so it's safe to call after a reconnect or screen-resume.
  Future<void> waitUntilConnected({Duration timeout = const Duration(seconds: 5)}) async {
    final current = socket.connection.state;
    if (current is Connected || current is Reconnected) return;

    await socket.connection
        .firstWhere((state) => state is Connected || state is Reconnected)
        .timeout(timeout);
  }

  void _initConnection() async {
    final uri = Uri.parse('$wsScheme://$domain/ws/app/');
    const backoff = ConstantBackoff(Duration(seconds: 1));
    socket = WebSocket(uri, backoff: backoff);

    // Wait for initial connection (Connected) or reconnection (Reconnected)
    await socket.connection.firstWhere(
      (state) => state is Connected || state is Reconnected,
    );

    // Complete immediately — we know the socket is connected
    if (!_connectionCompleter.isCompleted) {
      _connectionCompleter.complete();
    }

    mainStream = socket.messages.map((event) => json.decode(event));

    channelMapping = {
      "route": locationStreamController,
      "auth": authStreamController,
      "config": configStreamController,
      "message": messageStreamController,
      "messageHistory": messageStreamController,
    };

    mainStream.listen((event) {
      final type = event["type"];
      final controller = channelMapping[type];
      if (controller == null) {
        debugPrint('[socket] unrouted message type=$type');
        return;
      }
      debugPrint('[socket] message type=$type');
      controller.add(event["data"]);
    });
  }

  getStatus() {
    return socket.connection.state;
  }

  isAuthenticated() {
    return authResult;
  }

  void sendJson(data) {
    final state = socket.connection.state;
    final endpoint = (data is Map) ? data['endpoint'] : '?';
    debugPrint('[socket] sendJson endpoint=$endpoint state=$state authResult=$authResult');
    socket.send(json.encode(data));
  }

  Future<T> listenOnce<T>(Stream<T> stream, {Duration? timeout}) {
    final completer = Completer<T>();
    late StreamSubscription<T> subscription;

    subscription = stream.listen((event) {
      subscription.cancel();
      if (!completer.isCompleted) {
        completer.complete(event);
      }
    });

    if (timeout != null) {
      Future.delayed(timeout, () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.completeError(
            TimeoutException('No response received', timeout),
          );
        }
      });
    }

    return completer.future;
  }

  Future<bool> authenticate(String authString) async {
    authResult = false;

    if (authString.isNotEmpty) {
      // Ensure the socket is connected before sending
      await onConnected.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );

      sendJson({
        "endpoint": "authenticate",
        "data": {
          "authStr": authString,
        },
      });
      try {
        final response = await listenOnce(
          authStream,
          timeout: const Duration(seconds: 10),
        );
        authResult = response["result"] == 1;
        if (authResult) {
          authStr = authString;
          messagingEnabled = response["messagingEnabled"] == true;

          // Start location sender with server-provided interval
          final interval = response["locationInterval"] as int? ?? 300;
          LocationSender.instance.start(interval);

          // Listen for dynamic interval updates (cancel previous subscription)
          _configSubscription?.cancel();
          _configSubscription = configStream.listen((event) {
            if (event["locationInterval"] != null) {
              LocationSender.instance.updateInterval(
                event["locationInterval"] as int,
              );
            }
          });
        }
      } catch (e) {
        // Auth failed or timed out
      }
    }

    return authResult;
  }

  static void closeAndReconnect() {
    socketConnection._configSubscription?.cancel();
    socketConnection.socket.close();
    socketConnection = SocketConnection();
  }

  void close(int? closeCode, String? closeString) {
    _configSubscription?.cancel();
    socket.close(closeCode, closeString);
  }

  void reconnect() {
    debugPrint('[socket] reconnect() — dropping current socket');
    // The server drops the session as soon as the WebSocket closes, so any
    // cached auth on this client is stale. Force re-auth on the next request.
    authResult = false;
    socket.close();
    _initConnection();
  }

  SocketConnection() {
    _initConnection();
  }
}

SocketConnection socketConnection = SocketConnection();
