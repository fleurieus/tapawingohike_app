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
import 'package:tapa_hike/services/location_sender.dart';

import 'package:tapa_hike/pages/messages.dart';
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
  final AudioPlayer _messageChimePlayer = AudioPlayer();

  bool _reconnecting = false;
  bool _waitingForDestination = false;
  bool _loadingHikeData = false;
  bool _isConfirming = false;

  GpsStatus _gpsStatus = GpsStatus.noSignal;
  StreamSubscription<Position>? _gpsSub;
  Timer? _gpsStaleTimer;

  int _unreadMessages = 0;
  StreamSubscription? _messageSub;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initGpsStatusWatcher();
    _initMessageListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsSub?.cancel();
    _gpsStaleTimer?.cancel();
    _messageSub?.cancel();
    _chimePlayer.dispose();
    _messageChimePlayer.dispose();
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
        _waitingForDestination = false;
        _loadingHikeData = false;
        _isConfirming = false;
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
    if (_loadingHikeData) return;
    debugPrint('[HikePage] receiveHikeData: starting');
    setState(() => _loadingHikeData = true);

    try {
      await _ensureConnectedAndAuthenticated();
      debugPrint('[HikePage] receiveHikeData: waiting 700ms before newLocation');
      await Future.delayed(const Duration(milliseconds: 700));

      // Set up the listener BEFORE sending the request so no message is missed.
      final future = socketConnection.listenOnce(
        socketConnection.locationStream,
        timeout: const Duration(seconds: 15),
      );
      debugPrint('[HikePage] receiveHikeData: sending newLocation');
      socketConnection.sendJson({'endpoint': 'newLocation'});
      debugPrint('[HikePage] receiveHikeData: waiting for route response (15s timeout)');

      final event = await future;
      debugPrint('[HikePage] receiveHikeData: route response received');
      if (!mounted) return;

      setState(() {
        hikeData = event;
        _loadingHikeData = false;

        // Parse destinations: from bundle's current part or single part
        if (hikeData!["bundle"] == true) {
          destinations = parseDestinations(_currentBundleCoordinates());
          showUndo = hikeData!["hasUndoableCompletions"] == true;
        } else {
          destinations = parseDestinations(hikeData!["data"]["coordinates"]);
          showUndo = hikeData!["data"]["hasUndoableCompletions"] == true;
        }
      });
      debugPrint('[HikePage] receiveHikeData: state updated, destinations: ${destinations.length}');
    } catch (e) {
      debugPrint('[HikePage] receiveHikeData: ERROR: $e');
      if (mounted) {
        setState(() => _loadingHikeData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij ophalen locatie, probeer opnieuw: $e')),
        );
      }
    }
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
    if (showConfirm || destinations.isEmpty || _waitingForDestination) return;
    _waitingForDestination = true;

    Destination destination = await destinationReached(destinations);

    _waitingForDestination = false;
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
    LocationSender.instance.stop();
    await LocalStorage.remove("authStr");
    SocketConnection.closeAndReconnect();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  Future<void> _ensureConnectedAndAuthenticated() async {
    // 1) Wacht tot de socket echt in Connected/Reconnected staat is
    debugPrint('[HikePage] _ensureConnectedAndAuthenticated: checking live socket state');
    try {
      await socketConnection.waitUntilConnected(timeout: const Duration(seconds: 10));
      debugPrint('[HikePage] _ensureConnectedAndAuthenticated: socket is connected');
    } catch (_) {
      // fallback: forceer reconnect en wacht opnieuw
      debugPrint('[HikePage] _ensureConnectedAndAuthenticated: not connected, forcing reconnect');
      socketConnection.reconnect();
      await socketConnection.waitUntilConnected(timeout: const Duration(seconds: 10));
      debugPrint('[HikePage] _ensureConnectedAndAuthenticated: reconnected');
    }

    // 2) Check of we al geauthenticeerd zijn; zo niet, doe dat met de opgeslagen authStr
    if (!socketConnection.isAuthenticated()) {
      debugPrint('[HikePage] _ensureConnectedAndAuthenticated: not authenticated, re-authenticating');
      final authStr = await LocalStorage.getString("authStr");
      if (authStr == null || authStr.trim().isEmpty) {
        throw Exception('Geen opgeslagen teamcode gevonden');
      }

      final ok = await socketConnection.authenticate(authStr.trim())
          .timeout(const Duration(seconds: 6));
      if (!ok) {
        throw Exception('Authenticatie mislukt');
      }
      debugPrint('[HikePage] _ensureConnectedAndAuthenticated: authenticated successfully');
    } else {
      debugPrint('[HikePage] _ensureConnectedAndAuthenticated: already authenticated');
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



  void _initMessageListener() {
    if (!socketConnection.messagingEnabled) return;
    _messageSub = socketConnection.messageStream.listen((event) {
      // Only handle single incoming messages here (not history lists)
      // Skip echoes of our own sent messages
      if (event is Map && event["isOrganisation"] == true) {
        if (mounted) {
          setState(() => _unreadMessages++);
          _playMessageChime();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${event["from"]}: ${event["text"]}'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Bekijk',
                onPressed: _openMessages,
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _playMessageChime() async {
    try {
      await _messageChimePlayer.setAsset('assets/sounds/destination_reached.wav');
      await _messageChimePlayer.play();
    } catch (_) {}
  }

  void _openMessages() {
    setState(() => _unreadMessages = 0);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MessagesPage()),
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
    // if not hike data: receive
    if (hikeData == null) {
      if (!_loadingHikeData) receiveHikeData();
      return loadingWidget();
    }

    setupLocationThings();

    final scheme = Theme.of(context).colorScheme;

    //Confirm button
    FloatingActionButton confirmButton = FloatingActionButton.extended(
      onPressed: !_isConfirming
          ? () async {
              debugPrint('[HikePage] Volgende pressed, reachedLocationId=$reachedLocationId');
              setState(() => _isConfirming = true);
              try {
                // Ensure the socket is connected before sending so the
                // confirmation is never silently dropped into a reconnecting socket.
                await _ensureConnectedAndAuthenticated();
                debugPrint('[HikePage] Volgende: sending destinationConfirmed');
                socketConnection.sendJson(locationConfirmdData(reachedLocationId));
                debugPrint('[HikePage] Volgende: confirmation sent successfully');
              } catch (e) {
                debugPrint('[HikePage] Volgende: ERROR sending confirmation: $e');
                if (mounted) {
                  setState(() => _isConfirming = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kon bevestiging niet versturen, probeer opnieuw: $e')),
                  );
                }
                return;
              }
              debugPrint('[HikePage] Volgende: resetting hike data, loading next location');
              if (mounted) resetHikeData();
            }
          : null,
      label: const Text('Volgende'),
      icon: const Icon(Icons.thumb_up),
      backgroundColor: _isConfirming ? scheme.surfaceContainerHighest : scheme.primary,
      foregroundColor: _isConfirming ? scheme.onSurface : scheme.onPrimary,
    );
        
        

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text("TapawingoHike"),
        ),
        actions: <Widget>[
          // Messages icon with unread badge
          if (socketConnection.messagingEnabled)
            IconButton(
              tooltip: 'Berichten',
              onPressed: _openMessages,
              icon: Badge(
                isLabelVisible: _unreadMessages > 0,
                label: Text('$_unreadMessages'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
            ),

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
