import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';
import 'package:photo_view/photo_view.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

import 'package:tapa_hike/widgets/audio.dart';

Map hikeTypeWidgets = {
  "coordinate": coordinate,
  "image": image,
  "audio": audio,
};

Widget widgetCoordinate (data, destinations) {
  List markers = destinations.map((item) => item.marker).toList();

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
     ...markers,
    ],
  );
}

Widget widgetImage (data) {
  print(data["image"]);
  if (data["zoomEnabled"] == false) {
    return Image(image: NetworkImage(data["image"]));
  }
  
  return Container(
    child: ClipRect(
      child: PhotoView(
        imageProvider: NetworkImage(data["image"]),
        minScale: PhotoViewComputedScale.contained,
        initialScale: PhotoViewComputedScale.contained,
      ),
    ),
  );
}

Widget widgetAudio (data) {
  return AudioPlayerWidget(audioUrl: data["audio"]);
}


Widget coordinate (data, destinations) {
  return Column(children: [
    Expanded(
      flex: 6,
      child: widgetCoordinate(data, destinations),
    )
  ]);
}

Widget image (data, destinations) {
  List<Widget> widgets = [
    Expanded(
      flex: 3,
      child: widgetImage(data),
    ),
  ];

  if (data["fullscreen"] == false) {
    widgets.add(
      Expanded(
        flex: 3,
        child: widgetCoordinate(data, destinations),
      )
    );
  }

  return Column(children: widgets);
}

Widget audio (data, destinations) {
  List<Widget> widgets = [
    Expanded(
      flex: 1,
      child: widgetAudio(data),
    ),
  ];
  if (data["fullscreen"] == false) {
    widgets.add(
      Expanded(
        flex: 2,
        child: widgetImage(data),
      ),
    );
    widgets.add(
      Expanded(
        flex: 3,
        child: widgetCoordinate(data, destinations),
      )
    );
  } else {
    widgets.add(
      Expanded(
        flex: 5,
        child: widgetImage(data),
      ),
    );
  }
  return Column(children: widgets);
}

