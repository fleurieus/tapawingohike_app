// lib/pages/home.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tapa_hike/services/storage.dart';
import 'package:tapa_hike/services/socket.dart'; // <- gebruikt socketConnection.authenticate

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authStrController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loggingIn = false;
  String? _savedAuth;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Probeer met bewaarde authStr (zonder UI te blokkeren)
    final saved = await LocalStorage.getString("authStr");
    if (!mounted) return;

    final trimmed = (saved ?? '').trim();
    if (trimmed.isNotEmpty) {
      setState(() {
        _savedAuth = trimmed;
        _authStrController.text = trimmed;
      });
      // Probeer automatisch in te loggen (zoals "vroeger")
      _login(trimmed);
    }
  }

  Future<void> _login(String authStr) async {
    if (_loggingIn) return;
    setState(() => _loggingIn = true);

    try {
      // Show prominent disclosure before requesting location permission (Play Store requirement).
      // Skip if permission is already granted (returning user, no need to show again).
      final existingPermission = await Geolocator.checkPermission();
      if (existingPermission == LocationPermission.denied ||
          existingPermission == LocationPermission.deniedForever) {
        if (!mounted) return;
        final accepted = await _showLocationDisclosure();
        if (!accepted) {
          if (mounted) setState(() => _loggingIn = false);
          return;
        }
      }

      // Request location permission.
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Locatiepermissie is permanent geweigerd. Pas dit aan in de app-instellingen.'),
            ),
          );
          setState(() => _loggingIn = false);
        }
        return;
      }

      // Request notification permission (Android 13+) for foreground service notification.
      final notifStatus = await Permission.notification.status;
      if (notifStatus.isDenied) {
        await Permission.notification.request();
      }

      final bool authResult = await socketConnection.authenticate(authStr);
      if (authResult) {
        await LocalStorage.saveString("authStr", authStr);
        if (!mounted) return;
        _navigateToHikePage();
      } else {
        if (!mounted) return;
        _showLoginFailed();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Inloggen mislukt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  /// Shows a prominent disclosure dialog explaining location usage.
  /// Returns true if the user accepts, false if they decline.
  Future<bool> _showLocationDisclosure() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Toestemming voor locatie'),
            content: const SingleChildScrollView(
              child: Text(
                'Deze app verzamelt je GPS-locatie om de hike-tocht te laten werken. '
                'De locatie wordt zowel gebruikt op je telefoon als gedeeld met de '
                'organisatie van het evenement, via onze server.\n\n'
                'Wat we doen met je locatie:\n'
                '• Automatisch detecteren wanneer je een routepunt bereikt, zodat de app '
                'een melding en een geluidssignaal kan geven.\n'
                '• Je positie periodiek naar de server sturen, zodat de organisatie de '
                'teams kan zien op de live kaart in de backoffice.\n\n'
                'Wanneer wordt locatie gebruikt:\n'
                'Tijdens een actieve hike blijft de app je locatie volgen, ook als de '
                'app op de achtergrond draait of als je scherm uit staat. Een melding '
                'in je notificatiebalk laat zien dat de locatie actief is. Buiten een '
                'hike om wordt geen locatie verzameld.\n\n'
                'Zonder locatietoegang werkt de app niet. Je kunt de toestemming op '
                'elk moment intrekken via de instellingen van je telefoon.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuleren'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Akkoord'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _navigateToHikePage() {
    Navigator.of(context).pushReplacementNamed('/hike');
  }

  void _showLoginFailed() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inloggen mislukt'),
        content: const Text('Controleer je teamcode en probeer het opnieuw.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _authStrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TapawingoHike'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titel
                Text(
                  'Welkom bij de TapawingoHike',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),

                // Teamcode veld
                TextFormField(
                  controller: _authStrController,
                  enabled: !_loggingIn,
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    labelText: 'Login met jouw teamcode',
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (value) {
                    final authStr = value.trim();
                    if (authStr.isNotEmpty) {
                      _login(authStr);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Voer je teamcode in';
                    }
                    return null;
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'^\s')),
                  ],
                ),
                const SizedBox(height: 16),

                // Actieknoppen
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loggingIn
                            ? null
                            : () {
                                if (_formKey.currentState?.validate() ?? false) {
                                  final authStr = _authStrController.text.trim();
                                  if (authStr.isNotEmpty) {
                                    _login(authStr);
                                  }
                                }
                              },
                        child: _loggingIn
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Inloggen'),
                      ),
                    ),
                  ],
                ),

                if (_savedAuth != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loggingIn ? null : () => _login(_savedAuth!),
                    icon: const Icon(Icons.key),
                    label: const Text('Inloggen met opgeslagen teamcode'),
                  ),
                ],

                const SizedBox(height: 40),
                Text(
                  'Je teamcode wordt lokaal op jouw telefoon bewaard, zodat je bij het openen van de app automatisch weer inlogt. '
                  'Uitloggen kan altijd vanuit het hike-scherm.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
