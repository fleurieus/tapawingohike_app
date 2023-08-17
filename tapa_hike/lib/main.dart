import 'package:flutter/material.dart';
import 'package:tapa_hike/theme.dart';
import 'package:workmanager/workmanager.dart';

import 'package:tapa_hike/pages/home.dart';
import 'package:tapa_hike/pages/hike.dart';


void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    final Function taskFunction = Function.apply(Function.apply((){
      return () {};
    }, []), []);

    taskFunction();
    return Future.value(true);
  });

  runApp(MyApp());
}
void main() {
  runApp(MyApp());
  Workmanager().initialize(callbackDispatcher);
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
