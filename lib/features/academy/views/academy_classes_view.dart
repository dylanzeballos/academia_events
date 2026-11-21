// lib/features/academy/views/academy_classes_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/class_presentation.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/schedule/genre_filter_bar.dart';
import '../../../shared/widgets/schedule/schedule_grid_body.dart';
import '../../classes/views/class_create_view.dart';

/// Horario semanal del panel de la academia.
///
/// Usa la misma grilla que el público ([ScheduleGridBody]) más el filtro por
/// ritmo, el resumen publicado/borrador y la acción de crear clase.
class AcademyClassesView extends ConsumerStatefulWidget {
  const AcademyClassesView({super.key});

  @override
  ConsumerState<AcademyClassesView> createState() => _AcademyClassesViewState();
}

class _AcademyClassesViewState extends ConsumerState<AcademyClassesView> {
  /// Ritmo seleccionado para filtrar; `null` = todos.
  String? _selectedGenre;

  Future<void> _openCreateClass() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClassCreateView()),
    );
    if (!mounted) return;
    ref.invalidate(orgClassesProvider);
    ref.invalidate(orgWeeklyScheduleEntriesProvider);
  }

  Future<void> _openClassDetail(String classId) async {
    await context.push('${AppRoutes.classDetail}/$classId');
    if (!mounted) return;
    ref.invalidate(orgClassesProvider);
    ref.invalidate(orgWeeklyScheduleEntriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(orgWeeklyScheduleEntriesProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageClasses ?? false;
    final legendEntries = entriesAsync.value ?? const <OrgScheduleEntry>[];

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        if (mounted) context.go(AppRoutes.academyDashboard);
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: context.cardBg,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Volver al panel',
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: context.textOnBg,
              size: 20,
            ),
            onPressed: () => context.go(AppRoutes.academyDashboard),
          ),
          title: Text(
            'Horario semanal',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: context.textOnBg,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar horario',
              icon: Icon(Icons.refresh_rounded, color: context.textMuted),
              onPressed: () {
                ref.invalidate(orgClassesProvider);
                ref.invalidate(orgWeeklyScheduleEntriesProvider);
              },
            ),
          ],
          bottom: legendEntries.isEmpty
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(38),
                  child: _ScheduleLegend(entries: legendEntries),
                ),
        ),
        body: SafeArea(
          child: entriesAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => AppErrorState(
              message: friendlyError(e),
              onRetry: () {
                ref.invalidate(orgClassesProvider);
                ref.invalidate(orgWeeklyScheduleEntriesProvider);
              },
            ),
            data: (allEntries) {
              if (allEntries.isEmpty) {
                return _buildEmptyState(context, canManage);
              }

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
                          (e) =>
                              classGenre(e.danceClass.title) == _selectedGenre,
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
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No hay clases de este ritmo en el horario.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  filterBar,
                  Expanded(
                    child: ScheduleGridBody(
                      entries: entries,
                      onOpenClass: _openClassDetail,
                      onAddClass: canManage ? _openCreateClass : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        floatingActionButton: canManage
            ? FloatingActionButton.extended(
                tooltip: 'Crear una clase nueva',
                onPressed: _openCreateClass,
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Nueva clase'),
              )
            : null,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool canManage) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
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
            const SizedBox(height: 20),
            Text(
              'Todavía no hay clases en el horario',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                canManage
                    ? 'Creá una clase y elegí los días y horarios en los que se dicta. '
                          'Mientras esté en borrador solo la ves vos.'
                    : 'Pedile a un administrador de la academia que configure el horario.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
            if (canManage) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openCreateClass,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Crear clase'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Resumen del horario: cuántas clases están publicadas y cuántas en borrador.
/// Responde de un vistazo "¿esto lo ve el público?" sin abrir cada clase.
class _ScheduleLegend extends StatelessWidget {
  const _ScheduleLegend({required this.entries});

  final List<OrgScheduleEntry> entries;

  @override
  Widget build(BuildContext context) {
    final classIds = entries.map((e) => e.danceClass.id).toSet();
    final draftIds = entries
        .where((e) => !e.danceClass.isPublished)
        .map((e) => e.danceClass.id)
        .toSet();
    final publishedCount = classIds.length - draftIds.length;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(bottom: BorderSide(color: context.divider)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            _LegendStat(
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              label: publishedCount == 1
                  ? '1 publicada'
                  : '$publishedCount publicadas',
            ),
            if (draftIds.isNotEmpty) ...[
              const SizedBox(width: 14),
              _LegendStat(
                icon: Icons.edit_note_rounded,
                color: AppColors.warning,
                label: draftIds.length == 1
                    ? '1 borrador'
                    : '${draftIds.length} borradores',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendStat extends StatelessWidget {
  const _LegendStat({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: context.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}