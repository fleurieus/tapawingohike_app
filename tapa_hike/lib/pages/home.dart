import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tapa_hike/services/socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _authStrController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkAndLogin();
  }

  Future<void> loginAndPermissions(String authStr) async {
    socketConnection.authenticate(authStr);
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    if (!serviceEnabled ||
        ([
          LocationPermission.denied,
          LocationPermission.deniedForever,
          LocationPermission.unableToDetermine,
        ].contains(permission))) {
      await Geolocator.requestPermission();
    }
    SharedPreferences localStore = await SharedPreferences.getInstance();
    localStore.setString("authStr", authStr);
    Navigator.pushReplacementNamed(context, "/hike");
  }

  Future<void> checkAndLogin() async {
    SharedPreferences localStore = await SharedPreferences.getInstance();
    String authStr = localStore.getString("authStr") ?? '';

    if (authStr.isNotEmpty) {
      loginAndPermissions(authStr);
    }
  }

  @override
  void dispose() {
    _authStrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login bij TapawingoHike 2023'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Column(
          children: [
            TextFormField(
              controller: _authStrController,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                labelText: 'Login met jouw teamcode',
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String authStr = _authStrController.text.trim();
                if (authStr.isNotEmpty) {
                  loginAndPermissions(authStr);
                }
              },
              child: Text('Inloggen'),
            ),
          ],
        ),
      ),
    );
  }
}
