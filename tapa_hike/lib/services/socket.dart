import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

const String domain = "116.203.112.220:80"; // "127.0.0.1:8000";

class SocketConnection {
  late final WebSocketChannel channel;
  late final Stream mainStream;
  late final Map channelMapping;

  final StreamController locationStreamController = StreamController.broadcast();
  get locationStream => locationStreamController.stream;

    
    


  SocketConnection () {
    channel = WebSocketChannel.connect(Uri.parse('ws://$domain/ws/app/'));
    mainStream = channel.stream.map((event) => json.decode(event));
    
    channelMapping = {
      "route": locationStreamController,
    };
    
    mainStream.listen((event) {
      channelMapping[event["type"]].add(event["data"]);
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
