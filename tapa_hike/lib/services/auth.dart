// lib/services/auth.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tapa_hike/services/socket.dart';
import 'package:tapa_hike/services/storage.dart';

// Centraliseer login + permissies hier, zodat zowel HomePage als HikePage dit kan gebruiken.
Future<void> loginAndPermissions(String authStr, BuildContext context) async {
  // 1) Auth opslaan, zodat herlogin kan zonder opnieuw in te voeren
  await LocalStorage.saveString("authStr", authStr);

  // 2) Locatie permissies vragen indien nodig
  var serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Je kunt hier optioneel een dialoog tonen of settings openen
    // await Geolocator.openLocationSettings();
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  // 3) Socket verbinden en aanmelden bij jouw backend
  // Pas dit aan naar jouw bestaande login-protocol
  SocketConnection.closeAndReconnect();
  await Future.delayed(const Duration(milliseconds: 250));
  socketConnection.sendJson({'endpoint': 'login', 'authStr': authStr});

  // Eventueel wachten op bevestiging kan hier
  // final ok = await socketConnection.awaitLoginAck();
  // if (!ok) throw Exception('Login mislukt');
}

// Herlogin met bewaarde auth, zonder auth te verwijderen.
Future<void> reLoginWithStoredAuth(BuildContext context) async {
  final authStr = await LocalStorage.getString("authStr");
  if (authStr == null || authStr.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Geen opgeslagen teamcode gevonden.')),
    );
    return;
  }
  await loginAndPermissions(authStr, context);
}
