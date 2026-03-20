# TapawingoHike – App (Flutter)

> Lees eerst `../CLAUDE.md` voor de gedeelde projectcontext.

## Communicatie
- Spreek Nederlands met de gebruiker
- Code, comments en commit messages in het Engels

## Stack (geverifieerd)
- **Framework**: Flutter SDK ^3.9.0 (Dart)
- **State management**: vanilla StatefulWidget + setState() (geen framework)
- **Communicatie**: WebSocket via `web_socket_client` package
- **Kaart**: `flutter_map` + OpenStreetMap tiles
- **Lokale opslag**: `shared_preferences`
- **Foto zoom**: `photo_view` (al geïnstalleerd)
- **Audio**: `just_audio`
- **GPS**: `geolocator` met `AndroidSettings` + `ForegroundNotificationConfig` (foreground service)
- **Scherm aan**: `wakelock_plus`

## Stap 1 – Verken de codebase (altijd eerst doen)
```bash
cat pubspec.yaml              # dependencies en Flutter versie
find lib -name "*.dart" | sort
ls lib/                       # top-level structuur (screens, models, services, widgets?)
cat lib/main.dart
find lib -name "*service*" -o -name "*api*" -o -name "*repository*" | sort
find lib -name "*model*" -o -name "*entity*" | sort
```
Beschrijf je bevindingen beknopt voordat je begint.

## Afgeronde taken
1. ~~**Galerij / bladeren door routetypes**~~ – geïmplementeerd als bundel-functionaliteit.
   `BundleView` widget (`lib/widgets/bundle.dart`) met PageView, status-indicator dots,
   lock/blur voor lineaire modus. `hike.dart` aangepast met `_isBundle` detectie.
   Gecommit en gepusht: commit 00c4930.
2. ~~**Geluidje bij destination reached**~~ – `just_audio` speelt
   `assets/sounds/destination_reached.wav` af zodra GPS-radius bereikt is. Werkt in
   voor- en achtergrond dankzij foreground service. Commit 15bd1e3.
3. ~~**Foreground service voor achtergrond GPS + geluid**~~ – WorkManager volledig vervangen
   door geolocator `AndroidSettings` met `ForegroundNotificationConfig`. Eén gedeelde
   `positionStream` (location.dart) voor zowel GPS-status icoon als destination-check.
   Notificatie-permissie wordt gevraagd bij login (auth.dart). Commit 15bd1e3 + bugfixes.
4. ~~**Package naam fix**~~ – pubspec.yaml `name` van `TapawingoHike` naar `tapa_hike`
   zodat imports matchen en de build slaagt. Commit 024a24a.
5. ~~**Bugfix: meerdere destination-subscriptions**~~ – `destinations == []` (altijd false in
   Dart) vervangen door `destinations.isEmpty`, plus `_waitingForDestination` guard om
   dubbele subscriptions op `currentLocationStream` te voorkomen.
6. ~~**Bundel swipe UX**~~ – "1/3" teller verwijderd (alleen dots), swipe geclampt op max ±1
   pagina, `IgnorePointer` op geblurde locked-content zodat swipe niet wordt afgevangen.

## Codebase structuur (geverifieerd)
```
lib/
├── main.dart                    # Entry point (clean, geen WorkManager)
├── theme.dart                   # Material 3, brand color #266619
├── pages/
│   ├── home.dart                # Login (teamcode invoer)
│   └── hike.dart                # Hoofd-hike scherm (route weergave, GPS, confirm)
├── services/
│   ├── socket.dart              # WebSocket (ws://116.203.112.220:80/ws/app/)
│   ├── location.dart            # Destination model, positionStream, currentLocationStream
│   ├── auth.dart                # Login + locatie/notificatie permissions helper
│   └── storage.dart             # SharedPreferences wrapper
└── widgets/
    ├── routes.dart              # Route type dispatcher (coordinate/image/audio)
    ├── bundle.dart              # BundleView – PageView met swipe, dots, lock/blur
    ├── map.dart                 # flutter_map component
    ├── audio.dart               # just_audio player widget
    ├── loading.dart             # Spinner
    └── legendrow.dart           # GPS legend
```

## Actieve taken

### [PRIO 1] Competitie zichtbaar tijdens route
**Voorstel voor CC om uit te werken**:
Stel een concreet voorstel voor op basis van de bestaande architectuur. Mogelijke richtingen:
- Optie A: Live scorebord – teams gesorteerd op aantal voltooide checkpoints + snelheid
- Optie B: Kaartweergave – andere teams (geanonimiseerd of met teamnaam) op de kaart
- Optie C: Combinatie – compact scorebord-icoontje + optionele kaartlaag
Geef aan welke server-aanpassingen elk optie vereist.

### [PRIO 2] Berichten sturen/ontvangen
- Verifieer of de server al een messaging endpoint heeft
- Chat-achtig scherm per editie of globaal?
- Push notifications gewenst? (vereist FCM integratie – vraag aan gebruiker)

### [PRIO 3] Locatie delen
**Doel**: periodiek de GPS-locatie van het team uploaden naar de server.
- Foreground service draait al → `positionStream` is beschikbaar
- Vraag aan gebruiker: hoe frequent uploaden? (bijv. elke 30 sec, of alleen op verzoek?)
- Server heeft al `updateLocation` endpoint

### [PRIO 4] Route datum + locatielogs filteren
- Voeg `date` veld toe aan het route/editie model (verifieer of dit al bestaat)
- Locatielogs filteren op datum in de beheerapplicatie (server-kant) en/of app

### [PRIO 5] Help menu
- Statische of dynamische helpteksten per scherm
- Verifieer of er al een settings/about scherm is om op te hangen

## GPS architectuur (referentie)
- `location.dart` definieert `positionStream` (broadcast `Stream<Position>`) met
  `AndroidSettings` + `ForegroundNotificationConfig` — dit is de **enige** GPS stream
- `currentLocationStream` mapt `positionStream` naar `LatLng` voor destination-checks
- `hike.dart` `_initGpsStatusWatcher()` luistert naar `positionStream` voor accuracy/icon
- `hike.dart` `destinationReached()` luistert naar `currentLocationStream` voor radius-check
- `auth.dart` vraagt locatie- én notificatie-permissie bij login

## Flutter conventies (geverifieerd)
- Mapstructuur: `lib/pages/`, `lib/widgets/`, `lib/services/` (geen apart models-bestand)
- Routing: standaard `Navigator` met named routes (`/home`, `/hike`)
- Theme: Material 3 seed-based, brand color `#266619`
- Server URL: hardcoded constante `116.203.112.220:80` in `socket.dart`
- Data: alles als dynamic Maps/Lists – geen typed models

## Veelgebruikte commando's
```bash
flutter pub get
flutter run
flutter build apk --release
flutter test
flutter analyze
dart fix --apply
```

## Lokaal testen via USB
```bash
adb reverse tcp:8000 tcp:8000
# Wijzig socket.dart: domain = "127.0.0.1:8000"
# Vergeet niet terug te zetten naar productie-URL voor commit!
```

## Belangrijk: API-contract
De app communiceert met de Django server via **WebSocket** (niet REST). **Pas nooit de verwachte
message structuur aan** zonder ook de server aan te passen én dit te vermelden aan de gebruiker.
Documenteer API-wijzigingen in `../CLAUDE.md` onder "Bundel-functionaliteit".
