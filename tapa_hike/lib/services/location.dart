import 'dart:async';

import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';


Map locationConfirmdData (id) => {"endpoint": "destinationConfirmed", "data": {"id": id}};

List parseDestinations (List coordinates) {
  return coordinates.map((c) => Destination(
    c["id"],
    c["latitude"],
    c["longitude"],
    c["radius"],
    c["type"],
    c["confirmByUser"],
  )).toList();
}

class Destination {
  final int id;
  final int radius;
  final String type;
  final bool confirmByUser;
  late final LatLng location;

  final Map colorMapping = {
    "mandatory": Colors.red,
    "choice": Colors.orange,
    "bonus": Colors.green,
  };

  Destination (this.id, latitude, longitude, this.radius, this.type, this.confirmByUser) {
    location = LatLng(latitude, longitude);
  }

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

  bool inRadius (LatLng current) {
    double distance = Distance().as(LengthUnit.Meter, location, current);
    return distance<=radius;
  }
}

LatLng positionToLatLng (position) => LatLng(position.latitude, position.longitude);

Destination? checkDestionsReached(List destinations, currentLocation) {
  for (final Destination destination in destinations) {
    if (destination.inRadius(currentLocation)) {
      return destination;
    }
  }
  return null;
}

const locationSettings = LocationSettings(
  accuracy: LocationAccuracy.bestForNavigation
);

Stream currentLocationStream = Geolocator.getPositionStream(locationSettings: locationSettings).map(
  (Position position) => positionToLatLng(position)
).asBroadcastStream();
