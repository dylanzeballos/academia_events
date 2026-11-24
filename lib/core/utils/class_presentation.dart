import 'package:flutter/material.dart';

/// Presentación compartida de clases en las grillas semanales.

/// Paleta de acentos por ritmo. Se indexa con el hash del género para que el
/// color de cada clase se mantenga estable entre sesiones y publicaciones.
const List<Color> genrePalette = [
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
  Color(0xFF3B82F6),
  Color(0xFFF97316),
  Color(0xFF14B8A6),
  Color(0xFFA855F7),
  Color(0xFF84CC16),
  Color(0xFF6366F1),
];

/// "salsa prueba sesión" → "SALSA".
String classGenre(String title) {
  final clean = title.trim();
  if (clean.isEmpty) return 'CLASE';
  return clean.split(RegExp(r'\s+')).first.toUpperCase();
}

Color genreColor(String genre) =>
    genrePalette[genre.hashCode.abs() % genrePalette.length];

/// '19:00:00' → '19:00'.
String hhmm(String value) {
  final clean = value.trim();
  return clean.length >= 5 ? clean.substring(0, 5) : clean;
}

/// Días de la semana con la numeración que usa la base (1 = lunes, 0 = domingo).
const List<(int, String, String)> weekDays = [
  (1, 'LUN', 'LUNES'),
  (2, 'MAR', 'MARTES'),
  (3, 'MIÉ', 'MIÉRCOLES'),
  (4, 'JUE', 'JUEVES'),
  (5, 'VIE', 'VIERNES'),
  (6, 'SÁB', 'SÁBADO'),
  (0, 'DOM', 'DOMINGO'),
];

const List<String> _dayNames = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// 1 → 'lunes', 0 → 'domingo'.
String weekdayName(int dayOfWeek) {
  final index = dayOfWeek == 0 ? 6 : dayOfWeek - 1;
  return _dayNames[index.clamp(0, 6)];
}

/// '19' → '19:00'.
String hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';
