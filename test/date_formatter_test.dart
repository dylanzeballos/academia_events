import 'package:flutter_test/flutter_test.dart';

import 'package:academia_events/core/utils/date_formatter.dart';

void main() {
  group('rangeCoversDay', () {
    // El evento social bachatero: 19:00 del 2/9 → 14:00 del 3/9
    final start = DateTime(2026, 9, 2, 19);
    final end = DateTime(2026, 9, 3, 14);

    test('cubre el día de inicio', () {
      expect(
        DateFormatter.rangeCoversDay(
          start,
          end,
          DateTime(2026, 9, 2),
        ),
        isTrue,
      );
    });

    test('cubre el día en que termina (cruza medianoche)', () {
      expect(
        DateFormatter.rangeCoversDay(
          start,
          end,
          DateTime(2026, 9, 3),
        ),
        isTrue,
      );
    });

    test('no cubre días fuera del rango', () {
      expect(
        DateFormatter.rangeCoversDay(
          start,
          end,
          DateTime(2026, 9, 4),
        ),
        isFalse,
      );
      expect(
        DateFormatter.rangeCoversDay(
          start,
          end,
          DateTime(2026, 9, 1),
        ),
        isFalse,
      );
    });
  });

  group('clampRangeToDayMinutes', () {
    final start = DateTime(2026, 9, 2, 19);
    final end = DateTime(2026, 9, 3, 14);

    test('día de inicio: de 19:00 hasta fin de día (1440)', () {
      final range = DateFormatter.clampRangeToDayMinutes(
        start,
        end,
        DateTime(2026, 9, 2),
      );
      expect(range, (1140, 1440));
    });

    test('día de fin: de 00:00 hasta 14:00', () {
      final range = DateFormatter.clampRangeToDayMinutes(
        start,
        end,
        DateTime(2026, 9, 3),
      );
      expect(range, (0, 840));
    });

    test('devuelve null si el día no toca el tramo', () {
      expect(
        DateFormatter.clampRangeToDayMinutes(
          start,
          end,
          DateTime(2026, 9, 4),
        ),
        isNull,
      );
    });

    test('evento en un único día no se recorta', () {
      final singleStart = DateTime(2026, 9, 3, 10);
      final singleEnd = DateTime(2026, 9, 3, 12);
      expect(
        DateFormatter.clampRangeToDayMinutes(
          singleStart,
          singleEnd,
          DateTime(2026, 9, 3),
        ),
        (600, 720),
      );
    });
  });
}