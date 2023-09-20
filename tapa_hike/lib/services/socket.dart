import 'dart:async';
import 'dart:convert';

import 'package:web_socket_client/web_socket_client.dart';

const String domain = "116.203.112.220:80"; // "127.0.0.1:8000";

class SocketConnection {
  late WebSocket socket;
  late Stream mainStream;
  late Map channelMapping;
  String authStr = '';
  bool authResult = false;

  final StreamController locationStreamController = StreamController.broadcast();
  Stream get locationStream => locationStreamController.stream;

  final StreamController authStreamController = StreamController.broadcast();
  Stream get authStream => authStreamController.stream;

  final Completer<void> _connectionCompleter = Completer<void>(); // Initialize here

  Future<void> get onConnected => _connectionCompleter.future;

  void _initConnection() async {
    final uri = Uri.parse('ws://$domain/ws/app/');
    const backoff = ConstantBackoff(Duration(seconds: 1));
    socket = WebSocket(uri, backoff: backoff);

    await socket.connection.firstWhere((state) => state is Connected);

    socket.connection.listen((state) {
      if (state is Connected && !_connectionCompleter.isCompleted) {
        _connectionCompleter.complete();
      }
    });

    mainStream = socket.messages.map((event) => json.decode(event));

    channelMapping = {
      "route": locationStreamController,
      "auth": authStreamController,
    };

    mainStream.listen((event) {
      channelMapping[event["type"]].add(event["data"]);
    });

    // Re-authenticate if needed
    authenticate(authStr);
  }

  getStatus() {
    return socket.connection.state;
  }

  isAuthenticated() {
    return authResult;
  }

  void sendJson(data) {
    socket.send(json.encode(data));
  }

  Future listenOnce(stream) {
    final completer = Completer();
    late StreamSubscription subscription;

    subscription = stream.listen((event) {
      subscription.cancel();
      completer.complete(event); // Resolve the Future with the data event
    });

    return completer.future;
  }

  Future<bool> authenticate(String authString) async {
    authResult = false;

    if (authString.isNotEmpty) {
      sendJson({
        "endpoint": "authenticate",
        "data": {
          "authStr": authString,
        },
      });
      try {
        final response = await listenOnce(authStream);
        authResult = response["result"] == 1;
        if (authResult) {
          authStr = authString;
        }
      } catch (e) {
        // Handle any errors that might occur during the network call.
        //print("Error: $e");
      }
    }

    return authResult;
  }

  static void closeAndReconnect() {
    socketConnection.socket.close();
    socketConnection = SocketConnection();
  }

  void close(int? closeCode, String? closeString) {
    socket.close(closeCode, closeString);
  }

  void reconnect() {
    socket.close();
    _initConnection();
  }

  SocketConnection() {
    _initConnection();
  }
}

SocketConnection socketConnection = SocketConnection();
