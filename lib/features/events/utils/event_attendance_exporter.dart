import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/excel_report_helpers.dart';
import '../../../data/models/event_attendance_model.dart';

/// Genera el informe de ingresos de un evento con el formato del Excel
/// demostrativo: NOMBRE · CHECK-IN · MONTO BS.
class EventAttendanceExporter {
  EventAttendanceExporter._();

  static Future<void> exportToExcel(
    List<EventAttendee> attendees,
    String eventTitle,
  ) async {
    final excel = buildExcel(attendees, eventTitle);
    final bytes = excel.encode();
    if (bytes == null) {
      throw const AttendanceExportException('No se pudo generar el archivo.');
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/Ingresos_${ExcelReportHelpers.sanitize(eventTitle)}.xlsx',
    );
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Informe de ingresos de $eventTitle',
      ),
    );
  }

  static Excel buildExcel(List<EventAttendee> attendees, String eventTitle) {
    final excel = Excel.createExcel();
    const sheetName = 'Informe';
    final sheet = excel[sheetName];
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.delete(defaultSheet);
    }

    ExcelReportHelpers.writeTitle(sheet, eventTitle.toUpperCase(), 3);
    ExcelReportHelpers.writeHeader(sheet, 1, const [
      'NOMBRE',
      'CHECK-IN',
      'MONTO BS',
    ]);

    var row = 2;
    for (final attendee in attendees) {
      ExcelReportHelpers.setText(sheet, row, 0, attendee.fullName);
      ExcelReportHelpers.setText(
        sheet,
        row,
        1,
        ExcelReportHelpers.formatDateTime(attendee.checkInTime),
      );
      ExcelReportHelpers.setNumber(sheet, row, 2, attendee.ticketPrice);
      row++;
    }

    sheet.setColumnWidth(0, 26);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 14);

    return excel;
  }
}

class AttendanceExportException implements Exception {
  const AttendanceExportException(this.message);
  final String message;
  @override
  String toString() => message;
}
