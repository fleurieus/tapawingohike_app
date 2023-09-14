import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tapa_hike/services/socket.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _authStrController = TextEditingController();
  BuildContext? _context; // Initialized as null

  @override
  void initState() {
    super.initState();
    checkAndLogin();
  }

  @override
  void dispose() {
    _authStrController.dispose();
    super.dispose();
  }

  Future<void> login(String authStr) async {
    try {
      bool authResult = await socketConnection.authenticate(authStr);

      if (authResult) {
        await saveAuthStringToLocalStorage(authStr);
        navigateToHikePage();
      } else {
        // Display a dialog when authentication fails
        showLoginFailed();
      }
    } catch (e) {
      // Handle any errors that might occur during authentication or storage.
      //print("Error: $e");
      // Optionally, you can show an error message to the user.
    }
  }

  Future<void> saveAuthStringToLocalStorage(String authStr) async {
    SharedPreferences localStore = await SharedPreferences.getInstance();
    await localStore.setString("authStr", authStr);
  }

  void navigateToHikePage() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/hike");
    }
  }

  void showLoginFailed() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Inloggen niet gelukt"),
          content: Text("Controleer of de teamcode correct is ingevoerd en probeer opnieuw."),
          actions: <Widget>[
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> loginAndPermissions(String authStr, BuildContext context) async {
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();

    if (!serviceEnabled ||
        ([
          LocationPermission.denied,
          LocationPermission.deniedForever,
          LocationPermission.unableToDetermine,
        ].contains(permission))) {
      bool shouldRequestPermissions = await showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text("Location Permissions"),
            content: const Text(
                "Deze app verzamelt uw locatiegegevens om u te voorzien van de juiste route informatie. Dit gebeurt ook als de app gesloten is. Zodra u uitlogt stopt het verzamelen van locatiegegevens. Geef in het volgende dialoog toestemming voor het gebruik van uw locatiegegevens."),
            actions: <Widget>[
              TextButton(
                child: const Text("Cancel"),
                onPressed: () {
                  if (mounted) {
                    Navigator.of(context).pop(false); // Return false when Cancel is pressed
                  }
                },
              ),
              TextButton(
                child: const Text("OK"),
                onPressed: () async {
                  if (mounted) {
                    Navigator.of(context).pop(true); // Return true when OK is pressed
                    //await Geolocator.requestPermission();
                  }
                },
              ),
            ],
          );
        },
      );

      if (shouldRequestPermissions) {
        // Request location permissions
        //await Geolocator.requestPermission();
        //login(authStr);
        var permissionStatus = await Geolocator.requestPermission();
        if (permissionStatus == LocationPermission.always || permissionStatus == LocationPermission.whileInUse) {
          login(authStr);
        }
      }
    } else {
      // Permissions are already granted, proceed with login
      login(authStr);
    }
  }

  Future<void> checkAndLogin() async {
    SharedPreferences localStore = await SharedPreferences.getInstance();
    String authStr = localStore.getString("authStr") ?? '';

    if (authStr.isNotEmpty) {
      login(authStr);
    }
  }

  @override
  Widget build(BuildContext context) {
    _context = context; // Assign context when the widget is built

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login bij TapawingoHike 2023'),
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
              onFieldSubmitted: (value) {
                String authStr = value.trim();
                if (authStr.isNotEmpty) {
                  loginAndPermissions(authStr, _context!);
                }
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String authStr = _authStrController.text.trim();
                if (authStr.isNotEmpty) {
                  loginAndPermissions(authStr, _context!);
                }
              },
              child: const Text('Inloggen'),
            ),
          ],
        ),
      ),
    );
  }
}
