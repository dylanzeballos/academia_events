import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:academia_events/data/models/class_attendance_model.dart';
import 'package:academia_events/data/models/event_attendance_model.dart';
import 'package:academia_events/data/models/vip_attendance_model.dart';
import 'package:academia_events/features/classes/utils/class_attendance_exporter.dart';
import 'package:academia_events/features/events/utils/event_attendance_exporter.dart';
import 'package:academia_events/features/organization/utils/vip_attendance_exporter.dart';

String _text(Sheet sheet, int col, int row) {
  final value = sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .value;
  if (value is TextCellValue) return value.value.text ?? '';
  return value?.toString() ?? '';
}

num _number(Sheet sheet, int col, int row) {
  final value = sheet
      .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      .value;
  if (value is DoubleCellValue) return value.value;
  if (value is IntCellValue) return value.value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

ClassAttendanceData _sampleData() => ClassAttendanceData.fromJson({
      'capacity': 20,
      'enrolled': 2,
      'class_title': 'Salsa',
      'price': 150,
      'currency': 'BOB',
      'sessions': [
        {
          'session_id': 's1',
          'session_date': '2026-10-01',
          'start_at': '2026-10-01T19:00:00Z',
          'end_at': '2026-10-01T20:00:00Z',
          'status': 'completed',
          'present': 1,
          'late': 0,
          'absent': 0,
          'pending': 1,
        },
        {
          'session_id': 's2',
          'session_date': '2026-10-03',
          'start_at': '2026-10-03T19:00:00Z',
          'end_at': '2026-10-03T20:00:00Z',
          'status': 'completed',
          'present': 1,
          'late': 0,
          'absent': 0,
          'pending': 1,
        },
      ],
      'students': [
        {
          'enrollment_id': 'e1',
          'user_id': 'u1',
          'first_name': 'Ariel',
          'last_name': 'Jaldin',
          'enrollment_status': 'active',
          'sessions_attended': 2,
          'sessions_total': 2,
          'last_attendance_status': 'present',
          'last_check_in_time': '2026-10-03T19:06:00Z',
          'attendance': [
            {
              'session_id': 's1',
              'session_date': '2026-10-01',
              'status': 'present',
              'recorded_at': '2026-10-01T19:05:00Z',
            },
            {
              'session_id': 's2',
              'session_date': '2026-10-03',
              'status': 'present',
              'recorded_at': '2026-10-03T19:06:00Z',
            },
          ],
        },
        {
          'enrollment_id': 'e2',
          'user_id': 'u2',
          'first_name': 'Iver',
          'last_name': 'Coaquira',
          'enrollment_status': 'pending',
          'sessions_attended': 1,
          'sessions_total': 2,
          'last_attendance_status': 'late',
          'last_check_in_time': '2026-10-01T19:20:00Z',
          'attendance': [
            {
              'session_id': 's1',
              'session_date': '2026-10-01',
              'status': 'late',
              'recorded_at': '2026-10-01T19:20:00Z',
            },
          ],
        },
      ],
    });

void main() {
  group('ClassAttendanceExporter informe mensual', () {
    test('genera columnas por sesion, totales e ingreso economico', () {
      final data = _sampleData();
      final excel = ClassAttendanceExporter.buildMonthlyExcel(
        data: data,
        classTitle: 'Salsa',
      );
      final sheet = excel['Informe mensual'];

      // Titulo combinado en A1.
      expect(_text(sheet, 0, 0), contains('INFORME MENSUAL CLASE SALSA'));

      // Cabeceras.
      expect(_text(sheet, 0, 1), 'NOMBRES');
      expect(_text(sheet, 1, 1), 'ESTADO DE INSCRIPCION');
      expect(_text(sheet, 2, 1), 'TOTAL DE SESIONES');
      expect(_text(sheet, 3, 1), 'SESIONES ASISTIDAS');
      expect(_text(sheet, 4, 1), '1 CHECK-IN');
      expect(_text(sheet, 5, 1), '2 CHECK-IN');
      expect(_text(sheet, 6, 1), 'INGRESO ECONOMICO');

      // Primera fila de datos: Ariel, activo, 2/2, ingreso 150.
      expect(_text(sheet, 0, 2), 'Ariel Jaldin');
      expect(_text(sheet, 1, 2), 'ACTIVO');
      expect(_number(sheet, 2, 2), 2);
      expect(_number(sheet, 3, 2), 2);
      expect(_text(sheet, 4, 2), contains('/'));
      expect(_text(sheet, 5, 2), contains('/'));
      expect(_number(sheet, 6, 2), 150);

      // Segunda fila: Iver, pendiente, solo asistio la sesion 1.
      expect(_text(sheet, 0, 3), 'Iver Coaquira');
      expect(_text(sheet, 1, 3), 'PENDIENTE');
      expect(_number(sheet, 3, 3), 1);
      expect(_text(sheet, 4, 3), contains('/'));
      expect(_text(sheet, 5, 3), '');
      expect(_number(sheet, 6, 3), 75);
    });
  });

  group('ClassAttendanceExporter informe por sesion', () {
    test('muestra check-in e ingreso de una sola sesion', () {
      final data = _sampleData();
      final excel = ClassAttendanceExporter.buildSessionExcel(
        data: data,
        session: data.sessions.first,
        classTitle: 'Salsa',
      );
      final sheet = excel['Informe sesion'];

      expect(_text(sheet, 0, 1), 'NOMBRES');
      expect(_text(sheet, 5, 1), 'INGRESO ECONOMICO');
      // Ariel asistio: ingreso = 150/2 = 75.
      expect(_number(sheet, 5, 2), 75);
      // Iver asistio (tarde): 75.
      expect(_number(sheet, 5, 3), 75);
    });
  });

  group('EventAttendanceExporter informe de ingresos', () {
    test('genera NOMBRE, CHECK-IN y MONTO BS', () {
      final attendees = [
        EventAttendee.fromJson({
          'user_id': 'u1',
          'first_name': 'Dylan',
          'last_name': '',
          'ticket_number': 'T1',
          'ticket_type': 'General',
          'ticket_price': 10,
          'currency': 'BOB',
          'ticket_status': 'used',
          'checked_in': true,
          'check_in_time': '2026-10-01T21:30:00Z',
        }),
      ];
      final excel = EventAttendanceExporter.buildExcel(attendees, 'El mejor social');
      final sheet = excel['Informe'];

      expect(_text(sheet, 0, 1), 'NOMBRE');
      expect(_text(sheet, 1, 1), 'CHECK-IN');
      expect(_text(sheet, 2, 1), 'MONTO BS');
      expect(_text(sheet, 0, 2), 'Dylan');
      expect(_number(sheet, 2, 2), 10);
    });
  });

  group('VipAttendanceExporter informe VIP mensual', () {
    test('cruza alumnos VIP con clases y calcula ingreso', () {
      final data = VipAttendanceData.fromJson({
        'month_start': '2026-10-01',
        'classes': [
          {'id': 'c1', 'title': 'Bachata', 'price': 200, 'currency': 'BOB', 'sessions': 10},
          {'id': 'c2', 'title': 'Salsa', 'price': 150, 'currency': 'BOB', 'sessions': 10},
        ],
        'students': [
          {'user_id': 'u1', 'first_name': 'Ariel', 'last_name': 'Jaldin'},
          {'user_id': 'u2', 'first_name': 'Iver', 'last_name': 'Coaquira'},
        ],
        'marks': [
          {'user_id': 'u1', 'class_id': 'c1', 'recorded_at': '2026-10-02T19:05:00Z'},
          {'user_id': 'u1', 'class_id': 'c2', 'recorded_at': '2026-10-03T19:05:00Z'},
        ],
      });
      final excel = VipAttendanceExporter.buildExcel(data);
      final sheet = excel['Informe VIP'];

      expect(_text(sheet, 0, 0), contains('INFORME DE SESION VIP MES OCTUBRE 2026'));
      expect(_text(sheet, 0, 1), 'NOMBRES');
      expect(_text(sheet, 4, 1), 'BACHATA');
      expect(_text(sheet, 5, 1), 'SALSA');
      expect(_text(sheet, 6, 1), 'INGRESO ECONOMICO');

      // Ariel: 2 clases asistidas, ingreso 200/10 + 150/10 = 35.
      expect(_text(sheet, 0, 2), 'Ariel Jaldin');
      expect(_number(sheet, 3, 2), 2);
      expect(_number(sheet, 6, 2), 35);

      // Iver: sin check-in.
      expect(_number(sheet, 3, 3), 0);
      expect(_number(sheet, 6, 3), 0);
    });
  });
}
