import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';

class MapWidgetFMap extends StatefulWidget {
  final List destinations;

  const MapWidgetFMap({super.key, required this.destinations});

  @override
  State<MapWidgetFMap> createState() => _MapWidgetFMapState();
}

class _MapWidgetFMapState extends State<MapWidgetFMap> {
  late AlignOnUpdate _alignOnUpdate;
  late StreamController<double?> _alignPositionStreamController;
  final mapController = MapController();

  @override
  void initState() {
    super.initState();
    _alignOnUpdate = AlignOnUpdate.always;
    _alignPositionStreamController = StreamController<double?>();
  }

  @override
  void dispose() {
    _alignPositionStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Neem aan dat elke destination een .marker widget levert (zoals in jouw bestaande code)
    final markers = widget.destinations.map((item) => item.marker).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: const LatLng(52.258779, 5.970222),
            initialZoom: 14,
            minZoom: 0,
            maxZoom: 19,
            onMapReady: () {
              mapController.mapEventStream.listen((evt) {});
              // overige MapController-afhankelijke calls hier
            },
            // v8: callback -> (MapCamera camera, bool hasGesture)
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && _alignOnUpdate != AlignOnUpdate.never) {
                setState(() => _alignOnUpdate = AlignOnUpdate.never);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'net.tlserver6y.flutter_map_location_marker.',
              maxZoom: 19,
            ),
            CurrentLocationLayer(
              alignPositionStream: _alignPositionStreamController.stream,
              alignPositionOnUpdate: _alignOnUpdate,
              alignDirectionOnUpdate: AlignOnUpdate.never,
            ),
            ...markers,
          ],
        ),

        // === Overlay knoppen (vervanging voor nonRotatedChildren) ===

        Positioned(
          right: 20,
          bottom: 55,
          child: FloatingActionButton(
            backgroundColor: Colors.green,
            heroTag: 'followMebtn',
            onPressed: () {
              // opnieuw automatisch centreren + naar zoom 18
              setState(() => _alignOnUpdate = AlignOnUpdate.always);
              _alignPositionStreamController.add(18);
            },
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ),

        Positioned(
          right: 20,
          bottom: 120,
          child: FloatingActionButton(
            backgroundColor: Colors.green,
            heroTag: 'northBtn',
            onPressed: () {
              // rotate naar noorden (0 graden)
              mapController.rotate(0.0);
            },
            child: const Icon(Icons.explore, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
