// lib/features/academy/views/dashboard/upcoming_sessions_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../providers/dance_class_provider.dart';

/// Vista previa del panel: **una sola** próxima sesión, la más cercana de una
/// clase **publicada**.
///
/// Si todavía no hay sesiones generadas cae al próximo horario semanal
/// publicado, para no dejar la tarjeta vacía.
class UpcomingSessionsList extends ConsumerWidget {
  const UpcomingSessionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextAsync = ref.watch(nextOrgSessionProvider);

    return nextAsync.when(
      loading: () => const _SessionsCard(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
      error: (e, _) => const _SessionsCard(
        child: _NoSessionMessage(
          message: 'No se pudo cargar la próxima sesión.',
        ),
      ),
      data: (next) {
        if (next != null) {
          return _SessionsCard(
            child: _NextSessionTile(
              title: next.classTitle,
              start: next.startAt,
              end: next.endAt,
              label: 'Próxima sesión',
              onTap: () => _openClass(context, ref, next.classId),
            ),
          );
        }

        // Sin sesiones generadas: próximo horario, solo de clases publicadas.
        final entries = ref
            .watch(orgWeeklyScheduleEntriesProvider)
            .value
            ?.where((e) => e.danceClass.isPublished)
            .toList();
        final upcoming = _nearestOccurrence(entries ?? const []);
        if (upcoming == null) {
          return const _SessionsCard(
            child: _NoSessionMessage(
              message: 'No hay sesiones programadas todavía.',
            ),
          );
        }

        return _SessionsCard(
          child: _NextSessionTile(
            title: upcoming.entry.danceClass.title,
            start: upcoming.start,
            end: upcoming.end,
            label: 'Horario programado',
            onTap: () => _openClass(context, ref, upcoming.entry.danceClass.id),
          ),
        );
      },
    );
  }

  Future<void> _openClass(
    BuildContext context,
    WidgetRef ref,
    String classId,
  ) async {
    await context.push('${AppRoutes.classDetail}/$classId');
    ref.invalidate(nextOrgSessionProvider);
    ref.invalidate(orgWeeklyScheduleEntriesProvider);
    ref.invalidate(orgClassesProvider);
  }

  /// Próxima ocurrencia (fecha real) entre los horarios semanales.
  ({OrgScheduleEntry entry, DateTime start, DateTime end})? _nearestOccurrence(
    List<OrgScheduleEntry> entries,
  ) {
    if (entries.isEmpty) return null;
    final now = DateTime.now();

    ({OrgScheduleEntry entry, DateTime start, DateTime end})? best;
    for (final entry in entries) {
      final startTime = _parseTime(entry.schedule.startTime);
      final endTime = _parseTime(entry.schedule.endTime);
      final targetDay = entry.schedule.dayOfWeek == 0
          ? 7
          : entry.schedule.dayOfWeek;

      var daysAhead = (targetDay - now.weekday) % 7;
      if (daysAhead < 0) daysAhead += 7;

      var start = DateTime(
        now.year,
        now.month,
        now.day,
        startTime.$1,
        startTime.$2,
      ).add(Duration(days: daysAhead));
      if (start.isBefore(now)) start = start.add(const Duration(days: 7));
      final end = DateTime(
        start.year,
        start.month,
        start.day,
        endTime.$1,
        endTime.$2,
      );

      if (best == null || start.isBefore(best.start)) {
        best = (entry: entry, start: start, end: end);
      }
    }
    return best;
  }

  (int, int) _parseTime(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (hour, minute);
  }
}

class _SessionsCard extends StatelessWidget {
  const _SessionsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: context.divider),
      ),
      child: child,
    );
  }
}

class _NextSessionTile extends StatelessWidget {
  const _NextSessionTile({
    required this.title,
    required this.start,
    required this.end,
    required this.label,
    required this.onTap,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = start.toLocal();
    final localEnd = end.toLocal();

    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormatter.capitalize(DateFormatter.shortDay(local))} '
                    '${DateFormatter.dayMonth(local)} · '
                    '${DateFormatter.timeRange(local, localEnd)}',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSessionMessage extends StatelessWidget {
  const _NoSessionMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, size: 20, color: context.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
