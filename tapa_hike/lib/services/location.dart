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
    c["hideForUser"]
  )).toList();
}

class Destination {
  final int id;
  final int radius;
  late String type;
  double size = 20;
  final bool confirmByUser;
  late final LatLng location;
  final bool hideForUser;

  final Map colorMapping = {
    "mandatory": Colors.red,
    "choice": Colors.orange,
    "bonus": Colors.green,
    "hidden": Colors.black
  };

  Destination (this.id, latitude, longitude, this.radius, this.type, this.confirmByUser, this.hideForUser) {
    location = LatLng(latitude, longitude);
    type = hideForUser ? "hidden" : type;
    size = hideForUser ? 0 : 20;
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
      ),
      markerSize: Size.square(size)
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
