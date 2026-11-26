// lib/core/utils/screen_orientation.dart
import 'package:flutter/services.dart';

/// Bloquea la orientación de la app desde un solo lugar.
///
/// La orientación es estado global del sistema: si una pantalla la cambia y no
/// la restaura, el resto de la app queda "pegada" en esa posición. Centralizar
/// el bloqueo evita repetir el par de llamadas en cada vista.
class ScreenOrientation {
  const ScreenOrientation._();

  /// Permite rotar libremente entre horizontal izquierda y derecha.
  static Future<void> lockLandscape() => SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  /// Vuelve al vertical, que es el modo por defecto de la app.
  static Future<void> lockPortrait() =>
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
}
