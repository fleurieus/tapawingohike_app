import 'package:flutter/material.dart';

const kBrandSeed = Color(0xFF266619);

ThemeData _buildTheme(Brightness brightness) {
  // Start met een seed-based schema
  var scheme = ColorScheme.fromSeed(
    seedColor: kBrandSeed,
    brightness: brightness,
  );

  // In dark mode: forceer dezelfde diepe primaire kleur
  if (brightness == Brightness.dark) {
    scheme = scheme.copyWith(
      primary: kBrandSeed,          // blijf donkergroen
      onPrimary: Colors.white,      // goede leesbaarheid
      // (optioneel) maak de container net wat donkerder voor contrast
      primaryContainer: const Color(0xFF1E4F14),
      onPrimaryContainer: Colors.white,
    );
  }

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.primary,
      textStyle: TextStyle(color: scheme.onPrimary),
      elevation: 6,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.onPrimary.withOpacity(0.24),
      thickness: 1,
      space: 0,
    ),
    // (optioneel) iets neutralere slider/ink e.d. kun je hier ook tunen
  );
}

final ThemeData hikeTheme     = _buildTheme(Brightness.light);
final ThemeData hikeDarkTheme = _buildTheme(Brightness.dark);
