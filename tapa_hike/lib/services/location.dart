import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

List parseDestinations (coordinates) {
  List destinations = [];
  for (final c in coordinates) {
    destinations.add(Destination(
      c["latitude"],
      c["longitude"],
      c["radius"],
      c["type"],
      c["confirmByUser"],
    ));
  }
  return destinations;
}

class Destination {
  late final LatLng location;
  late final int radius;
  late final String type;
  late final bool confirmByUser;

  final Map colorMapping = {
    "mandatory": Colors.red,
    "choice": Colors.orange,
    "bonus": Colors.green,
  };

  Widget get marker => LocationMarkerLayer(
    position: LocationMarkerPosition(
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: 0,
    ),
    style: LocationMarkerStyle(
      marker: DefaultLocationMarker(
        color: colorMapping[type]
      )
    )
  );

  Destination (latitude, longitude, this.radius, this.type, this.confirmByUser) {
    location = LatLng(latitude, longitude);
  }
}
