import 'package:intl/intl.dart';

/// Utilidades de formato de fechas. No contiene lógica de negocio.
class DateFormatter {
  DateFormatter._();

  static final _hourMin = DateFormat('HH:mm');
  static final _dayMonth = DateFormat('d MMM', 'es');
  static final _fullDate = DateFormat('EEEE d MMMM yyyy', 'es');
  static final _shortDay = DateFormat('EEE', 'es'); // Lun, Mar...
  static final _dayNumber = DateFormat('d');
  static final _monthYear = DateFormat('MMMM yyyy', 'es'); // septiembre 2026
  static final _shortMonth = DateFormat('MMM', 'es'); // sep, oct...

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

  /// Mes y año con el mes en mayúscula corto/medio: "septiembre 2026"
  static String monthYear(DateTime dt) => _monthYear.format(dt);

  /// Mes abreviado: "sep"
  static String shortMonth(DateTime dt) => _shortMonth.format(dt);

  /// Capitaliza la primera letra de una cadena ("septiembre" → "Septiembre").
  static String capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  /// Devuelve el domingo que inicia la semana de [reference].
  static DateTime startOfWeek(DateTime reference) {
    final date = DateTime(reference.year, reference.month, reference.day);
    return date.subtract(Duration(days: date.weekday % 7));
  }

  /// Devuelve los 7 días de domingo a sábado de la semana de [reference].
  static List<DateTime> weekDays(DateTime reference) {
    final sunday = startOfWeek(reference);
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  /// Devuelve [count] días consecutivos comenzando en [start].
  ///
  /// Devuelve [count] días consecutivos comenzando en [start].
  static List<DateTime> consecutiveDays(DateTime start, int count) =>
      List.generate(count, (i) => start.add(Duration(days: i)));

  /// Tiempo en minutos desde la medianoche.
  static int minutesFromMidnight(DateTime dt) => dt.hour * 60 + dt.minute;

  /// Duración en minutos entre dos DateTime.
  static int durationMinutes(DateTime start, DateTime end) =>
      end.difference(start).inMinutes;

  /// ¿El tramo [start]–[end] toca el día [day] (inclusive si cruza la
  /// medianoche o dura varios días)?
  static bool rangeCoversDay(DateTime start, DateTime end, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final nextDay = dayStart.add(const Duration(days: 1));
    return start.isBefore(nextDay) && end.isAfter(dayStart);
  }

  /// Recorta el tramo [start]–[end] al día [day] y devuelve los minutos desde
  /// la medianoche del inicio y del fin (el fin puede ser 1440 para "00:00 del
  /// día siguiente"). Devuelve `null` si el tramo no toca ese día.
  ///
  /// Permite dibujar eventos multi-día correctamente: el día de inicio se
  /// muestra desde la hora real hasta fin de día, y los días posteriores
  /// desde 00:00 hasta la hora real de fin.
  static (int, int)? clampRangeToDayMinutes(
    DateTime start,
    DateTime end,
    DateTime day,
  ) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final nextDay = dayStart.add(const Duration(days: 1));

    if (!start.isBefore(nextDay)) return null;
    if (!end.isAfter(dayStart)) return null;

    final clampedStart = start.isBefore(dayStart) ? dayStart : start;
    final clampedEnd = end.isAfter(nextDay) ? nextDay : end;
    final isEndOfDay = !clampedEnd.isBefore(nextDay);

    if (!clampedStart.isBefore(clampedEnd)) return null;

    return (
      minutesFromMidnight(clampedStart),
      isEndOfDay ? 24 * 60 : minutesFromMidnight(clampedEnd),
    );
  }
}
