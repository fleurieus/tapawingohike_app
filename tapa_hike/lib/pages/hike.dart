import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:just_audio/just_audio.dart';

import 'package:tapa_hike/pages/home.dart';
import 'package:tapa_hike/services/auth.dart';
import 'package:tapa_hike/services/socket.dart';
import 'package:tapa_hike/services/location.dart';
import 'package:tapa_hike/services/storage.dart';

import 'package:tapa_hike/widgets/loading.dart';
import 'package:tapa_hike/widgets/routes.dart';
import 'package:tapa_hike/widgets/bundle.dart';
import 'package:tapa_hike/widgets/legendrow.dart';

enum GpsStatus { noSignal, acquiring, fix }

// GPS statuskleuren – vast (niet via theme)
const kGpsFixColor        = Color.fromARGB(255, 0, 255, 8); // groen
const kGpsAcquiringColor  = Colors.orange;                  // oranje
const kGpsNoSignalColor   = Colors.red;                     // rood


class HikePage extends StatefulWidget {
  const HikePage({super.key});

  @override
  State<HikePage> createState() => _HikePageState();
}

class _HikePageState extends State<HikePage> with WidgetsBindingObserver {
  Map? hikeData;
  int? reachedLocationId;
  List destinations = [];
  bool showConfirm = false;
  bool keepScreenOn = false;
  bool showUndo = false;
  late LatLng lastLocation;

  final AudioPlayer _chimePlayer = AudioPlayer();

  bool _reconnecting = false;

