import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';

class MapWidgetFMap extends StatefulWidget {
  final List destinations;

  const MapWidgetFMap({super.key, required this.destinations});

  @override
  _MapWidgetFMapState createState() => _MapWidgetFMapState();
}

class _MapWidgetFMapState extends State<MapWidgetFMap> {
  late FollowOnLocationUpdate _followOnLocationUpdate;
  late StreamController<double?> _followCurrentLocationStreamController;
  final mapController = MapController();

  @override
  void initState() {
    super.initState();
    _followOnLocationUpdate = FollowOnLocationUpdate.always;
    _followCurrentLocationStreamController = StreamController<double?>();
  }

  @override
  void dispose() {
    _followCurrentLocationStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List markers = widget.destinations.map((item) => item.marker).toList();
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        center: const LatLng(52.258779, 5.970222),
        zoom: 14,
        minZoom: 0,
        maxZoom: 19,
        onMapReady: () {
          mapController.mapEventStream.listen((evt) {});
          // And any other `MapController` dependent non-movement methods
        },
        // Stop following the location marker on the map if user interacted with the map.
        onPositionChanged: (MapPosition position, bool hasGesture) {
          if (hasGesture && _followOnLocationUpdate != FollowOnLocationUpdate.never) {
            setState(
              () => _followOnLocationUpdate = FollowOnLocationUpdate.never,
            );
          }
        },
      ),
      // ignore: sort_child_properties_last
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'net.tlserver6y.flutter_map_location_marker.',
          maxZoom: 19,
        ),
        CurrentLocationLayer(
          followCurrentLocationStream: _followCurrentLocationStreamController.stream,
          followOnLocationUpdate: _followOnLocationUpdate,
          turnOnHeadingUpdate: TurnOnHeadingUpdate.never,
        ),
        ...markers,
      ],
      nonRotatedChildren: [
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            heroTag: 'followMebtn',
            onPressed: () {
              // Follow the location marker on the map when location updated until user interact with the map.
              setState(
                () => _followOnLocationUpdate = FollowOnLocationUpdate.always,
              );
              // Follow the location marker on the map and zoom the map to level 18.
              _followCurrentLocationStreamController.add(18);
            },
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 85,
          child: FloatingActionButton(
            heroTag: 'northBtn',
            onPressed: () {
              //rotate to north
              double rotation = 0.0;
              mapController.rotate(rotation);
            },
            child: const Icon(
              Icons.explore,
              color: Colors.white,
            ),
          ),
        )
      ],
    );
  }
}
