import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dance_class_provider.dart';
import '../../../classes/views/class_detail_view.dart';

class ScheduleClassCard extends ConsumerWidget {
  const ScheduleClassCard({
    super.key,
    required this.entry,
    required this.themeColor,
    required this.styleTag,
  });

  final OrgScheduleEntry entry;
  final Color themeColor;
  final String styleTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final danceClass = entry.danceClass;
    final schedule = entry.schedule;
    final instructor = schedule.instructorName ?? danceClass.instructorName ?? 'Profesor';

    return GestureDetector(
      onTap: () async {
        ref.read(selectedClassIdProvider.notifier).select(danceClass.id);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClassDetailView()),
        );
        ref.invalidate(orgClassesProvider);
        ref.invalidate(orgWeeklyScheduleEntriesProvider);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF161B26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: themeColor.withValues(alpha: 0.5),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Cabecera: Tag dinámico + Hora
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      styleTag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  schedule.startTime.substring(0, 5),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 8.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            // Título de la clase
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                danceClass.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),

            // Pie: Profesor y Precio
            Row(
              children: [
                Expanded(
                  child: Text(
                    instructor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 8.0,
                    ),
                  ),
                ),
                if (danceClass.price > 0)
                  Text(
                    '${danceClass.price.toInt()} Bs',
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}