import 'package:flutter/material.dart';
import 'package:tapa_hike/theme.dart';
import 'package:workmanager/workmanager.dart';
import 'package:latlong2/latlong.dart';
import 'package:tapa_hike/services/socket.dart';
import 'package:tapa_hike/services/location.dart';

import 'package:tapa_hike/pages/home.dart';
import 'package:tapa_hike/pages/hike.dart';




void sendLastLocationData() {
  // Assuming you have access to the necessary data (lastLocation) here
  late LatLng lastLocation;
print( 'Send last location called');
  currentLocationStream.listen((location) {
    lastLocation = location;
    // Implement your logic for sending last location data here
    socketConnection.sendJson({
      "endpoint": "updateLocation",
      "data": {
        "lat": lastLocation.latitude,
        "lng": lastLocation.longitude,
      },
    });
  });    
}

void callbackDispatcher() {
  
  Workmanager().executeTask((task, inputData) {
    if (task == 'locationUpdate') {
      sendLastLocationData();
    }

    return Future.value(true);
  });

  runApp(MyApp());
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: hikeTheme,
      initialRoute: "/home",
      routes: {
        '/home': (context) => HomePage(),
        '/hike': (context) => HikePage(),
      },
    );
  }
}
