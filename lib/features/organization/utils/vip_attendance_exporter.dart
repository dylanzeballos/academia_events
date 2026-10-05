import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/excel_report_helpers.dart';
import '../../../data/models/vip_attendance_model.dart';

/// Genera el informe VIP mensual de la organización con el formato del Excel
/// demostrativo:
///   NOMBRES · ESTADO DE INSCRIPCION · TOTAL DE SESIONES · SESIONES ASISTIDAS ·
///   una columna por clase · INGRESO ECONOMICO.
///
/// Solo incluye a los alumnos VIP (con pase de clase activo) y las clases del
/// mes donde hubo check-in.
class VipAttendanceExporter {
  VipAttendanceExporter._();

  static const List<String> _months = [
    'ENERO',
    'FEBRERO',
    'MARZO',
    'ABRIL',
    'MAYO',
    'JUNIO',
    'JULIO',
    'AGOSTO',
    'SEPTIEMBRE',
    'OCTUBRE',
    'NOVIEMBRE',
    'DICIEMBRE',
  ];

  static Future<void> export(VipAttendanceData data) async {
    final excel = buildExcel(data);
    final bytes = excel.encode();
    if (bytes == null) {
      throw const VipExportException('No se pudo generar el archivo.');
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/Informe_VIP_${data.monthStart.year}'
      '_${data.monthStart.month.toString().padLeft(2, '0')}.xlsx',
    );
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Informe VIP mensual',
      ),
    );
  }

  static Excel buildExcel(VipAttendanceData data) {
    final classes = [...data.classes]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final excel = Excel.createExcel();
    const sheetName = 'Informe VIP';
    final sheet = excel[sheetName];
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.delete(defaultSheet);
    }

    final columns = 4 + classes.length + 1;
    final title =
        'INFORME DE SESION VIP MES ${_monthLabel(data.monthStart)}';
    ExcelReportHelpers.writeTitle(sheet, title, columns);

    final headers = <String>[
      'NOMBRES',
      'ESTADO DE INSCRIPCION',
      'TOTAL DE SESIONES',
      'SESIONES ASISTIDAS',
      for (final c in classes) c.title.toUpperCase(),
      'INGRESO ECONOMICO',
    ];
    ExcelReportHelpers.writeHeader(sheet, 1, headers);

    var row = 2;
    for (final student in data.students) {
      var col = 0;
      ExcelReportHelpers.setText(sheet, row, col++, student.fullName);
      ExcelReportHelpers.setText(sheet, row, col++, 'VIP');
      ExcelReportHelpers.setNumber(sheet, row, col++, classes.length);
      ExcelReportHelpers.setNumber(
        sheet,
        row,
        col++,
        data.attendedClasses(student.userId),
      );
      for (final klass in classes) {
        final mark = data.markFor(student.userId, klass.id);
        ExcelReportHelpers.setText(
          sheet,
          row,
          col++,
          mark == null ? '' : ExcelReportHelpers.formatDateTime(mark),
        );
      }
      ExcelReportHelpers.setNumber(
        sheet,
        row,
        col,
        data.incomeFor(student.userId),
      );
      row++;
    }

    sheet.setColumnWidth(0, 24);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 16);
    sheet.setColumnWidth(3, 18);
    for (var i = 0; i < classes.length; i++) {
      sheet.setColumnWidth(4 + i, 20);
    }
    sheet.setColumnWidth(4 + classes.length, 18);

    return excel;
  }

  static String _monthLabel(DateTime date) =>
      '${_months[date.month - 1]} ${date.year}';
}

class VipExportException implements Exception {
  const VipExportException(this.message);
  final String message;
  @override
  String toString() => message;
}
