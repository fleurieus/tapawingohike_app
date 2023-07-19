import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';


Map hikeTypeWidgets = {
  "coordinate": (data) => coordinate(data),
  "image": (data) => image(data),
  "audio": (data) => audio(data),
};

Widget marker (lat, lng, color) => LocationMarkerLayer(position: LocationMarkerPosition(latitude: lat, longitude: lng, accuracy: 0), style: LocationMarkerStyle(marker: DefaultLocationMarker(color: color)));

Widget widgetCoordinate (data) {
  return FlutterMap(
    options: MapOptions(
      center: LatLng(52.258779, 5.970222),
      zoom: 9.2,
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      ),
      CurrentLocationLayer(
        followOnLocationUpdate: FollowOnLocationUpdate.always
      ),
      marker(52.0, 5.8, Colors.red),
    ],
  );
}

Widget widgetImage (data) {
  return Scaffold(
    backgroundColor: Colors.red,
  );
}

Widget widgetAudio (data) {
  return Scaffold(
    backgroundColor: Colors.green,
  );
}


Widget coordinate (data) {
  return Column(children: [
    Expanded(
      flex: 6,
      child: widgetCoordinate(data),
    )
  ]);
}

Widget image (data) {
  return Column(children: [
    Expanded(
      flex: 3,
      child: widgetImage(data),
    ),
    Expanded(
      flex: 3,
      child: widgetCoordinate(data),
    )
  ]);
}

Widget audio (data) {
  return Column(children: [
    Expanded(
      flex: 1,
      child: widgetAudio(data),
    ),
    Expanded(
      flex: 2,
      child: widgetImage(data),
    ),
    Expanded(
      flex: 3,
      child: widgetCoordinate(data),
    )
  ]);
}

