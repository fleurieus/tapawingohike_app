import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/routes.dart';
import '../services/location.dart';

class BundleView extends StatefulWidget {
  final Map bundleData;
  final List<Destination> currentDestinations;

  const BundleView({
    super.key,
    required this.bundleData,
    required this.currentDestinations,
  });

  @override
  State<BundleView> createState() => _BundleViewState();
}

class _BundleViewState extends State<BundleView> {
  late PageController _pageController;
  late int _currentPage;

  List get parts => widget.bundleData["parts"] as List;
  String get browseMode => widget.bundleData["browseMode"] ?? "free";
  String get linearUpcomingMode =>
      widget.bundleData["linearUpcomingMode"] ?? "locked";
  int get currentIndex => widget.bundleData["currentIndex"] ?? 0;

  @override
  void initState() {
    super.initState();
    _currentPage = currentIndex;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(covariant BundleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When bundle data updates (e.g. after destination confirmed),
    // jump to the new current index
    if (currentIndex != _currentPage) {
      _currentPage = currentIndex;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Build the content widget for a single part within the bundle
  Widget _buildPartContent(int index) {
    final part = parts[index];
    final status = part["status"] as String;
    final type = part["type"] as String;
    final data = part["data"] as Map;

    // For the current part, use the live destinations from GPS tracking
    // For completed/upcoming parts, parse their own destinations
    final destinations = (status == "current")
        ? widget.currentDestinations
        : parseDestinations(data["coordinates"] ?? []);

    // Get the render function for this route type
    final renderFn = hikeTypeWidgets[type];
    if (renderFn == null) {
      return const Center(child: Text("Onbekend routetype"));
    }

    Widget content = renderFn(data, destinations);

    // Linear mode: lock upcoming parts
    if (browseMode == "linear" && status == "upcoming") {
      if (linearUpcomingMode == "hidden") {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                "Dit routedeel is nog niet beschikbaar",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        );
      }

      // Locked: show blurred content with lock overlay
      return Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: content,
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.3),
          ),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 48, color: Colors.white70),
                SizedBox(height: 12),
                Text(
                  "Bereik eerst het huidige checkpoint",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Completed overlay: subtle checkmark
    if (status == "completed") {
      return Stack(
        children: [
          content,
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            ),
          ),
        ],
      );
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    final totalParts = parts.length;

    return Stack(
      children: [
        // PageView with swipeable pages
        PageView.builder(
          controller: _pageController,
          itemCount: totalParts,
          onPageChanged: (index) {
            setState(() => _currentPage = index);
          },
          // In linear mode, physics restricts but we handle via UI
          itemBuilder: (context, index) => _buildPartContent(index),
        ),

        // Bottom indicator: dots + counter
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Counter text
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "${_currentPage + 1} / $totalParts",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalParts, (index) {
                  final status = parts[index]["status"] as String;
                  Color dotColor;
                  switch (status) {
                    case "completed":
                      dotColor = Colors.green;
                      break;
                    case "current":
                      dotColor = Colors.blue;
                      break;
                    default:
                      dotColor = Colors.grey;
                  }

                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 12 : 8,
                    height: isActive ? 12 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? dotColor : dotColor.withValues(alpha: 0.5),
                      border: isActive
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
