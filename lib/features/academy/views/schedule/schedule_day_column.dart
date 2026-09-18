import 'package:flutter/material.dart';

import '../../../../providers/dance_class_provider.dart';
import 'schedule_class_card.dart';

class ScheduleDayColumn extends StatelessWidget {
  const ScheduleDayColumn({
    super.key,
    required this.dayOfWeek,
    required this.hour,
    required this.entries,
    required this.width,
    required this.genreColorMap,
    this.onAddClass,
  });

  final int dayOfWeek;
  final int hour;
  final List<OrgScheduleEntry> entries;
  final double width;
  final Map<String, Color> genreColorMap;
  final VoidCallback? onAddClass;

  int _parseHour(String timeStr) {
    try {
      final clean = timeStr.trim().split(' ')[0].split('+')[0];
      return int.parse(clean.split(':')[0]);
    } catch (_) {
      return 12;
    }
  }

  String _extractGenre(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return 'CLASE';
    return clean.split(RegExp(r'\s+')).first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final match = entries.where((e) {
      return e.schedule.dayOfWeek == dayOfWeek &&
          _parseHour(e.schedule.startTime) == hour;
    }).firstOrNull;

    if (match == null) {
      return Container(
        width: width,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0xFF181D2A), width: 0.7)),
        ),
        child: Center(
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.add,
              size: 14,
              color: Colors.white.withValues(alpha: 0.04),
            ),
            onPressed: onAddClass,
          ),
        ),
      );
    }

    final tag = _extractGenre(match.danceClass.title);
    final color = genreColorMap[tag] ?? const Color(0xFF6366F1);

    return Container(
      width: width,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF181D2A), width: 0.7)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
      child: ScheduleClassCard(
        entry: match,
        themeColor: color,
        styleTag: tag,
      ),
    );
  }
}