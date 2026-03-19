import 'package:flutter/material.dart';
import 'package:tapa_hike/theme.dart';
import 'package:tapa_hike/services/socket.dart';

import 'package:tapa_hike/pages/home.dart';
import 'package:tapa_hike/pages/hike.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await socketConnection.onConnected;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: hikeTheme,
      darkTheme: hikeDarkTheme,
      themeMode: ThemeMode.system,
      initialRoute: "/home",
      routes: {
        '/home': (context) => const HomePage(),
        '/hike': (context) => const HikePage(),
      },
    );
  }
}
