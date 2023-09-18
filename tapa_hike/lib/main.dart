import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:tapa_hike/theme.dart';
import 'package:workmanager/workmanager.dart';
import 'package:latlong2/latlong.dart';
import 'package:tapa_hike/services/socket.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tapa_hike/services/location.dart';
import 'package:tapa_hike/services/storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:tapa_hike/pages/home.dart';
import 'package:tapa_hike/pages/hike.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<bool> sendLocationData() async {
  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    double latitude = position.latitude;
    double longitude = position.longitude;

    SocketConnection mySocketConnection = SocketConnection();
    await mySocketConnection.onConnected;

    String authStr = (await LocalStorage.getString("authStr")) ?? '';

    mySocketConnection.authenticate(authStr);
    mySocketConnection.sendJson({
      "endpoint": "updateLocation",
      "data": {"lat": latitude, "lng": longitude}
    });

    String pingStr = (await LocalStorage.getString("pingStr")) ?? '';

    if (pingStr == '') {
      final LatLng curLocation = LatLng(latitude, longitude);
      final String latLngStr = (await LocalStorage.getString("destinations")) ?? '';

      if (latLngStr != '') {
        final latLngList = json.decode(latLngStr);
        for (var latLngMap in latLngList) {
          final double? destLatitude = latLngMap['lat'] as double?;
          final double? destLongitude = latLngMap['lng'] as double?;

          if (destLatitude != null && destLongitude != null) {
            final double distance = await Geolocator.distanceBetween(
              curLocation.latitude,
              curLocation.longitude,
              destLatitude,
              destLongitude,
            );

            //print('Distance to destination: $distance meters');

            if (distance <= 800) {
              // Notify the user when the distance is 1000 meters or less
              await showNotification();

              //set pingStr, so it doesn't ping every time
              String toStoreHash = generateMd5(json.encode(latLngList));
              LocalStorage.saveString("pingStr", toStoreHash);
            }
          } else {
            //print('Invalid latitude or longitude for a destination');
          }
        }
      }
    }

    return true;
  } catch (e) {
    //print("Error getting location: $e");
    return false;
  }
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'locationUpdate') {
      return Future.value(sendLocationData());
    }
    return Future.value(false);
  });
}

Future<void> showNotification() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails('tapa_hike_101', 'TapawingoHike',
      channelDescription: 'TapawingoHike',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('knock_knock'));

  const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    0,
    'Je nadert een post',
    'Gefeliciteerd, je komt in de buurt van een post!',
    platformChannelSpecifics,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  await socketConnection.onConnected;

  final initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: hikeTheme,
      initialRoute: "/home",
      routes: {
        '/home': (context) => const HomePage(),
        '/hike': (context) => const HikePage(),
      },
    );
  }
}

String generateMd5(String input) {
  return md5.convert(utf8.encode(input)).toString();
}
