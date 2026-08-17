import 'package:intl/intl.dart';

/// Utilidades de formato de fechas. No contiene lógica de negocio.
class DateFormatter {
  DateFormatter._();

  static final _hourMin = DateFormat('HH:mm');
  static final _dayMonth = DateFormat('d MMM', 'es');
  static final _fullDate = DateFormat('EEEE d MMMM yyyy', 'es');
  static final _shortDay = DateFormat('EEE', 'es'); // Lun, Mar...
  static final _dayNumber = DateFormat('d');

  /// Ej: "18:30"
  static String hourMin(DateTime dt) => _hourMin.format(dt);

  /// Ej: "18:30 – 20:00"
  static String timeRange(DateTime start, DateTime end) =>
      '${hourMin(start)} – ${hourMin(end)}';

  /// Ej: "15 Ago"
  static String dayMonth(DateTime dt) => _dayMonth.format(dt);

  /// Ej: "lunes 15 de agosto 2026"
  static String fullDate(DateTime dt) => _fullDate.format(dt);

  /// Abreviatura del día: "Lun"
  static String shortDay(DateTime dt) => _shortDay.format(dt);

  /// Número del día: "15"
  static String dayNumber(DateTime dt) => _dayNumber.format(dt);

  /// Devuelve los 7 días de la semana que contiene [reference].
  static List<DateTime> weekDays(DateTime reference) {
    // Empezar en lunes (weekday==1)
    final monday = reference.subtract(
      Duration(days: reference.weekday - 1),
    );
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  /// Tiempo en minutos desde la medianoche.
  static int minutesFromMidnight(DateTime dt) => dt.hour * 60 + dt.minute;

  /// Duración en minutos entre dos DateTime.
  static int durationMinutes(DateTime start, DateTime end) =>
      end.difference(start).inMinutes;
}
