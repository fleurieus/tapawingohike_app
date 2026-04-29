import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:tapa_hike/theme.dart';
import 'package:tapa_hike/services/socket.dart';

import 'package:tapa_hike/pages/home.dart';
import 'package:tapa_hike/pages/hike.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On iOS, configure the audio session so the destination chime can play
  // while the app is in the background or the device is locked. Android
  // handles this via the foreground service notification.
  if (Platform.isIOS) {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
    ));
  }

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
