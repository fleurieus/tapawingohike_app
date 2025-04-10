import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:tapa_hike/main.dart';
import 'package:wakelock/wakelock.dart';

import 'package:tapa_hike/pages/home.dart';

import 'package:tapa_hike/services/socket.dart';
import 'package:tapa_hike/services/location.dart';
import 'package:tapa_hike/services/storage.dart';

import 'package:workmanager/workmanager.dart';

import 'package:tapa_hike/widgets/loading.dart';
import 'package:tapa_hike/widgets/routes.dart';

class HikePage extends StatefulWidget {
  const HikePage({super.key});

  @override
  State<HikePage> createState() => _HikePageState();
}

class _HikePageState extends State<HikePage> with WidgetsBindingObserver {
  Map? hikeData;
  int? reachedLocationId;
  List destinations = [];
  bool showConfirm = false;
  bool keepScreenOn = false;
  bool showUndo = false;
  late LatLng lastLocation;
  String destsJson = '';
  String storedDestHash = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      //reconnect
      socketConnection.reconnect();
    }
  }

  @override
  void didUpdateWidget(covariant HikePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    fetchStoredDestHash(); // Call the asynchronous function when the widget is updated
  }

  Future<void> fetchStoredDestHash() async {
    String pingStr = await LocalStorage.getString("pingStr") ?? '';
    setState(() {
      storedDestHash = pingStr; // Update the state variable
    });
  }

  void _startBackgroundTask() async {
    //print('_startBackgroundTask');
    String authStr = await LocalStorage.getString("authStr") ?? '';
    Workmanager().registerPeriodicTask(
      'background_task',
      'locationUpdate',
      inputData: <String, dynamic>{
        'authStr': authStr,
        'destsJson': destsJson,
      },
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 5),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );

    // Workmanager().registerOneOffTask(
    //   "oneoff_task",
    //   'locationUpdate',
    //   inputData: <String, dynamic>{
    //     'authStr': authStr,
    //     'destsJson': destsJson,
    //   },
    //   initialDelay: const Duration(seconds: 30),
    //   constraints: Constraints(
    //     networkType: NetworkType.connected,
    //   ),
    // );
  }

  void _cancelBackgroundTask() {
    Workmanager().cancelAll();
  }

  void resetHikeData() => setState(() {
        hikeData = null;
        reachedLocationId = null;
        destinations = [];
        showConfirm = false;
        showUndo = false;
      });

  void receiveHikeData() async {
    //request new Location
    //print('receiveHikeData');
    await Future.delayed(const Duration(milliseconds: 700));

    socketConnection.listenOnce(socketConnection.locationStream).then((event) {
      setState(() {
        hikeData = event;
        destinations = parseDestinations(hikeData!["data"]["coordinates"]);
        showUndo = hikeData!["data"]["hasUndoableCompletions"] == true;

        //save lat's and lng's to localStorage, to use in WorkManager
        final latLngList = destinations.map((dest) {
          return {
            'lat': dest.location.latitude,
            'lng': dest.location.longitude,
          };
        }).toList();
        destsJson = json.encode(latLngList);
        LocalStorage.saveString("destinations", json.encode(latLngList));

        //nieuwe locaties waarvoor nog geen notificatie is gegeven? Vlaggetje pingStr verwijderen, wordt dan door de background task aangemaakt
        String toStoreHash = generateMd5(json.encode(latLngList));
        if (toStoreHash != storedDestHash) {
          LocalStorage.remove("pingStr");
        }
      });
    });
    socketConnection.sendJson({'endpoint': 'newLocation'});
  }

  Future destinationReached(destinations) {
    final completer = Completer();
    late StreamSubscription subscription;

    subscription = currentLocationStream.listen((location) {
      lastLocation = location;
      Destination? destination = checkDestionsReached(destinations, location);
      if (destination != null) {
        subscription.cancel();
        completer.complete(destination);
      }
    });

    return completer.future;
  }

  void setupLocationThings() async {
    if (showConfirm || destinations == []) return;

    // before destination reached but hiking
    _startBackgroundTask();

    Destination destination = await destinationReached(destinations);

    // after destination reached
    _cancelBackgroundTask();

    if (destination.confirmByUser) {
      setState(() {
        reachedLocationId = destination.id;
        showConfirm = destination.confirmByUser;
      });
    } else {
      socketConnection.sendJson(locationConfirmdData(destination.id));
      resetHikeData();
    }
  }

  void verifyUndoCompletion() async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Terug naar vorige post"),
          content: const Text(
              "Weet je zeker dat je terug wilt naar de vorige aanwijzing? Je kunt deze actie niet ongedaan maken, anders dan door naar de bijbehorende locatie te gaan."),
          actions: <Widget>[
            TextButton(
              child: const Text("Nee, stop"),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // Return false when Cancel is pressed
              },
            ),
            TextButton(
              child: const Text("Ja, ik weet het zeker"),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Return true when Approve is pressed
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Call the undoCompletion method here
      undoCompletion();
    }
  }

  void undoCompletion() {
    socketConnection.sendJson({"endpoint": "undoCompletion"});
    resetHikeData();
  }

  logout() async {
    await LocalStorage.remove("authStr");
    SocketConnection.closeAndReconnect();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // if not hike data: recieve
    if (hikeData == null) {
      receiveHikeData();
      return loadingWidget();
    }

    setupLocationThings();

    //Confirm button
    bool isConfirming = false; // Track whether confirmation is in progress
    FloatingActionButton confirmButton = FloatingActionButton.extended(
      onPressed: !isConfirming
          ? () async {
              setState(() {
                isConfirming = true;
              });

              socketConnection.sendJson(locationConfirmdData(reachedLocationId));
              //hier willen we eigenlijk een bevestiging terug en dan pas de state wijzigen
              setState(() {
                isConfirming = false;
                resetHikeData();
              });
            }
          : null,
      label: const Text('Volgende'),
      icon: const Icon(Icons.thumb_up),
      backgroundColor: isConfirming ? Colors.grey : Colors.red,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("TapawingoHike"),
        actions: <Widget>[
          if (showUndo)
            IconButton(
              onPressed: () {
                verifyUndoCompletion();
              },
              icon: const Icon(Icons.undo),
            ),
          IconButton(
            onPressed: () {
              setState(() {
                keepScreenOn = !keepScreenOn;
              });

              // Toggle screen wake lock state
              if (keepScreenOn) {
                Wakelock.enable();
              } else {
                Wakelock.disable();
              }
            },
            icon: Icon(
              keepScreenOn ? Icons.screen_lock_rotation : Icons.screen_lock_portrait,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Uitloggen',
            onPressed: () {
              logout();
            },
          ), //IconButton
        ], //<Widget>[]
        backgroundColor: Colors.green,
        elevation: 50.0,
        // leading: IconButton(
        //   icon: const Icon(Icons.menu),
        //   tooltip: 'Menu Icon',
        //   onPressed: () {},
        // ),
      ),
      body: hikeTypeWidgets[hikeData!["type"]](hikeData!["data"], destinations),
      floatingActionButton: (showConfirm ? confirmButton : null),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
