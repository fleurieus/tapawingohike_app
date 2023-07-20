import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:tapa_hike/services/socket.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Authenticatie'),
      ),
      body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
          child: TextFormField(
            decoration: const InputDecoration(
              border: UnderlineInputBorder(),
              labelText: 'TEAM ID',
            ),
            onFieldSubmitted: (authStr) async {
              socketConnection.authenticate(authStr);
              var serviceEnabled = await Geolocator.isLocationServiceEnabled();
              var permission = await Geolocator.checkPermission();
              if (!serviceEnabled || ([
                LocationPermission.denied,
                LocationPermission.deniedForever,
                LocationPermission.unableToDetermine
              ].contains(permission))) {
                // niet de juiste locatie permisies
                return;
              }
              Navigator.pushReplacementNamed(context, "/hike");
            },
          ),
        ),
    );
  }
}