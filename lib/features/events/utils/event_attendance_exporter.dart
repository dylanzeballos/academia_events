import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/event_attendance_model.dart';

/// Exporta la lista de asistentes de un evento a un archivo .xlsx y lo
/// comparte.
class EventAttendanceExporter {
  EventAttendanceExporter._();

  static Future<void> exportToExcel(
    List<EventAttendee> attendees,
    String eventTitle,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Asistentes'];

    sheet.appendRow([
      TextCellValue('Nombre'),
      TextCellValue('Ticket'),
      TextCellValue('Tipo de entrada'),
      TextCellValue('Estado'),
      TextCellValue('Hora de check-in'),
      TextCellValue('Punto de acceso'),
    ]);

    for (final a in attendees) {
      sheet.appendRow([
        TextCellValue(a.fullName),
        TextCellValue(a.ticketNumber),
        TextCellValue(a.ticketType),
        TextCellValue(_statusLabel(a)),
        TextCellValue(_timeLabel(a.checkInTime)),
        TextCellValue(a.accessPoint ?? ''),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw const AttendanceExportException('No se pudo generar el archivo.');
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/Asistentes_${_sanitize(eventTitle)}.xlsx',
    );
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Lista de asistentes de $eventTitle',
      ),
    );
  }

  static String _statusLabel(EventAttendee a) {
    if (a.checkedIn) return 'Ingresó';
    if (a.ticketStatus == 'used') return 'Usado';
    return 'Pendiente';
  }

  static String _timeLabel(DateTime? time) {
    if (time == null) return '';
    return '${_two(time.day)}/${_two(time.month)} '
        '${_two(time.hour)}:${_two(time.minute)}';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _sanitize(String title) {
    final cleaned = title.replaceAll(RegExp(r'[^\w\s]'), '');
    return cleaned.replaceAll(RegExp(r'\s+'), '_');
  }
}

class AttendanceExportException implements Exception {
  const AttendanceExportException(this.message);
  final String message;
  @override
  String toString() => message;
}