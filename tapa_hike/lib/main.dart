import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tapa_hike/theme.dart';
import 'package:workmanager/workmanager.dart';
import 'package:latlong2/latlong.dart';
import 'package:tapa_hike/services/socket.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tapa_hike/services/location.dart';

import 'package:tapa_hike/pages/home.dart';
import 'package:tapa_hike/pages/hike.dart';




void sendLastLocationData() {
  Stream bgLocationStream = Geolocator.getPositionStream(locationSettings: locationSettings).map(
    (Position position) => positionToLatLng(position)
  ).asBroadcastStream();

  late StreamSubscription subscription;

  subscription = bgLocationStream.listen((location) {
    print({
      "endpoint": "updateLocation",
      "data": {
        "lat": location.latitude,
        "lng": location.longitude
      }
    });
    socketConnection.sendJson({
      "endpoint": "updateLocation",
      "data": {
        "lat": location.latitude,
        "lng": location.longitude
      }
    });    
    subscription.cancel();
  });  
  
}

void callbackDispatcher() {
  print('callback dispatching');
  Workmanager().executeTask((task, inputData) async {
    
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
  MyApp({super.key});
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
