import 'package:flutter/material.dart';

import '../../../../core/utils/theme_extensions.dart';

class ScheduleHoursColumn extends StatelessWidget {
  const ScheduleHoursColumn({
    super.key,
    required this.hour,
    required this.width,
  });

  final int hour;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.surfaceDeep,
        border: Border(right: BorderSide(color: context.divider, width: 1.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${hour.toString().padLeft(2, '0')}:00',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${(hour + 1).toString().padLeft(2, '0')}:00',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 9.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}