import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketConnection {
  late final WebSocketChannel channel;
  late final Stream mainStream;

  // sub streams
  late final Stream routeStream;

  SocketConnection () {
      channel = WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:8000/ws/app/'));
      mainStream = channel.stream.map((data) => json.decode(data)).asBroadcastStream();

      routeStream = mainStream.where((data) => data['type'] == 'route').asBroadcastStream();
  }
  
  void sendJson(data) {
    channel.sink.add(json.encode(data));
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
