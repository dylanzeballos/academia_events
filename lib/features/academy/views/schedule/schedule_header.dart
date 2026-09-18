import 'package:flutter/material.dart';

class ScheduleHeader extends StatelessWidget {
  const ScheduleHeader({
    super.key,
    required this.colWidth,
    required this.daysOfWeek,
    required this.headerHeight,
  });

  final double colWidth;
  final List<(int, String, String)> daysOfWeek;
  final double headerHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: headerHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF171B26),
        border: Border(
          bottom: BorderSide(color: Color(0xFF222738), width: 1.2),
        ),
      ),
      child: Row(
        children: daysOfWeek.map((d) {
          return SizedBox(
            width: colWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  d.$2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    letterSpacing: 0.4,
                  ),
                ),
                Text(
                  d.$3,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}