import 'package:flutter/material.dart';
import 'package:tapa_hike/theme.dart';
import 'package:tapa_hike/pages/home.dart';
import 'package:tapa_hike/pages/hike.dart';



void main() {
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
