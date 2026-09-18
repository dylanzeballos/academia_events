import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../providers/dance_class_provider.dart';
import '../../../classes/views/class_detail_view.dart';

class UpcomingSessionsList extends ConsumerWidget {
  const UpcomingSessionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleEntriesAsync = ref.watch(orgWeeklyScheduleEntriesProvider);

    return scheduleEntriesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Text(
        'Error al cargar sesiones: $e',
        style: const TextStyle(color: Colors.grey),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Card(
            color: context.cardBg,
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No hay clases con días programados aún',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          );
        }

        // Mostrar las primeras 5 entradas de horario activo
        final previewEntries = entries.take(5).toList();

        return Card(
          color: context.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            side: BorderSide(color: context.divider),
          ),
          child: Column(
            children: previewEntries.map((entry) {
              final danceClass = entry.danceClass;
              final schedule = entry.schedule;
              final dayName = schedule.dayName;
              final timeRange =
                  '${schedule.startTime.substring(0, 5)} - ${schedule.endTime.substring(0, 5)}';

              return ListTile(
                onTap: () async {
                  ref.read(selectedClassIdProvider.notifier).select(danceClass.id);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClassDetailView()),
                  );
                  ref.invalidate(orgWeeklyScheduleEntriesProvider);
                  ref.invalidate(orgClassesProvider);
                },
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    danceClass.title.isNotEmpty ? danceClass.title[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  danceClass.title,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE85D04).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dayName,
                        style: const TextStyle(
                          color: Color(0xFFE85D04),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeRange,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}