// lib/features/classes/views/class_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_publication_status.dart';
import '../../../data/models/dance_class_schedule_model.dart';
import '../../../data/models/dance_class_session_model.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../data/services/pagosya_service.dart';
import '../../tickets/views/pagosya_checkout_screen.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/schedule_dialog.dart';
import 'class_attendance_view.dart';

class ClassDetailView extends ConsumerStatefulWidget {
  const ClassDetailView({super.key, this.classId});

  final String? classId;

  @override
  ConsumerState<ClassDetailView> createState() => _ClassDetailViewState();
}

class _ClassDetailViewState extends ConsumerState<ClassDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    final id = widget.classId;
    if (id != null && id.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedClassIdProvider.notifier).select(id);
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classAsync = ref.watch(selectedClassProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageClasses ?? false;

    return classAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (e, _) => Scaffold(body: AppErrorState(message: friendlyError(e))),
      data: (danceClass) {
        if (danceClass == null) {
          return const Scaffold(
            body: Center(child: Text('Clase no encontrada')),
          );
        }

        return Scaffold(
          backgroundColor: context.scaffoldBg,
          appBar: AppBar(
            backgroundColor: context.cardBg,
            elevation: 0,
            title: Text(
              danceClass.title,
              style: TextStyle(
                color: context.textOnBg,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ClassAttendanceView(
                      classId: danceClass.id,
                      classTitle: danceClass.title,
                    ),
                  ),
                ),
                icon: const Icon(Icons.assessment_outlined, size: 18),
                label: const Text('Asistencia'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 4),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: context.textMuted,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Info'),
                Tab(
                  icon: Icon(Icons.schedule_outlined, size: 18),
                  text: 'Horarios',
                ),
                Tab(
                  icon: Icon(Icons.event_note_outlined, size: 18),
                  text: 'Sesiones',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _InfoTab(danceClass: danceClass, canManage: canManage),
              const _SchedulesTab(),
              const _SessionsTab(),
            ],
          ),
        );
      },
    );
  }
}

