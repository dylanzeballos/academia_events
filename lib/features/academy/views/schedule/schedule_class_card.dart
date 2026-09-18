import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dance_class_provider.dart';
import '../../../classes/views/class_detail_view.dart';

class ScheduleClassCard extends ConsumerWidget {
  const ScheduleClassCard({super.key, required this.entry});

  final OrgScheduleEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final danceClass = entry.danceClass;
    final schedule = entry.schedule;

    final titleLower = danceClass.title.toLowerCase();
    final bool isKizomba = titleLower.contains('kizomba') || titleLower.contains('urban');
    final bool isFree = titleLower.contains('práctica') || titleLower.contains('pista');
    final bool isBachata = titleLower.contains('bachata');

    final Color badgeBg = isFree
        ? const Color(0xFF475569)
        : isKizomba
            ? const Color(0xFF0EA5E9)
            : isBachata
                ? const Color(0xFFEA580C)
                : const Color(0xFFDB2777);

    final String categoryTag = isFree
        ? 'LIBRE'
        : isKizomba
            ? 'KIZOMBA'
            : (isBachata ? 'BACHATA' : 'SALSA');

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
          color: const Color(0xFF1E2333),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: badgeBg.withValues(alpha: 0.4),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Fila superior: Tag y Hora
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      categoryTag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
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

            // Título de la clase amplio y legible
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                danceClass.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.0,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),

            // Fila inferior: Profesor y Precio
            Row(
              children: [
                Expanded(
                  child: Text(
                    instructor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 8.5,
                    ),
                  ),
                ),
                if (danceClass.price > 0)
                  Text(
                    '${danceClass.price.toInt()} Bs',
                    style: TextStyle(
                      color: badgeBg,
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