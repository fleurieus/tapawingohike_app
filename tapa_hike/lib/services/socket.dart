import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class SocketConnection {
  late final WebSocketChannel channel;
  late final Stream mainStream;

  final StreamController locationStreamController = StreamController.broadcast();
  get locationStream => locationStreamController.stream;


  SocketConnection () {
    channel = WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:8000/ws/app/'));
    mainStream = channel.stream.map((event) => json.decode(event));
    
    final Map channelMapping = {
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
      "type": "authenticate",
      "data": {
        "authStr": authStr.toString(),
      },
    });
  }
}

SocketConnection socketConnection = SocketConnection();
