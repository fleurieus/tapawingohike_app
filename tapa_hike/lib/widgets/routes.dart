import 'package:flutter/material.dart';

import 'package:photo_view/photo_view.dart';

import 'package:tapa_hike/widgets/audio.dart';
import 'package:tapa_hike/widgets/map.dart';

// A getter, not a top-level variable: Dart never re-runs top-level field
// initializers on hot reload, so a `Map hikeTypeWidgets = {...}` could freeze
// with a stale set of keys (e.g. missing "gallery") and keep returning null
// from the dispatch lookup until a full restart. A getter is re-evaluated on
// every access and always reflects the current function set.
Map<String, Function> get hikeTypeWidgets => {
      "coordinate": coordinate,
      "image": image,
      "audio": audio,
      "gallery": gallery,
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
  final bool fullscreen = data["fullscreen"] != false; // default true
  final bool hasImage = data["image"] != null;

  List<Widget> widgets = [
    Expanded(
      flex: 1,
      child: widgetAudio(data),
    ),
  ];

  if (!fullscreen) {
    // Non-fullscreen: always show the map so podwalk users see the next
    // checkpoint. Image is optional — shown above the map when present.
    if (hasImage) {
      widgets.add(Expanded(flex: 2, child: widgetImage(data)));
      widgets.add(Expanded(flex: 3, child: widgetCoordinate(data, destinations)));
    } else {
      widgets.add(Expanded(flex: 5, child: widgetCoordinate(data, destinations)));
    }
  } else if (hasImage) {
    widgets.add(Expanded(flex: 5, child: widgetImage(data)));
  }

  return Column(children: widgets);
}


/// Carousel of gallery images with PageView + dot indicator.
/// Reused by [gallery] route renderer; kept as its own widget so it can hold
/// PageController state.
class GalleryCarousel extends StatefulWidget {
  final List<String> imageUrls;

  const GalleryCarousel({super.key, required this.imageUrls});

  @override
  State<GalleryCarousel> createState() => _GalleryCarouselState();
}

class _GalleryCarouselState extends State<GalleryCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final n = widget.imageUrls.length;
    final next = (_currentPage + delta).clamp(0, n - 1);
    if (next != _currentPage) {
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.40),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    if (urls.isEmpty) {
      return const Center(child: Text("Geen foto's"));
    }
    final bool multi = urls.length > 1;

    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemBuilder: (context, index) => ClipRect(
            child: PhotoView(
              imageProvider: NetworkImage(urls[index]),
              minScale: PhotoViewComputedScale.contained,
              initialScale: PhotoViewComputedScale.contained,
            ),
          ),
        ),

        // Fototeller rechtsboven — maakt meteen duidelijk dat er meer foto's
        // zijn (en hoeveel), i.p.v. alleen de subtiele stippen.
        if (multi)
          Positioned(
            top: 8,
            right: 8,
            child: _pill('${_currentPage + 1} / ${urls.length}'),
          ),

        // Tikbare vorige/volgende-pijlen voor wie niet aan vegen denkt.
        // Verborgen aan de uiteinden zodat begin/eind duidelijk is.
        if (multi && _currentPage > 0)
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(child: _arrow(Icons.chevron_left, () => _go(-1))),
          ),
        if (multi && _currentPage < urls.length - 1)
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: Center(child: _arrow(Icons.chevron_right, () => _go(1))),
          ),

        // Stippen onderaan.
        if (multi)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(urls.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 10 : 7,
                  height: active ? 10 : 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    border: Border.all(color: Colors.black26, width: 1),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

Widget widgetGallery(data) {
  final images = (data["images"] as List?)?.cast<String>() ?? const <String>[];
  final caption = (data["caption"] as String?) ?? "";

  if (caption.isEmpty) {
    return GalleryCarousel(imageUrls: images);
  }

  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Text(
          caption,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      Expanded(child: GalleryCarousel(imageUrls: images)),
    ],
  );
}

Widget gallery(data, destinations) {
  final bool fullscreen = data["fullscreen"] != false; // default true
  final bool hasCoordinates = destinations is List && destinations.isNotEmpty;

  // Fullscreen, or no coordinates → only the carousel
  if (fullscreen || !hasCoordinates) {
    return widgetGallery(data);
  }

  // Non-fullscreen + coordinates → carousel above, map below (same ratios
  // as the image renderer for visual consistency).
  return Column(children: [
    Expanded(flex: 3, child: widgetGallery(data)),
    Expanded(flex: 3, child: widgetCoordinate(data, destinations)),
  ]);
}
