import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales del dispositivo (tema, modo de la app).
///
/// Se inicializa en `main()` y se inyecta con `ProviderScope.overrides`, así
/// los providers pueden leerlas de forma sincrónica al arrancar.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider debe sobrescribirse en main()',
  );
});

/// Claves usadas en las preferencias.
abstract final class PreferenceKeys {
  static const themeMode = 'pref_theme_mode';
  static const layoutMode = 'pref_layout_mode';
}
