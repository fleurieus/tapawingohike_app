import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

const String domain = "116.203.112.220:80"; // "127.0.0.1:8000";

class SocketConnection {
  late final WebSocketChannel channel;
  late final Stream mainStream;
  late final Map channelMapping;
  final String authStr = '';

  final StreamController locationStreamController = StreamController.broadcast();
  get locationStream => locationStreamController.stream;

    
  static void reconnect() {
    channel = WebSocketChannel.connect(Uri.parse('ws://$domain/ws/app/'));

    mainStream = channel.stream.map((event) => json.decode(event));

    mainStream.listen((event) {
      channelMapping[event["type"]].add(event["data"]);
    });

    // Re-authenticate if needed
    authenticate(authStr);
  } 
  
     

  bool isConnected() {
    return channel.sink.done == null;
  }

  SocketConnection () {
    channel = WebSocketChannel.connect(Uri.parse('ws://$domain/ws/app/'));
    mainStream = channel.stream.map((event) => json.decode(event));
    
    channelMapping = {
      "route": locationStreamController,
    };
    
    mainStream.listen((event) {
      channelMapping[event["type"]].add(event["data"]);
    });

    // Detect when the WebSocket connection is closed
    channel.sink.done.then((_) {
      // Attempt to reconnect after a delay
      Future.delayed(const Duration(seconds: 5), () {
        _reconnect();
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

  void authenticate(authStr) {
    authStr = authStr;

    sendJson({
      "endpoint": "authenticate",
      "data": {
        "authStr": authStr.toString(),
      },
    });
  }

  static void closeAndReconnect() {
    socketConnection.channel.sink.close();
    socketConnection = SocketConnection(); // Re-create the instance
  }

}

SocketConnection socketConnection = SocketConnection();
