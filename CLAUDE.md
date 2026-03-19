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
- **GPS**: `geolocator`
- **Achtergrond**: `workmanager` (wordt vervangen door geolocator foreground service)

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
2. ~~**Geluidje bij destination reached (foreground)**~~ – `just_audio` speelt
   `assets/sounds/destination_reached.wav` af zodra GPS-radius bereikt is. Werkt in
   voorgrond. Nog niet gecommit – wordt meegenomen in foreground-service commit.
   Gewijzigde bestanden: `pubspec.yaml` (assets sectie), `lib/pages/hike.dart`
   (`_chimePlayer`, `_playDestinationChime()`, aanroep in `setupLocationThings()`).

## Codebase structuur (geverifieerd)
```
lib/
├── main.dart                    # Entry point, WorkManager setup
├── theme.dart                   # Material 3, brand color #266619
├── pages/
│   ├── home.dart                # Login (teamcode invoer)
│   └── hike.dart                # Hoofd-hike scherm (route weergave, GPS, confirm)
├── services/
│   ├── socket.dart              # WebSocket (ws://116.203.112.220:80/ws/app/)
│   ├── location.dart            # Destination model, GPS radius check, parseDestinations()
│   ├── auth.dart                # Login + permissions helper
│   ├── storage.dart             # SharedPreferences wrapper
│   └── cron_job.dart            # Ongebruikt
└── widgets/
    ├── routes.dart              # Route type dispatcher (coordinate/image/audio)
    ├── bundle.dart              # BundleView (NIEUW) – PageView met swipe, dots, lock/blur
    ├── map.dart                 # flutter_map component
    ├── audio.dart               # just_audio player widget
    ├── loading.dart             # Spinner
    └── legendrow.dart           # GPS legend
```

## Actieve taken

### [PRIO 1] Foreground service voor achtergrond GPS + geluid ← VOLGENDE TAAK
**Zie gedetailleerd plan in `../CLAUDE.md` onder "Plan: Foreground service".**
Samenvatting:
- Gebruik `geolocator`'s ingebouwde `ForegroundNotificationConfig` (geen extra package)
- Android permissions toevoegen (FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, ACCESS_BACKGROUND_LOCATION)
- `currentLocationStream` omzetten naar `AndroidSettings` met foreground service
- WorkManager volledig verwijderen (`pubspec.yaml`, `main.dart`, `hike.dart`, `cron_job.dart`)
- Geluid (`_playDestinationChime()`) werkt automatisch mee doordat de app actief blijft
- Testen met scherm uit, dan committen + pushen

### [PRIO 2] Competitie zichtbaar tijdens route
**Voorstel voor CC om uit te werken**:
Stel een concreet voorstel voor op basis van de bestaande architectuur. Mogelijke richtingen:
- Optie A: Live scorebord – teams gesorteerd op aantal voltooide checkpoints + snelheid
- Optie B: Kaartweergave – andere teams (geanonimiseerd of met teamnaam) op de kaart
- Optie C: Combinatie – compact scorebord-icoontje + optionele kaartlaag
Geef aan welke server-aanpassingen elk optie vereist.

### [PRIO 4] Berichten sturen/ontvangen
- Verifieer of de server al een messaging endpoint heeft
- Chat-achtig scherm per editie of globaal?
- Push notifications gewenst? (vereist FCM integratie – vraag aan gebruiker)

### [PRIO 5] Locatie delen
**Doel**: periodiek of op verzoek van de server de GPS-locatie van het team uploaden.
- Achtergrond locatie vereist `background_locator` of `geolocator` met background mode
- Vraag aan gebruiker: hoe frequent uploaden? (bijv. elke 30 sec, of alleen op verzoek?)
- Verifieer bestaand locatie-mechanisme in de code

### [PRIO 6] Route datum + locatielogs filteren
- Voeg `date` veld toe aan het route/editie model (verifieer of dit al bestaat)
- Locatielogs filteren op datum in de beheerapplicatie (server-kant) en/of app

### [PRIO 7] GPS fix feedback
- Toon de huidige GPS-nauwkeurigheid visueel (bijv. icoontje met kleur: rood/oranje/groen)
- Gebruik `geolocator` accuracy veld

### [PRIO 8] Help menu
- Statische of dynamische helpteksten per scherm
- Verifieer of er al een settings/about scherm is om op te hangen

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

## Belangrijk: API-contract
De app communiceert met de Django server via **WebSocket** (niet REST). **Pas nooit de verwachte
message structuur aan** zonder ook de server aan te passen én dit te vermelden aan de gebruiker.
Documenteer API-wijzigingen in `../CLAUDE.md` onder "Bundel-functionaliteit".

## Bekende issue: package naam mismatch
pubspec.yaml heeft `name: TapawingoHike` maar alle imports gebruiken `package:tapa_hike/...`.
`flutter analyze` toont veel false-positive errors hierdoor. De app compileert en draait wel correct.
