import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/preferences.dart';

/// Tema de la app: claro, oscuro o según el sistema.
///
/// La elección se guarda en el dispositivo y se restaura al abrir la app.
/// Sin elección previa se usa [ThemeMode.system].
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref
        .read(sharedPreferencesProvider)
        .getString(PreferenceKeys.themeMode);

    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void set(ThemeMode mode) {
    if (state == mode) return;
    state = mode;
    ref
        .read(sharedPreferencesProvider)
        .setString(PreferenceKeys.themeMode, mode.name);
  }

  /// Alterna entre claro y oscuro (el botón rápido no usa "sistema").
  void toggle() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDarkNow = switch (state) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => brightness == Brightness.dark,
    };
    set(isDarkNow ? ThemeMode.light : ThemeMode.dark);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Texto legible del tema seleccionado.
String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'Claro',
  ThemeMode.dark => 'Oscuro',
  ThemeMode.system => 'Según el sistema',
};
