import 'dart:async';
import 'dart:convert';

//import 'package:web_socket_channel/web_socket_channel.dart';
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

  final Completer<void> _connectionCompleter = Completer<void>();
  Future<void> get onConnected => _connectionCompleter.future;

  void _initConnection() async {
    final uri = Uri.parse('ws://$domain/ws/app/');
    const backoff = ConstantBackoff(Duration(seconds: 1));
    socket = WebSocket(uri, backoff: backoff);

    await socket.connection.firstWhere((state) => state is Connected);

    socket.connection.listen((state) {
      if (state is Connected) {
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
        final response = await socketConnection.listenOnce(socketConnection.authStream);

        authResult = response["result"] == 1;
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

  void reconnect() {
    socket.close();
    _initConnection();
  }

  SocketConnection() {
    _initConnection();
  }
}

SocketConnection socketConnection = SocketConnection();

// class SocketConnection {
//   late WebSocketChannel channel;
//   late Stream mainStream;
//   late Map channelMapping;
//   String authStr = '';
//   bool authResult = false;

//   final StreamController locationStreamController = StreamController.broadcast();
//   Stream get locationStream => locationStreamController.stream;

//   final StreamController authStreamController = StreamController.broadcast();
//   Stream get authStream => authStreamController.stream;

//   void _initConnection() {
//     channel = WebSocketChannel.connect(Uri.parse('ws://$domain/ws/app/'));

//     mainStream = channel.stream.map((event) => json.decode(event));

//     channelMapping = {
//       "route": locationStreamController,
//       "auth": authStreamController,
//     };

//     mainStream.listen((event) {
//       channelMapping[event["type"]].add(event["data"]);
//     });

//     // Re-authenticate if needed
//     authenticate(authStr);
//   }

//   void reconnect() {
//     channel.sink.close();
//     _initConnection();
//   }

//   SocketConnection() {
//     _initConnection();

//     // Detect when the WebSocket connection is closed
//     channel.sink.done.then((_) {
//       // Attempt to reconnect after a delay
//       Future.delayed(const Duration(seconds: 1), () {
//         reconnect();
//       });
//     });
//   }

//   void sendJson(data) {
//     print('sending json:');
//     print(data);
//     channel.sink.add(json.encode(data));
//   }

//   Future listenOnce(stream) {
//     final completer = Completer();
//     late StreamSubscription subscription;

//     subscription = stream.listen((event) {
//       subscription.cancel();
//       completer.complete(event); // Resolve the Future with the data event
//     });

//     return completer.future;
//   }

//   Future<bool> authenticate(String authString) async {
//     authResult = false;

//     if (authString.isNotEmpty) {
//       sendJson({
//         "endpoint": "authenticate",
//         "data": {
//           "authStr": authString,
//         },
//       });
//       try {
//         final response = await socketConnection.listenOnce(socketConnection.authStream);

//         authResult = response["result"] == 1;
//       } catch (e) {
//         // Handle any errors that might occur during the network call.
//         //print("Error: $e");
//       }
//     }

//     return authResult;
//   }

//   static void closeAndReconnect() {
//     socketConnection.channel.sink.close();
//     socketConnection = SocketConnection();
//   }
// }