class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.danceClass, required this.canManage});

  final dynamic danceClass;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDetails =
        danceClass.danceCategoryName != null ||
        danceClass.instructorName != null ||
        danceClass.capacity != null ||
        danceClass.startTime != null ||
        danceClass.endTime != null ||
        (danceClass.description != null && danceClass.description!.isNotEmpty);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClassHeader(danceClass: danceClass),
          const SizedBox(height: 16),
          if (hasDetails)
            AppSectionCard(
              title: 'Detalle de la clase',
              icon: Icons.info_outline_rounded,
              children: [
                if (danceClass.danceCategoryName != null)
                  _InfoRow(
                    label: 'Ritmo',
                    value: danceClass.danceCategoryName!,
                  ),
                if (danceClass.instructorName != null)
                  _InfoRow(
                    label: 'Instructor',
                    value: danceClass.instructorName!,
                  ),
                if (danceClass.capacity != null)
                  _InfoRow(label: 'Cupos', value: '${danceClass.capacity}'),
                if (danceClass.startTime != null)
                  _InfoRow(
                    label: 'Inicio',
                    value:
                        '${danceClass.startTime!.day}/${danceClass.startTime!.month}/${danceClass.startTime!.year}',
                  ),
                if (danceClass.endTime != null)
                  _InfoRow(
                    label: 'Fin',
                    value:
                        '${danceClass.endTime!.day}/${danceClass.endTime!.month}/${danceClass.endTime!.year}',
                  ),
                if (danceClass.description != null &&
                    danceClass.description!.isNotEmpty)
                  _InfoRow(
                    label: 'Descripción',
                    value: danceClass.description!,
                  ),
              ],
            ),
          const SizedBox(height: 12),
          AppSectionCard(
            title: 'Precios',
            icon: Icons.payments_outlined,
            trailing: canManage
                ? TextButton(
                    onPressed: () => _editPrices(context, ref, danceClass),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Editar', style: TextStyle(fontSize: 12)),
                  )
                : null,
            children: [
              _InfoRow(
                label: 'Precio por sesión',
                value: '${danceClass.price} ${danceClass.currency}',
              ),
              if (danceClass.priceMonthly > 0)
                _InfoRow(
                  label: 'Pase mensual',
                  value: '${danceClass.priceMonthly} ${danceClass.currency}',
                )
              else
                _InfoRow(label: 'Pase mensual', value: 'No se ofrece'),
            ],
          ),
          if (canManage) ...[
            const SizedBox(height: 16),
            _PublicationCard(danceClass: danceClass),
          ],
        ],
      ),
    );
  }

  Future<void> _editPrices(
    BuildContext context,
    WidgetRef ref,
    dynamic danceClass,
  ) async {
    final sessionCtrl = TextEditingController(
      text: (danceClass.price as num?)?.toString() ?? '0',
    );
    final monthlyCtrl = TextEditingController(
      text: (danceClass.priceMonthly as num?)?.toString() ?? '0',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(
          'Editar precios',
          style: TextStyle(color: context.textOnBg),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sessionCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: context.textOnBg),
              decoration: InputDecoration(
                labelText: 'Precio por sesión (BOB)',
                labelStyle: TextStyle(color: context.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: monthlyCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: context.textOnBg),
              decoration: InputDecoration(
                labelText: 'Precio mensual (BOB)',
                helperText: '0 = no ofrecer pase mensual',
                helperStyle: TextStyle(color: context.textMuted, fontSize: 11),
                labelStyle: TextStyle(color: context.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) {
      sessionCtrl.dispose();
      monthlyCtrl.dispose();
      return;
    }

    try {
      await ref.read(danceClassRepositoryProvider).updateClass(danceClass.id, {
        'price': double.tryParse(sessionCtrl.text.replaceAll(',', '.')) ?? 0,
        'price_monthly':
            double.tryParse(monthlyCtrl.text.replaceAll(',', '.')) ?? 0,
      });
      ref.invalidate(selectedClassProvider);
      ref.invalidate(orgClassesProvider);
      if (context.mounted) {
        AppFeedback.success(context, 'Precios actualizados.');
      }
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, friendlyError(e));
    } finally {
      sessionCtrl.dispose();
      monthlyCtrl.dispose();
    }
  }
}

class _SchedulesTab extends ConsumerWidget {
  const _SchedulesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(classSchedulesProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageSchedules ?? false;

    return schedulesAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorState(message: friendlyError(e)),
      data: (schedules) {
        if (schedules.isEmpty) {
          return AppEmptyState(
            icon: Icons.schedule_outlined,
            title: 'Sin horarios definidos',
            message: 'Crea un horario para generar las sesiones de la clase.',
            actionLabel: canManage ? 'Crear horario' : null,
            onAction: canManage
                ? () => _addScheduleAndGenerate(context, ref)
                : null,
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schedules.length == 1
                        ? '1 horario semanal'
                        : '${schedules.length} horarios semanales',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canManage)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _addScheduleAndGenerate(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar horario'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cada horario genera sesiones automáticamente.',
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final s in schedules)
              _ScheduleTile(
                schedule: s,
                onEditCustom: (val) {
                  if (val == 'edit') _editSchedule(context, ref, s);
                  if (val == 'toggle') _toggleSchedule(context, ref, s);
                  if (val == 'delete') _deleteSchedule(context, ref, s);
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _addScheduleAndGenerate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showScheduleDialog(
      context,
      classStart: ref.read(selectedClassProvider).value?.startTime,
      classEnd: ref.read(selectedClassProvider).value?.endTime,
    );
    if (result == null || !context.mounted) return;

    final repo = ref.read(danceClassRepositoryProvider);
    final danceClass = ref.read(selectedClassProvider).value;
    await repo.createSchedule({
      ...result.toJson(),
      'dance_class_id': danceClass?.id,
    });
    await _generateSessions(ref);
    if (!context.mounted) return;
    ref.invalidate(classSchedulesProvider);
    AppFeedback.success(context, 'Horario agregado y sesiones generadas.');
  }

  Future<void> _generateSessions(WidgetRef ref) async {
    final repo = ref.read(danceClassRepositoryProvider);
    final danceClass = ref.read(selectedClassProvider).value;
    if (danceClass == null) return;
    final periodStart = danceClass.startTime ?? DateTime.now();
    final periodEnd =
        danceClass.endTime ?? periodStart.add(const Duration(days: 90));
    await repo.generateSessions(
      classId: danceClass.id,
      startDate: periodStart,
      endDate: periodEnd,
    );
    ref.invalidate(classSessionsPageProvider);
  }

  Future<void> _editSchedule(
    BuildContext context,
    WidgetRef ref,
    DanceClassScheduleModel s,
  ) async {
    final result = await showScheduleDialog(
      context,
      existing: s,
      classStart: ref.read(selectedClassProvider).value?.startTime,
      classEnd: ref.read(selectedClassProvider).value?.endTime,
    );
    if (result == null || !context.mounted) return;

    final repo = ref.read(danceClassRepositoryProvider);
    await repo.updateSchedule(s.id, result.toJson());

    await repo.clearUpcomingSessionsForSchedule(s.id);
    await _generateSessions(ref);
    if (!context.mounted) return;
    ref.invalidate(classSchedulesProvider);
    ref.invalidate(classSessionsPageProvider);
    AppFeedback.success(context, 'Horario actualizado.');
  }

  Future<void> _toggleSchedule(
    BuildContext context,
    WidgetRef ref,
    DanceClassScheduleModel s,
  ) async {
    final repo = ref.read(danceClassRepositoryProvider);
    await repo.updateSchedule(s.id, {'is_active': !s.isActive});
    ref.invalidate(classSchedulesProvider);
    ref.invalidate(classSessionsPageProvider);
  }

  Future<void> _deleteSchedule(
    BuildContext context,
    WidgetRef ref,
    DanceClassScheduleModel s,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(
          'Eliminar horario',
          style: TextStyle(color: context.textOnBg),
        ),
        content: Text(
          '¿Eliminar ${s.dayName} ${s.startTime}-${s.endTime}?',
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final repo = ref.read(danceClassRepositoryProvider);
    await repo.deleteSchedule(s.id);
    ref.invalidate(classSchedulesProvider);
    ref.invalidate(classSessionsPageProvider);
  }
}

class _ScheduleTile extends ConsumerWidget {
  const _ScheduleTile({required this.schedule, required this.onEditCustom});

  final DanceClassScheduleModel schedule;
  final ValueChanged<String> onEditCustom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = schedule;
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageSchedules ?? false;

    return Card(
      color: context.cardBg,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: const Icon(
            Icons.schedule_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                s.dayName,
                style: TextStyle(
                  color: context.textOnBg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!s.isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Inactivo',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.startTime} - ${s.endTime}',
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
            if (s.startDate != null || s.endDate != null)
              Text(
                '${s.startDate != null ? '${s.startDate!.day.toString().padLeft(2, '0')}/${s.startDate!.month.toString().padLeft(2, '0')}/${s.startDate!.year}' : 'desde'} - ${s.endDate != null ? '${s.endDate!.day.toString().padLeft(2, '0')}/${s.endDate!.month.toString().padLeft(2, '0')}/${s.endDate!.year}' : 'sin fin'}',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            if (s.locationOverride != null)
              Text(
                'Ubicación: ${s.locationOverride!['location_name'] ?? 'asignada'}',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
          ],
        ),
        trailing: canManage
            ? PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: context.textMuted, size: 20),
                color: context.cardBg,
                onSelected: onEditCustom,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(
                      'Editar',
                      style: TextStyle(color: context.textOnBg),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      s.isActive ? 'Desactivar' : 'Activar',
                      style: TextStyle(color: context.textOnBg),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Eliminar',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _SessionsTab extends ConsumerStatefulWidget {
  const _SessionsTab();

  @override
  ConsumerState<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends ConsumerState<_SessionsTab> {
  static const int _upcomingPageSize = 20;
  static const int _pastPageSize = 10;
  int _upcomingLimit = _upcomingPageSize;
  int _pastLimit = _pastPageSize;
  bool _showPast = false;

  @override
  Widget build(BuildContext context) {
    final classId = ref.watch(selectedClassIdProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canCancelSession ?? false;

    if (classId == null) {
      return AppEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'Selecciona una clase',
        message: 'Abre una clase para ver sus sesiones.',
      );
    }

    final upcomingAsync = ref.watch(
      classSessionsPageProvider((
        classId: classId,
        limit: _upcomingLimit,
        upcomingOnly: true,
        pastOnly: false,
      )),
    );

    return upcomingAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => AppErrorState(message: friendlyError(e)),
      data: (page) {
        final upcoming = page.sessions;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Próximas sesiones',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canManage)
                  IconButton(
                    tooltip: 'Generar sesiones',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.autorenew_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    onPressed: () => _generateSessions(context),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              _NoUpcomingSessions(
                canManage: canManage,
                onGenerate: () => _generateSessions(context),
              )
            else ...[
              for (final session in upcoming)
                _SessionTile(session: session, canManage: canManage),
              if (page.hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.expand_more_rounded, size: 18),
                    label: const Text('Ver más sesiones próximas'),
                    onPressed: () =>
                        setState(() => _upcomingLimit += _upcomingPageSize),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: Icon(
                  _showPast ? Icons.expand_less : Icons.history_rounded,
                  size: 18,
                ),
                label: Text(
                  _showPast
                      ? 'Ocultar sesiones anteriores'
                      : 'Ver sesiones anteriores',
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                onPressed: () => setState(() => _showPast = !_showPast),
              ),
            ),
            if (_showPast)
              _PastSessionsList(
                classId: classId,
                canManage: canManage,
                limit: _pastLimit,
                onLoadMore: () => setState(() => _pastLimit += _pastPageSize),
              ),
          ],
        );
      },
    );
  }

  Future<void> _generateSessions(BuildContext context) async {
    final repo = ref.read(danceClassRepositoryProvider);
    final danceClass = ref.read(selectedClassProvider).value;
    if (danceClass == null) return;
    final periodStart = danceClass.startTime ?? DateTime.now();
    final periodEnd =
        danceClass.endTime ?? periodStart.add(const Duration(days: 90));
    await repo.generateSessions(
      classId: danceClass.id,
      startDate: periodStart,
      endDate: periodEnd,
    );
    ref.invalidate(classSessionsPageProvider);
    if (!context.mounted) return;
    AppFeedback.success(context, 'Sesiones generadas.');
  }
}

/// Sesiones pasadas, paginadas y de la más reciente a la más vieja.
class _PastSessionsList extends ConsumerWidget {
  const _PastSessionsList({
    required this.classId,
    required this.canManage,
    required this.limit,
    required this.onLoadMore,
  });

  final String classId;
  final bool canManage;
  final int limit;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pastAsync = ref.watch(
      classSessionsPageProvider((
        classId: classId,
        limit: limit,
        upcomingOnly: false,
        pastOnly: true,
      )),
    );

    return pastAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      error: (e, _) => Text(
        friendlyError(e),
        style: TextStyle(color: context.textMuted, fontSize: 12),
      ),
      data: (page) {
        if (page.sessions.isEmpty) {
          return Text(
            'Todavía no hay sesiones anteriores.',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          );
        }
        return Column(
          children: [
            for (final session in page.sessions)
              _SessionTile(session: session, canManage: canManage),
            if (page.hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  label: const Text('Ver más sesiones anteriores'),
                  onPressed: onLoadMore,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NoUpcomingSessions extends StatelessWidget {
  const _NoUpcomingSessions({
    required this.canManage,
    required this.onGenerate,
  });

  final bool canManage;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: context.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.event_busy_outlined,
                size: 20,
                color: context.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No hay sesiones próximas',
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generá las sesiones desde los horarios para que los '
                      'alumnos puedan comprar su acceso.',
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canManage) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.autorenew_rounded, size: 18),
              label: const Text('Generar sesiones'),
              onPressed: onGenerate,
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session, required this.canManage});

  final DanceClassSessionModel session;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr =
        '${session.sessionDate.day.toString().padLeft(2, '0')}/${session.sessionDate.month.toString().padLeft(2, '0')}/${session.sessionDate.year}';
    final startStr =
        '${session.startAt.hour.toString().padLeft(2, '0')}:${session.startAt.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${session.endAt.hour.toString().padLeft(2, '0')}:${session.endAt.minute.toString().padLeft(2, '0')}';

    Color statusColor;
    switch (session.status) {
      case 'scheduled':
        statusColor = AppColors.primary;
        break;
      case 'completed':
        statusColor = AppColors.success;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = context.textMuted;
    }

    return Card(
      color: context.cardBg,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(
            session.isCompleted
                ? Icons.check
                : session.isCancelled
                ? Icons.close
                : Icons.calendar_today,
            color: statusColor,
            size: 18,
          ),
        ),
        title: Text(
          dateStr,
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '$startStr - $endStr',
          style: TextStyle(color: context.textMuted, fontSize: 13),
        ),
        trailing: canManage && session.isScheduled
            ? PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: context.textMuted, size: 20),
                color: context.cardBg,
                onSelected: (value) async {
                  final repo = ref.read(danceClassRepositoryProvider);
                  if (value == 'complete') {
                    await repo.completeSession(session.id);
                    ref.invalidate(classSessionsPageProvider);
                  } else if (value == 'cancel') {
                    final reasonCtrl = TextEditingController();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: context.cardBg,
                        title: Text(
                          'Cancelar sesión',
                          style: TextStyle(color: context.textOnBg),
                        ),
                        content: TextField(
                          controller: reasonCtrl,
                          style: TextStyle(color: context.textOnBg),
                          decoration: InputDecoration(
                            hintText: 'Razón (opcional)',
                            hintStyle: TextStyle(color: context.textMuted),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await repo.cancelSession(
                        sessionId: session.id,
                        reason: reasonCtrl.text.trim().isEmpty
                            ? null
                            : reasonCtrl.text.trim(),
                      );
                      ref.invalidate(classSessionsPageProvider);
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'complete',
                    child: Text(
                      'Marcar completada',
                      style: TextStyle(color: context.textOnBg),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  session.statusDisplayName,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Cabecera de la clase: portada (o bloque con ícono), título y chips de
/// ritmo/estado. Reemplaza al círculo con la inicial.
class _ClassHeader extends StatelessWidget {
  const _ClassHeader({required this.danceClass});

  final dynamic danceClass;

  @override
  Widget build(BuildContext context) {
    final coverUrl = danceClass.coverImageUrl as String?;
    final published = danceClass.isPublished as bool;
    final genre = danceClass.danceCategoryName as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          child: AspectRatio(
            aspectRatio: 16 / 7,
            child: (coverUrl != null && coverUrl.isNotEmpty)
                ? Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _coverFallback(context),
                  )
                : _coverFallback(context),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          danceClass.title,
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (genre != null && genre.isNotEmpty)
              _Tag(
                label: genre,
                icon: Icons.music_note_rounded,
                color: AppColors.primary,
              ),
            _Tag(
              label: published ? 'Publicada' : 'Borrador',
              icon: published ? Icons.public : Icons.edit_note_rounded,
              color: published ? AppColors.success : AppColors.warning,
            ),
          ],
        ),
      ],
    );
  }

  Widget _coverFallback(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.10),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 36,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Publicación de la clase: pago por QR desde la propia organización o, si ya
/// está pagada / publicada, la acción directa.
class _PublicationCard extends ConsumerStatefulWidget {
  const _PublicationCard({required this.danceClass});

  final dynamic danceClass;

  @override
  ConsumerState<_PublicationCard> createState() => _PublicationCardState();
}

class _PublicationCardState extends ConsumerState<_PublicationCard> {
  bool _busy = false;

  bool get _isPublished => widget.danceClass.isPublished as bool;

  Future<void> _confirmationThen(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final ok = await showAppConfirm(
      context,
      title: 'Publicar clase',
      message:
          'El pago de publicación ya está acreditado. '
          '"${widget.danceClass.title}" quedará visible para el público.',
      confirmLabel: 'Publicar',
    );
    if (!ok || !mounted) return;

    await _confirmationThen(() async {
      try {
        await ref.read(danceClassRepositoryProvider).updateClass(
          widget.danceClass.id,
          {'status': 'published'},
        );
        _refresh();
        if (mounted) AppFeedback.success(context, 'Clase publicada.');
      } catch (e) {
        if (mounted) AppFeedback.error(context, friendlyError(e));
      }
    });
  }

  Future<void> _unpublish() async {
    final ok = await showAppConfirm(
      context,
      title: 'Despublicar clase',
      message:
          '¿Despublicar "${widget.danceClass.title}"? Dejará de ser visible.',
      confirmLabel: 'Despublicar',
      isDangerous: true,
    );
    if (!ok || !mounted) return;

    await _confirmationThen(() async {
      try {
        await ref.read(danceClassRepositoryProvider).updateClass(
          widget.danceClass.id,
          {'status': 'draft'},
        );
        _refresh();
        if (mounted) AppFeedback.success(context, 'Clase despublicada.');
      } catch (e) {
        if (mounted) AppFeedback.error(context, friendlyError(e));
      }
    });
  }

  Future<void> _payAndPublish(double price) async {
    final ok = await showAppConfirm(
      context,
      title: 'Pagar publicación',
      message:
          'Se generará un QR de pago por ${_money(price)}. '
          'La clase se publica automáticamente al confirmarse el pago.',
      confirmLabel: 'Generar QR',
    );
    if (!ok || !mounted) return;

    await _confirmationThen(() async {
      try {
        final checkout = await const PagosyaService().createPublicationCheckout(
          kind: 'class_publication',
          referenceId: widget.danceClass.id,
          amount: price,
        );
        if (!mounted) return;
        final paid = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PagosyaCheckoutScreen(checkout: checkout),
          ),
        );
        _refresh();
        if (paid == true && mounted) {
          AppFeedback.success(
            context,
            'Pago confirmado. La clase se publicará automáticamente.',
          );
        }
      } catch (e) {
        if (mounted) AppFeedback.error(context, friendlyError(e));
      }
    });
  }

  void _refresh() {
    ref.invalidate(classPublicationStatusProvider(widget.danceClass.id));
    ref.invalidate(selectedClassProvider);
    ref.invalidate(orgClassesProvider);
  }

  String _money(double value) => 'Bs. ${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(
      classPublicationStatusProvider(widget.danceClass.id),
    );

    return AppSectionCard(
      title: 'Publicación',
      icon: Icons.publish_outlined,
      trailing: _isPublished
          ? const _Chip(label: 'Publicada', color: AppColors.success)
          : const _Chip(label: 'Borrador', color: AppColors.warning),
      children: [
        statusAsync.when(
          loading: () => Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Consultando estado de publicación…',
                style: TextStyle(color: context.textMuted, fontSize: 12.5),
              ),
            ],
          ),
          error: (e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                friendlyError(e),
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reintentar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => ref.invalidate(
                    classPublicationStatusProvider(widget.danceClass.id),
                  ),
                ),
              ),
            ],
          ),
          data: (status) => _body(context, status),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, ClassPublicationStatus status) {
    if (_isPublished) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'La clase es visible para el público. Despublicarla no devuelve el '
            'pago de publicación.',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.unpublished_outlined, size: 18),
            label: const Text('Despublicar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
            ),
            onPressed: _busy ? null : _unpublish,
          ),
        ],
      );
    }

    if (!status.monthlyMembership) {
      return _message(
        context,
        icon: Icons.lock_clock_outlined,
        color: AppColors.warning,
        text:
            'Para publicar la clase necesitás la suscripción mensual activa de '
            'la academia.',
      );
    }

    if (status.alreadyPaid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'El pago de publicación está acreditado. Ya podés publicarla.',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _publishButton(context, price: null),
        ],
      );
    }

    if (!status.hasPrice) {
      return _message(
        context,
        icon: Icons.info_outline_rounded,
        color: context.textMuted,
        text:
            'La plataforma todavía no configuró el precio de publicación. '
            'Pedile el QR al administrador.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Precio de publicación: ${_money(status.price!)} (pago único).',
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pagás con QR y la clase se publica automáticamente.',
          style: TextStyle(
            color: context.textMuted,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        _publishButton(context, price: status.price),
      ],
    );
  }

  Widget _publishButton(BuildContext context, {double? price}) {
    return FilledButton.icon(
      icon: Icon(price == null ? Icons.publish : Icons.qr_code_2, size: 18),
      label: Text(
        price == null ? 'Publicar' : 'Pagar ${_money(price)} y publicar',
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
      ),
      onPressed: _busy
          ? null
          : () => price == null ? _publish() : _payAndPublish(price),
    );
  }

  Widget _message(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: context.textOnBg, fontSize: 15)),
        ],
      ),
    );
  }
}
