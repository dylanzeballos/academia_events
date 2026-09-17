import 'package:flutter/material.dart';
import 'timeline_scale.dart';

class TimelineLabels extends StatelessWidget {
  const TimelineLabels({super.key, required this.scale});

  final TimelineScale scale;
  static const double _minLabelGap = 14;

  @override
  Widget build(BuildContext context) {
    if (scale.totalHours <= 0) return const SizedBox.shrink();

    final children = <Widget>[];
    final totalHours = scale.totalHours;
    for (var i = 0; i <= totalHours; i++) {
      final hour = scale.startHour + i;
      final isBoundary = i == 0 || i == totalHours;
      final segPx = i < totalHours
          ? scale.pxPerHourAt(hour)
          : scale.pxPerHourAt(hour - 1);
      final step = segPx >= _minLabelGap
          ? 1
          : (segPx >= _minLabelGap / 2 ? 2 : 3);
      if (!isBoundary && i % step != 0) continue;

      final top = scale.topAt(hour);
      final y = isBoundary ? top - 11 : top + 1;
      children.add(
        Positioned(
          top: y,
          left: 0,
          right: 4,
          child: Text(
            '${hour.toString().padLeft(2, '0')}:00',
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ),
      );
    }

    return SizedBox(
      height: scale.totalHeight,
      child: Stack(children: children),
    );
  }
}