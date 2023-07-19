import 'package:flutter/material.dart';

import 'package:tapa_hike/services/socket.dart';

import 'package:tapa_hike/widgets/loading.dart';
import 'package:tapa_hike/widgets/routes.dart';

class HikePage extends StatefulWidget {
  const HikePage({ super.key });

  @override
  State<HikePage> createState() => _HikePageState();
}

class _HikePageState extends State<HikePage> {
  Map? hikeData;
  List Destinations = [];

  void receiveHikeData () async {
    socketConnection.sendJson({"type": "request", "data": "newLocation"});
    socketConnection.listenOnce(socketConnection.routeStream).then((event) {
      setState(() {
        hikeData = event;
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {

    // if not hike data: recieve
    if (hikeData == null) {
      receiveHikeData();
      return LoadingWidget();
    }

    return hikeTypeWidgets[hikeData!["type"]](hikeData!["data"]);
  }
}
