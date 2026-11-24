import 'package:excel/excel.dart';

/// Utilidades compartidas para generar los reportes Excel con el formato
/// solicitado (títulos combinados, cabeceras y formato de fecha/hora).
abstract final class ExcelReportHelpers {
  static const String _fontFamily = 'Arial';

  static CellStyle titleStyle() => CellStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );

  static CellStyle headerStyle() => CellStyle(
        fontFamily: _fontFamily,
        fontSize: 10,
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );

  static CellStyle bodyStyle({bool wrap = false}) => CellStyle(
        fontFamily: _fontFamily,
        fontSize: 10,
        textWrapping: wrap ? TextWrapping.WrapText : null,
      );

  static CellStyle numberStyle() => CellStyle(
        fontFamily: _fontFamily,
        fontSize: 10,
        horizontalAlign: HorizontalAlign.Right,
        numberFormat: NumFormat.custom(formatCode: '0.00'),
      );

  static void writeTitle(Sheet sheet, String title, int columns) {
    final start = CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0);
    final end = CellIndex.indexByColumnRow(
      columnIndex: columns - 1,
      rowIndex: 0,
    );
    sheet.cell(start).value = TextCellValue(title);
    sheet.cell(start).cellStyle = titleStyle();
    sheet.merge(start, end);
    sheet.setRowHeight(0, 26);
  }

  static void writeHeader(Sheet sheet, int rowIndex, List<String> headers) {
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex),
      );
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = headerStyle();
    }
    sheet.setRowHeight(rowIndex, 30);
  }

  static void setText(
    Sheet sheet,
    int row,
    int col,
    String value, {
    CellStyle? style,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = TextCellValue(value);
    cell.cellStyle = style ?? bodyStyle();
  }

  static void setNumber(
    Sheet sheet,
    int row,
    int col,
    num value, {
    CellStyle? style,
  }) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = DoubleCellValue(value.toDouble());
    cell.cellStyle = style ?? numberStyle();
  }

  /// Fecha y hora en formato `dd/MM HH:mm` (como en el Excel demostrativo).
  static String formatDateTime(DateTime? time) {
    if (time == null) return '';
    return '${_two(time.day)}/${_two(time.month)} '
        '${_two(time.hour)}:${_two(time.minute)}';
  }

  /// Hora en formato `HH:mm`.
  static String formatTime(DateTime? time) {
    if (time == null) return '';
    return '${_two(time.hour)}:${_two(time.minute)}';
  }

  static String formatDate(DateTime time) =>
      '${_two(time.day)}/${_two(time.month)}/${time.year}';

  /// Rango horario legible `HRS HH:mm-HH:mm` a partir de dos instantes.
  static String formatRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    return 'HRS ${formatTime(start)}-${formatTime(end ?? start)}';
  }

  /// Rango horario legible `HH:mm-HH:mm` a partir de listas de sesiones.
  static String hoursLabel(Iterable<DateTime> starts, Iterable<DateTime> ends) {
    final start = starts.isEmpty ? null : starts.first;
    final end = ends.isEmpty ? null : ends.first;
    if (start == null && end == null) return '';
    return 'HRS ${formatTime(start)}-${formatTime(end ?? start)}';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String sanitize(String title) {
    final cleaned = title.replaceAll(RegExp(r'[^\w\s]'), '');
    return cleaned.replaceAll(RegExp(r'\s+'), '_');
  }
}
