import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/display_labels.dart';
import '../../../core/utils/excel_report_helpers.dart';
import '../../../data/models/class_attendance_model.dart';

/// Genera los informes de asistencia de una clase con el formato del Excel
/// demostrativo:
///   * Mensual: NOMBRES · ESTADO DE INSCRIPCION · TOTAL DE SESIONES ·
///     SESIONES ASISTIDAS · N CHECK-IN (una columna por sesión) ·
///     INGRESO ECONOMICO.
///   * Por sesión: NOMBRES · ESTADO DE INSCRIPCION · TOTAL DE SESIONES ·
///     SESIONES ASISTIDAS · CHECK-IN · INGRESO ECONOMICO.
///
/// El ingreso se calcula como `precio de la clase / total de sesiones`
/// multiplicado por las sesiones efectivamente asistidas.
class ClassAttendanceExporter {
  ClassAttendanceExporter._();

  static Future<void> exportMonthly({
    required ClassAttendanceData data,
    required String classTitle,
  }) async {
    final excel = buildMonthlyExcel(data: data, classTitle: classTitle);
    await _share(
      excel,
      'Informe_Mensual_${ExcelReportHelpers.sanitize(classTitle)}.xlsx',
      'Informe mensual de $classTitle',
    );
  }

  static Excel buildMonthlyExcel({
    required ClassAttendanceData data,
    required String classTitle,
  }) {
    final sessions = [...data.sessions]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final excel = _newWorkbook();
    final sheetName = 'Informe mensual';
    final sheet = excel[sheetName];
    _removeDefaultSheet(excel, sheetName);

    final columns = 4 + sessions.length + 1;
    final hours = ExcelReportHelpers.hoursLabel(
      sessions.map((s) => s.startAt),
      sessions.map((s) => s.endAt ?? s.startAt),
    );
    final title = [
      'INFORME MENSUAL CLASE ${classTitle.toUpperCase()}',
      if (hours.isNotEmpty) hours,
    ].join(' ');
    ExcelReportHelpers.writeTitle(sheet, title, columns);

    final headers = <String>[
      'NOMBRES',
      'ESTADO DE INSCRIPCION',
      'TOTAL DE SESIONES',
      'SESIONES ASISTIDAS',
      for (var i = 0; i < sessions.length; i++) '${i + 1} CHECK-IN',
      'INGRESO ECONOMICO',
    ];
    ExcelReportHelpers.writeHeader(sheet, 1, headers);

    final perSession = _perSessionValue(data.price, sessions.length);
    var row = 2;
    for (final student in data.students) {
      var col = 0;
      ExcelReportHelpers.setText(sheet, row, col++, student.fullName);
      ExcelReportHelpers.setText(
        sheet,
        row,
        col++,
        _enrollmentLabel(student.enrollmentStatus),
      );
      ExcelReportHelpers.setNumber(sheet, row, col++, sessions.length);
      ExcelReportHelpers.setNumber(sheet, row, col++, student.attendedCount);
      for (final session in sessions) {
        final record = student.recordForSession(session.sessionId);
        ExcelReportHelpers.setText(
          sheet,
          row,
          col++,
          record == null
              ? ''
              : ExcelReportHelpers.formatDateTime(
                  record.recordedAt ?? record.sessionDate,
                ),
        );
      }
      ExcelReportHelpers.setNumber(
        sheet,
        row,
        col,
        _round(perSession * student.attendedCount),
      );
      row++;
    }

    _applyColumnWidths(sheet, sessions.length);
    return excel;
  }

  static Future<void> exportSession({
    required ClassAttendanceData data,
    required SessionStats session,
    required String classTitle,
  }) async {
    final excel = buildSessionExcel(
      data: data,
      session: session,
      classTitle: classTitle,
    );
    await _share(
      excel,
      'Informe_Sesion_${ExcelReportHelpers.sanitize(classTitle)}'
      '_${ExcelReportHelpers.sanitize(ExcelReportHelpers.formatDate(session.sessionDate))}.xlsx',
      'Informe de sesión de $classTitle',
    );
  }

  static Excel buildSessionExcel({
    required ClassAttendanceData data,
    required SessionStats session,
    required String classTitle,
  }) {
    final excel = _newWorkbook();
    final sheetName = 'Informe sesion';
    final sheet = excel[sheetName];
    _removeDefaultSheet(excel, sheetName);

    const columns = 6;
    final hours = ExcelReportHelpers.formatRange(
      session.startAt,
      session.endAt,
    );
    final title = [
      'INFORME DE SESION ${ExcelReportHelpers.formatDate(session.sessionDate)}',
      'CLASE ${classTitle.toUpperCase()}',
      if (hours.isNotEmpty) hours,
    ].join(' ');
    ExcelReportHelpers.writeTitle(sheet, title, columns);

    ExcelReportHelpers.writeHeader(sheet, 1, const [
      'NOMBRES',
      'ESTADO DE INSCRIPCION',
      'TOTAL DE SESIONES',
      'SESIONES ASISTIDAS',
      'CHECK-IN',
      'INGRESO ECONOMICO',
    ]);

    final totalSessions = data.sessions.length;
    final perSession = _perSessionValue(data.price, totalSessions);
    var row = 2;
    for (final student in data.students) {
      final record = student.recordForSession(session.sessionId);
      var col = 0;
      ExcelReportHelpers.setText(sheet, row, col++, student.fullName);
      ExcelReportHelpers.setText(
        sheet,
        row,
        col++,
        _enrollmentLabel(student.enrollmentStatus),
      );
      ExcelReportHelpers.setNumber(sheet, row, col++, totalSessions);
      ExcelReportHelpers.setNumber(sheet, row, col++, student.attendedCount);
      ExcelReportHelpers.setText(
        sheet,
        row,
        col++,
        record == null
            ? ''
            : ExcelReportHelpers.formatDateTime(
                record.recordedAt ?? record.sessionDate,
              ),
      );
      ExcelReportHelpers.setNumber(
        sheet,
        row,
        col,
        record?.isAttended == true ? _round(perSession) : 0,
      );
      row++;
    }

    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 18);
    sheet.setColumnWidth(4, 18);
    sheet.setColumnWidth(5, 18);

    return excel;
  }

  static Excel _newWorkbook() => Excel.createExcel();

  static void _removeDefaultSheet(Excel excel, String keep) {
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != keep) {
      excel.delete(defaultSheet);
    }
  }

  static void _applyColumnWidths(Sheet sheet, int sessionCount) {
    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 18);
    for (var i = 0; i < sessionCount; i++) {
      sheet.setColumnWidth(4 + i, 16);
    }
    sheet.setColumnWidth(4 + sessionCount, 18);
  }

  static double _perSessionValue(double? price, int sessions) {
    if (price == null || price <= 0 || sessions <= 0) return 0;
    return price / sessions;
  }

  static double _round(num value) =>
      double.parse(value.toStringAsFixed(2));

  static Future<void> _share(Excel excel, String fileName, String text) async {
    final bytes = excel.encode();
    if (bytes == null) {
      throw const AttendanceExportException('No se pudo generar el archivo.');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text),
    );
  }

  static String _enrollmentLabel(String status) => switch (status) {
        'active' => 'ACTIVO',
        'approved' => 'APROBADO',
        'pending' => 'PENDIENTE',
        'cancelled' => 'CANCELADO',
        'rejected' => 'RECHAZADO',
        'completed' => 'COMPLETADO',
        _ => DisplayLabels.status(status).toUpperCase(),
      };
}

class AttendanceExportException implements Exception {
  const AttendanceExportException(this.message);
  final String message;
  @override
  String toString() => message;
}
