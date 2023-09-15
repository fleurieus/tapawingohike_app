import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

const String domain = "116.203.112.220:80"; // "127.0.0.1:8000";

class SocketConnection {
  late WebSocketChannel channel;
  late Stream mainStream;
  late Map channelMapping;
  String authStr = '';

  final StreamController locationStreamController = StreamController.broadcast();
  Stream get locationStream => locationStreamController.stream;

  void _initConnection() {
    channel = WebSocketChannel.connect(Uri.parse('ws://$domain/ws/app/'));

    mainStream = channel.stream.map((event) => json.decode(event));

    channelMapping = {
      "route": locationStreamController,
    };

    mainStream.listen((event) {
      channelMapping[event["type"]].add(event["data"]);
    });

    // Re-authenticate if needed
    authenticate(authStr);
  }

  void reconnect() {
    channel.sink.close();
    _initConnection();
  }


  SocketConnection() {
    _initConnection();

    // Detect when the WebSocket connection is closed
    channel.sink.done.then((_) {
      // Attempt to reconnect after a delay
      Future.delayed(const Duration(seconds: 1), () {
        reconnect();
      });
    });
  }

  void sendJson(data) {
    channel.sink.add(json.encode(data));
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

  void authenticate(String authString) {
    authStr = authString;
    if( authStr.isNotEmpty ) {          
      sendJson({
        "endpoint": "authenticate",
        "data": {
          "authStr": authStr,
        },
      });
    }
  }

  static void closeAndReconnect() {
    socketConnection.channel.sink.close();
    socketConnection = SocketConnection();
  }
}

SocketConnection socketConnection = SocketConnection();
