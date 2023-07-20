import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:tapa_hike/services/socket.dart';
import 'package:tapa_hike/services/location.dart';
import 'package:tapa_hike/services/cron_job.dart';

import 'package:tapa_hike/widgets/loading.dart';
import 'package:tapa_hike/widgets/routes.dart';

class HikePage extends StatefulWidget {
  const HikePage({ super.key });

  @override
  State<HikePage> createState() => _HikePageState();
}

class _HikePageState extends State<HikePage> {
  Map? hikeData;
  int? reachedLocationId;
  List destinations = [];
  bool showConfirm = false;
  late LatLng lastLocation;

  void resetHikeData () => setState(() {
    hikeData = null;
    reachedLocationId = null;
    destinations = [];
    showConfirm = false;
  });

  void sendLastLocationData () {
    socketConnection.sendJson({
      "type": "locationUpdate",
      "data": {
        "lat": lastLocation.latitude,
        "lng": lastLocation.longitude
      }
    });
  }

  void receiveHikeData () async {
    socketConnection.sendJson({"type": "request", "data": "newLocation"});
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
    if (showConfirm) return;

    // before destination reached but hiking
    startCronjob(sendLastLocationData, 1);
    Destination destination = await destinationReached(destinations);
    // after destination reached
    stopCronjob();


    if (destination.confirmByUser) {
      setState(() {
        reachedLocationId = destination.id;
        showConfirm = destination.confirmByUser;
      });
    } else {
      socketConnection.sendJson(locationConfirmdData(reachedLocationId));
      resetHikeData();
    }
  }

  @override
  Widget build(BuildContext context) {

    // if not hike data: recieve
    if (hikeData == null) {
      receiveHikeData();
      return LoadingWidget();
    }

    setupLocationThings();

    return Scaffold(
      backgroundColor: Colors.black,
      body: hikeTypeWidgets[hikeData!["type"]](hikeData!["data"], destinations),
      floatingActionButton: showConfirm ? FloatingActionButton(
        onPressed: () {
          socketConnection.sendJson(locationConfirmdData(reachedLocationId));
          resetHikeData();
        },
        child: const Icon(Icons.arrow_right_outlined, size: 50),
      ) : null,
    );
  }
}
