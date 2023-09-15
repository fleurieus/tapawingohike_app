import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock/wakelock.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:tapa_hike/pages/home.dart';

import 'package:tapa_hike/services/socket.dart';
import 'package:tapa_hike/services/location.dart';

import 'package:workmanager/workmanager.dart';

import 'package:tapa_hike/widgets/loading.dart';
import 'package:tapa_hike/widgets/routes.dart';

class HikePage extends StatefulWidget {
  const HikePage({ super.key });

  @override
  State<HikePage> createState() => _HikePageState();
}

class _HikePageState extends State<HikePage> with WidgetsBindingObserver {
  Map? hikeData;
  int? reachedLocationId;
  List destinations = [];
  bool showConfirm = false;
  bool keepScreenOn = false;
  late LatLng lastLocation;


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

  void _startBackgroundTask() {
    print('_startBackgroundTask');
    Workmanager().registerPeriodicTask(
      'background_task',
      'locationUpdate',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );


    
    Workmanager().registerOneOffTask(
        'simpleDelayedTask',
        'locationUpdate',
        initialDelay: Duration(seconds: 10),
      );    
  }

  void _cancelBackgroundTask() {
    Workmanager().cancelByTag('background_task');
  }



  // void sendLastLocationData() {
  //   print('Sending last location');
  //   socketConnection.sendJson({
  //     "endpoint": "updateLocation",
  //     "data": {
  //       "lat": lastLocation.latitude,
  //       "lng": lastLocation.longitude
  //     }
  //   });
  // }


  void removeAuthStr() async {
    SharedPreferences localStore = await SharedPreferences.getInstance();
    localStore.remove("authStr");
  }


  void resetHikeData () => setState(() {
    hikeData = null;
    reachedLocationId = null;
    destinations = [];
    showConfirm = false;
  });

  void receiveHikeData () async {    
    socketConnection.sendJson({"endpoint": "newLocation"});
    socketConnection.listenOnce(socketConnection.locationStream).then((event) { 
      setState(() {
        hikeData = event;        
        destinations = parseDestinations(hikeData!["data"]["coordinates"]);
      });
    });
  }


  Future destinationReached (destinations) {
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


  void setupLocationThings () async {
    if (showConfirm || destinations == []) return;

    // before destination reached but hiking
    //startCronjob(sendLastLocationData, 1);
    _startBackgroundTask();

    Destination destination = await destinationReached(destinations);
    
    // after destination reached
    //stopCronjob();
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
      onPressed: !isConfirming ? () async {
        setState(() {
          isConfirming = true;
        });

        socketConnection.sendJson(locationConfirmdData(reachedLocationId));
        //hier willen we eigenlijk een bevestiging terug en dan pas de state wijzigen
        setState(() {
          isConfirming = false;
          resetHikeData();
        });
      
      } : null,
      label: const Text('Volgende'),
      icon: const Icon(Icons.thumb_up),
      backgroundColor: isConfirming ? Colors.grey : Colors.red,
    );






    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("TapawingoHike 2023"),
        actions: <Widget>[          
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
              removeAuthStr();
              SocketConnection.closeAndReconnect();

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
              
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

// FloatingActionButton.extended(
//         onPressed: () {
//           socketConnection.sendJson(locationConfirmdData(reachedLocationId));
//           resetHikeData();
//         },
//         label: const Text('Volgende'),
//         icon: const Icon(Icons.thumb_up),
//         backgroundColor: Colors.red,
//       )