  GpsStatus _gpsStatus = GpsStatus.noSignal;
  StreamSubscription<Position>? _gpsSub;
  Timer? _gpsStaleTimer;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initGpsStatusWatcher();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsSub?.cancel();
    _gpsStaleTimer?.cancel();
    _chimePlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      //reconnect
      socketConnection.reconnect();
    }
  }

  Future<void> _playDestinationChime() async {
    try {
      await _chimePlayer.setAsset('assets/sounds/destination_reached.wav');
      await _chimePlayer.play();
    } catch (_) {
      // Don't let a sound failure block the hike flow
    }
  }

  void resetHikeData() => setState(() {
        hikeData = null;
        reachedLocationId = null;
        destinations = [];
        showConfirm = false;
        showUndo = false;
      });

  /// Check whether the received data is a bundle response
  bool get _isBundle => hikeData != null && hikeData!["bundle"] == true;

  /// Extract the current part's coordinates from bundle data
  List _currentBundleCoordinates() {
    if (!_isBundle) return [];
    final parts = hikeData!["parts"] as List;
    final idx = hikeData!["currentIndex"] as int? ?? 0;
    if (idx >= parts.length) return [];
    return parts[idx]["data"]["coordinates"] ?? [];
  }

  void receiveHikeData() async {
    //request new Location
    await _ensureConnectedAndAuthenticated();

    //print('receiveHikeData');
    await Future.delayed(const Duration(milliseconds: 700));


    socketConnection.listenOnce(socketConnection.locationStream).then((event) {
      setState(() {
        hikeData = event;

        // Parse destinations: from bundle's current part or single part
        if (hikeData!["bundle"] == true) {
          destinations = parseDestinations(_currentBundleCoordinates());
          showUndo = hikeData!["hasUndoableCompletions"] == true;
        } else {
          destinations = parseDestinations(hikeData!["data"]["coordinates"]);
          showUndo = hikeData!["data"]["hasUndoableCompletions"] == true;
        }
      });
    });
    socketConnection.sendJson({'endpoint': 'newLocation'});
  }

  Future destinationReached(destinations) {
    final completer = Completer();
    late StreamSubscription subscription;

    subscription = currentLocationStream.listen((location) {
      lastLocation = location;
      Destination? destination = checkDestionsReached(destinations, location);
      if (destination != null) {
        subscription.cancel();
        completer.complete(destination);
      }
    });

    return completer.future;
  }

  void setupLocationThings() async {
    if (showConfirm || destinations == []) return;

    Destination destination = await destinationReached(destinations);

    _playDestinationChime();

    if (destination.confirmByUser) {
      setState(() {
        reachedLocationId = destination.id;
        showConfirm = destination.confirmByUser;
      });
    } else {
      socketConnection.sendJson(locationConfirmdData(destination.id));
      resetHikeData();
    }
  }

  void verifyUndoCompletion() async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Terug naar vorige post"),
          content: const Text(
              "Weet je zeker dat je terug wilt naar de vorige aanwijzing? Je kunt deze actie niet ongedaan maken, anders dan door naar de bijbehorende locatie te gaan."),
          actions: <Widget>[
            TextButton(
              child: const Text("Nee, stop"),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // Return false when Cancel is pressed
              },
            ),
            TextButton(
              child: const Text("Ja, ik weet het zeker"),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Return true when Approve is pressed
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Call the undoCompletion method here
      undoCompletion();
    }
  }

  void undoCompletion() {
    socketConnection.sendJson({"endpoint": "undoCompletion"});
    resetHikeData();
  }

  logout() async {
    await LocalStorage.remove("authStr");
    SocketConnection.closeAndReconnect();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  Future<void> _ensureConnectedAndAuthenticated() async {
    // 1) Wacht tot de socket echt verbonden is
    try {
      await socketConnection.onConnected.timeout(const Duration(seconds: 5));
    } catch (_) {
      // fallback: forceer reconnect en wacht opnieuw
      socketConnection.reconnect();
      await socketConnection.onConnected.timeout(const Duration(seconds: 5));
    }

    // 2) Check of we al geauthenticeerd zijn; zo niet, doe dat met de opgeslagen authStr
    if (!socketConnection.isAuthenticated()) {
      final authStr = await LocalStorage.getString("authStr");
      if (authStr == null || authStr.trim().isEmpty) {
        throw Exception('Geen opgeslagen teamcode gevonden');
      }

      final ok = await socketConnection.authenticate(authStr.trim())
          .timeout(const Duration(seconds: 6));
      if (!ok) {
        throw Exception('Authenticatie mislukt');
      }
    }
  }

  Future<void> _reLoginWithStoredAuth() async {
    if (_reconnecting) return;
    setState(() => _reconnecting = true);

    try {
      // Sluit en start een schone socket (zoals jij al eerder deed)
      SocketConnection.closeAndReconnect();

      // Zorg dat we verbonden én geauthenticeerd zijn
      await _ensureConnectedAndAuthenticated();

      // UI/data verversen
      resetHikeData();
      await Future.delayed(const Duration(milliseconds: 50)); // laat de UI even ademhalen
      receiveHikeData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opnieuw verbonden')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Herverbinden mislukt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }



  IconData get _gpsIcon {
    switch (_gpsStatus) {
      case GpsStatus.fix: return Icons.gps_fixed;
      case GpsStatus.acquiring: return Icons.gps_not_fixed;
      case GpsStatus.noSignal: default: return Icons.gps_off;
    }
  }

  Color get _gpsColor {
    switch (_gpsStatus) {
      case GpsStatus.fix:        return kGpsFixColor;
      case GpsStatus.acquiring:  return kGpsAcquiringColor;
      case GpsStatus.noSignal:
      default:                   return kGpsNoSignalColor;
    }
  }

  Future<void> _initGpsStatusWatcher() async {
    if (mounted) setState(() => _gpsStatus = GpsStatus.noSignal);

    const accuracyGoodMeters = 30.0;
    const staleAfter = Duration(seconds: 12);

    _gpsSub?.cancel();
    _gpsSub = positionStream.listen(
      (Position pos) {
        _gpsStaleTimer?.cancel();
        _gpsStaleTimer = Timer(staleAfter, () {
          if (mounted) setState(() => _gpsStatus = GpsStatus.noSignal);
        });

        final acc = pos.accuracy;
        final next = acc <= accuracyGoodMeters ? GpsStatus.fix : GpsStatus.acquiring;
        if (mounted) setState(() => _gpsStatus = next);
      },
      onError: (_) {
        if (mounted) setState(() => _gpsStatus = GpsStatus.noSignal);
      },
    );
  }



  void _showGpsLegend() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('GPS status'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LegendRow(color: kGpsFixColor,       text: 'Groen - vaste fix, goede nauwkeurigheid'),
              SizedBox(height: 8),
              LegendRow(color: kGpsAcquiringColor, text: 'Oranje - bezig met fix, nauwkeurigheid nog matig'),
              SizedBox(height: 8),
              LegendRow(color: kGpsNoSignalColor,  text: 'Rood - geen signaal'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    // if not hike data: recieve
    if (hikeData == null) {
      receiveHikeData();
      return loadingWidget();
    }

    setupLocationThings();

    final scheme = Theme.of(context).colorScheme;

    //Confirm button
    bool isConfirming = false; // Track whether confirmation is in progress
    FloatingActionButton confirmButton = FloatingActionButton.extended(
      onPressed: !isConfirming
          ? () async {
              setState(() {
                isConfirming = true;
              });

              socketConnection.sendJson(locationConfirmdData(reachedLocationId));
              //hier willen we eigenlijk een bevestiging terug en dan pas de state wijzigen
              setState(() {
                isConfirming = false;
                resetHikeData();
              });
            }
          : null,
      label: const Text('Volgende'),
      icon: const Icon(Icons.thumb_up),
      backgroundColor: isConfirming ? scheme.surfaceContainerHighest : scheme.primary,
      foregroundColor: isConfirming ? scheme.onSurface : scheme.onPrimary,
    );
        
        

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text("TapawingoHike"),
        ),
        actions: <Widget>[
          if (showUndo)
            IconButton(
              tooltip: 'Ongedaan maken',
              onPressed: verifyUndoCompletion,
              icon: const Icon(Icons.undo),
            ),

          // (blijft) GPS-status
          IconButton(
            tooltip: 'GPS status',
            onPressed: _showGpsLegend,
            icon: Icon(_gpsIcon, color: _gpsColor),
          ),

          // (blijft) Herverbinden
          IconButton(
            tooltip: _reconnecting ? 'Bezig met herverbinden…' : 'Herverbinden',
            onPressed: _reconnecting ? null : _reLoginWithStoredAuth,
            icon: _reconnecting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),

          // ✅ Nieuw: overflow-menu met Scherm-aan en Uitloggen
          PopupMenuButton<String>(
            tooltip: 'Meer',
            onSelected: (value) async {
              switch (value) {
                case 'toggle_wakelock':
                  setState(() => keepScreenOn = !keepScreenOn);
                  if (keepScreenOn) {
                    await WakelockPlus.enable();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scherm-aan ingeschakeld')),
                      );
                    }
                  } else {
                    await WakelockPlus.disable();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scherm-aan uitgeschakeld')),
                      );
                    }
                  }
                  break;

                case 'logout':
                  logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'toggle_wakelock',
                child: Row(
                  children: [
                    Icon(
                      keepScreenOn ? Icons.screen_lock_rotation : Icons.screen_lock_portrait,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      keepScreenOn ? 'Scherm-aan uit' : 'Scherm-aan aan',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Theme.of(context).colorScheme.onPrimary),
                    const SizedBox(width: 12),
                    Text(
                      'Uitloggen',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      body: _isBundle
          ? BundleView(
              bundleData: hikeData!,
              currentDestinations: destinations.cast<Destination>(),
            )
          : hikeTypeWidgets[hikeData!["type"]](hikeData!["data"], destinations),
      floatingActionButton: (showConfirm ? confirmButton : null),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
