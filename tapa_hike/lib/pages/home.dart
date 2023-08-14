import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tapa_hike/services/socket.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    String authStr = ''; // Declare the authStr variable

    return Scaffold(
      appBar: AppBar(
        title: Text('Authenticatie'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                labelText: 'Login met jouw teamcode',
              ),
              onChanged: (value) {
                authStr = value; // Update the authStr when the text changes
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Add your submission logic here using the authStr variable
                socketConnection.authenticate(authStr);
                var serviceEnabled = await Geolocator.isLocationServiceEnabled();
                var permission = await Geolocator.checkPermission();
                if (!serviceEnabled ||
                    ([
                      LocationPermission.denied,
                      LocationPermission.deniedForever,
                      LocationPermission.unableToDetermine,
                    ].contains(permission))) {
                  // niet de juiste locatie permissions
                  await Geolocator.requestPermission();
                }
                Navigator.pushReplacementNamed(context, "/hike");
              },
              child: Text('Inloggen'),
            ),
          ],
        ),
      ),
    );
  }
}
