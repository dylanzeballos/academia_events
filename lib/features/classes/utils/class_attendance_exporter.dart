import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/class_attendance_model.dart';

/// Exporta el roster de estudiantes inscritos de una clase a un .xlsx y lo
/// comparte.
class ClassAttendanceExporter {
  ClassAttendanceExporter._();

  static Future<void> exportToExcel(
    List<ClassStudent> students,
    String classTitle,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Inscritos'];

    sheet.appendRow([
      TextCellValue('Nombre'),
      TextCellValue('Estado de inscripción'),
      TextCellValue('Sesiones asistidas'),
      TextCellValue('Total de sesiones'),
      TextCellValue('Último estado'),
      TextCellValue('Último check-in'),
    ]);

    for (final s in students) {
      sheet.appendRow([
        TextCellValue(s.fullName),
        TextCellValue(_enrollmentLabel(s.enrollmentStatus)),
        IntCellValue(s.sessionsAttended),
        IntCellValue(s.sessionsTotal),
        TextCellValue(_attendanceLabel(s.lastAttendanceStatus)),
        TextCellValue(_timeLabel(s.lastCheckInTime)),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw const AttendanceExportException('No se pudo generar el archivo.');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Inscritos_${_sanitize(classTitle)}.xlsx');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Lista de inscritos de $classTitle',
      ),
    );
  }

  static String _enrollmentLabel(String status) => switch (status) {
        'active' => 'Activa',
        'approved' => 'Aprobada',
        'pending' => 'Pendiente',
        'cancelled' => 'Cancelada',
        'rejected' => 'Rechazada',
        'completed' => 'Completada',
        _ => status,
      };

  static String _attendanceLabel(String? status) => switch (status) {
        'present' => 'Presente',
        'late' => 'Tarde',
        'absent' => 'Ausente',
        _ => 'Sin registrar',
      };

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