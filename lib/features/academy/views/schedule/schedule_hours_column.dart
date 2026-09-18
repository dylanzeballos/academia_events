import 'package:flutter/material.dart';

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
      decoration: const BoxDecoration(
        color: Color(0xFF141824),
        border: Border(right: BorderSide(color: Color(0xFF222738), width: 1.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${hour.toString().padLeft(2, '0')}:00',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${(hour + 1).toString().padLeft(2, '0')}:00',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 9.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}