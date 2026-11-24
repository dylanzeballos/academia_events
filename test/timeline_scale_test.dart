import 'package:flutter_test/flutter_test.dart';

import 'package:academia_events/features/calendar/widgets/column/timeline_scale.dart';

void main() {
  test('collapses empty weekly hours without shrinking active hours', () {
    final scale = TimelineScale(
      startHour: 6,
      endHour: 23,
      activeHours: {7, 8, 10, 21, 22},
      activePxPerHour: 48,
      collapseInactiveHours: true,
    );

    expect(scale.pxPerHourAt(7), 48);
    expect(scale.pxPerHourAt(9), 4);
    expect(scale.isActiveHour(10), isTrue);
    expect(scale.isActiveHour(9), isFalse);
    expect(scale.shouldDrawHourBoundary(12), isFalse);
    expect(scale.shouldDrawHourBoundary(10), isTrue);
    expect(scale.shouldDrawHourBoundary(21), isTrue);
  });

  test('manual zoom enlarges active hours and compact gaps equally', () {
    final scale = TimelineScale(
      startHour: 6,
      endHour: 23,
      activeHours: {7, 8, 10, 21, 22},
      activePxPerHour: 48,
      zoom: 2,
      collapseInactiveHours: true,
    );

    expect(scale.pxPerHourAt(7), 96);
    expect(scale.pxPerHourAt(9), 8);
  });

  test('keeps normal empty hours in the single-day view', () {
    final scale = TimelineScale(
      startHour: 0,
      endHour: 24,
      activeHours: {7, 8, 9},
      activePxPerHour: 48,
    );

    expect(scale.pxPerHourAt(6), 28);
    expect(scale.pxPerHourAt(7), 48);
  });

  test('centers a short weekly timeline without changing its scale', () {
    final scale = TimelineScale(
      startHour: 19,
      endHour: 23,
      activeHours: {19, 20, 21, 22},
      activePxPerHour: 48,
      availableHeight: 400,
      centerContentIfShort: true,
    );

    expect(scale.totalHeight, 400);
    expect(scale.topAt(19), 104);
    expect(scale.pxPerHourAt(19), 48);
  });
}
