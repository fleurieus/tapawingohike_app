import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:tapa_hike/theme.dart';
import 'package:workmanager/workmanager.dart';
import 'package:latlong2/latlong.dart';
import 'package:tapa_hike/services/socket.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tapa_hike/services/storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tapa_hike/pages/home.dart';
import 'package:tapa_hike/pages/hike.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
int messageID = 0;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'locationUpdate') {
      return Future.value(sendLocationData(inputData!));
    }

    return Future.value(false);
  });
}

Future<String?> saveToSharedPreferences(String key, String value) async {
  final sharedPreference = await SharedPreferences.getInstance();
  if (value.isNotEmpty) {
    sharedPreference.setString(key, value);
    return value;
  } else {
    return sharedPreference.getString(key);
  }
}

Future<bool> sendLocationData(Map<String, dynamic> inputData) async {
  String? authStr = await saveToSharedPreferences('authStr', inputData['authStr'] ?? '');
  String? destsJson = await saveToSharedPreferences('destsJson', inputData['destsJson'] ?? '');

  if (authStr == null || authStr.isEmpty || destsJson == null || destsJson.isEmpty) {
    return false;
  }

  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    double latitude = position.latitude;
    double longitude = position.longitude;

    SocketConnection workmanagerSocket = SocketConnection();
    await workmanagerSocket.onConnected;

    bool authResult = await workmanagerSocket.authenticate(authStr);
    if (!authResult) {
      return false;
    }

    workmanagerSocket.sendJson({
      "endpoint": "updateLocation",
      "data": {"lat": latitude, "lng": longitude}
    });

    workmanagerSocket.close(4005, "background task leaving");

    // String pingStr = (await LocalStorage.getString("pingStr")) ?? '';

    // if (pingStr == '') {
    //   final LatLng curLocation = LatLng(latitude, longitude);

    //   if (destsJson != '') {
    //     final latLngList = json.decode(destsJson);
    //     for (var latLngMap in latLngList) {
    //       final double? destLatitude = latLngMap['lat'] as double?;
    //       final double? destLongitude = latLngMap['lng'] as double?;

    //       if (destLatitude != null && destLongitude != null) {
    //         final double distance = Geolocator.distanceBetween(
    //           curLocation.latitude,
    //           curLocation.longitude,
    //           destLatitude,
    //           destLongitude,
    //         );

    //         //print('Distance to destination: $distance meters');

    //         if (distance <= 850 && distance >= 50) {
    //           // Notify the user when the distance is 1000 meters or less
    //           await showNotification();

    //           //set pingStr, so it doesn't ping every time
    //           String toStoreHash = generateMd5(json.encode(latLngList));
    //           LocalStorage.saveString("pingStr", toStoreHash);
    //         }
    //       } else {
    //         //print('Invalid latitude or longitude for a destination');
    //       }
    //     }
    //   }
    // }

    return true;
  } catch (e) {
    //print("Error getting location: $e");
    return false;
  }
}

Future<void> showNotification() async {
  //print('showNotification');
  const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails('com.florido.tapa_hike.message', 'TapawingoHike',
      channelDescription: 'TapawingoHike',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification2'),
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public,
      fullScreenIntent: true);

  const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);
  await flutterLocalNotificationsPlugin.show(
    messageID++,
    'Je nadert een post',
    'Gefeliciteerd, je komt in de buurt van een post!',
    notificationDetails,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  await socketConnection.onConnected;

  // final initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  // final initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  // await flutterLocalNotificationsPlugin.initialize(initializationSettings);

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
