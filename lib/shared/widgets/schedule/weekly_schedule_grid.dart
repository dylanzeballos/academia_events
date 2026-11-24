import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/class_presentation.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/dance_class_provider.dart';
import '../app_error_state.dart';
import '../app_feedback.dart';
import '../loading_indicator.dart';
import 'class_detail_sheet.dart';
import 'genre_filter_bar.dart';
import 'schedule_grid_body.dart';

/// Horario semanal de una organización, listo para el público.
///
/// Solo incluye clases publicadas y horarios activos. Se usa en la ficha
/// pública de la academia y en "Explorar clases".
final orgScheduleEntriesProvider =
    FutureProvider.family<List<OrgScheduleEntry>, String>((ref, orgId) async {
      if (orgId.trim().isEmpty) return [];
      final repo = ref.watch(danceClassRepositoryProvider);
      final classes = await repo.fetchOrganizationClasses(orgId);
      // Los borradores quedan visibles únicamente en el panel de la academia.
      final published = classes.where((c) => c.isPublished).toList();
      if (published.isEmpty) return [];

      final entries = <OrgScheduleEntry>[];
      for (final danceClass in published) {
        final schedules = await repo.fetchClassSchedules(danceClass.id);
        for (final s in schedules) {
          if (s.isActive) {
            entries.add(OrgScheduleEntry(schedule: s, danceClass: danceClass));
          }
        }
      }
      return entries;
    });

/// Grilla semanal con filtro por ritmo y ficha de clase en modal.
class WeeklyScheduleGrid extends ConsumerStatefulWidget {
  const WeeklyScheduleGrid({
    super.key,
    required this.organizationId,
    this.showFilters = true,
  });

  final String organizationId;
  final bool showFilters;

  @override
  ConsumerState<WeeklyScheduleGrid> createState() => _WeeklyScheduleGridState();
}

class _WeeklyScheduleGridState extends ConsumerState<WeeklyScheduleGrid> {
  /// `null` = todos los ritmos.
  String? _selectedGenre;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(
      orgScheduleEntriesProvider(widget.organizationId),
    );

    return entriesAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorState(
        message: friendlyError(e),
        onRetry: () =>
            ref.invalidate(orgScheduleEntriesProvider(widget.organizationId)),
      ),
      data: (allEntries) {
        if (allEntries.isEmpty) return const _EmptySchedule();

        final genres =
            allEntries
                .map((e) => classGenre(e.danceClass.title))
                .toSet()
                .toList()
              ..sort();

        int countFor(String genre) => allEntries
            .where((e) => classGenre(e.danceClass.title) == genre)
            .map((e) => e.danceClass.id)
            .toSet()
            .length;

        final entries = _selectedGenre == null
            ? allEntries
            : allEntries
                  .where(
                    (e) => classGenre(e.danceClass.title) == _selectedGenre,
                  )
                  .toList();

        final filterBar = GenreFilterBar(
          genres: genres,
          selected: _selectedGenre,
          onSelected: (genre) => setState(() => _selectedGenre = genre),
          countFor: countFor,
        );

        if (entries.isEmpty) {
          return Column(
            children: [
              filterBar,
              const Expanded(child: _NoClassesForGenre()),
            ],
          );
        }

        return Column(
          children: [
            if (widget.showFilters) filterBar,
            Expanded(
              child: ScheduleGridBody(
                entries: entries,
                onOpenClass: (classId) => _openClassSheet(allEntries, classId),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Ficha rápida en modal: el alumno ve la clase sin perder el horario.
  void _openClassSheet(List<OrgScheduleEntry> entries, String classId) {
    final classEntries = entries
        .where((e) => e.danceClass.id == classId)
        .toList();
    if (classEntries.isEmpty) return;
    final danceClass = classEntries.first.danceClass;
    ClassDetailSheet.show(
      context,
      danceClass: danceClass,
      schedules: classEntries.map((e) => e.schedule).toList(),
      accent: genreColor(classGenre(danceClass.title)),
    );
  }
}

class _NoClassesForGenre extends StatelessWidget {
  const _NoClassesForGenre();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No hay clases de este ritmo en el horario.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textMuted, fontSize: 13.5),
        ),
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sin horario publicado',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                'Esta academia todavía no tiene clases publicadas. '
                'Cuando publique su horario aparecerá acá.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
