import 'package:flutter/material.dart';

import 'package:photo_view/photo_view.dart';

import 'package:tapa_hike/widgets/audio.dart';
import 'package:tapa_hike/widgets/map.dart';

Map hikeTypeWidgets = {
  "coordinate": coordinate,
  "image": image,
  "audio": audio,
};

Widget widgetCoordinate (data, destinations) {
  return MapWidgetFMap(destinations: destinations);
}

Widget widgetImage (data) {
  if (data["zoomEnabled"] == false) {
    return Image(image: NetworkImage(data["image"]));
  }
  
  return ClipRect(
      child: PhotoView(
        imageProvider: NetworkImage(data["image"]),
        minScale: PhotoViewComputedScale.contained,
        initialScale: PhotoViewComputedScale.contained,
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
  if (data["fullscreen"] == false && data["image"] != null ) {
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
  } else if(data["image"] != null) {
    widgets.add(
      Expanded(
        flex: 5,
        child: widgetImage(data),
      ),
    );
  }
  return Column(children: widgets);
}

