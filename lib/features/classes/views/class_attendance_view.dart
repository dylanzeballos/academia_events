import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_attendance_model.dart';
import '../../../providers/attendance_provider.dart';
import '../../../shared/widgets/attendance_bar_chart.dart';
import '../../../shared/widgets/attendance_donut_chart.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../utils/class_attendance_exporter.dart';

/// Vista dedicada de asistencia de una clase. Muestra un resumen general y,
/// con selector, el detalle por sesión.
class ClassAttendanceView extends ConsumerStatefulWidget {
  const ClassAttendanceView({
    super.key,
    required this.classId,
    required this.classTitle,
  });

  final String classId;
  final String classTitle;

  @override
  ConsumerState<ClassAttendanceView> createState() =>
      _ClassAttendanceViewState();
}

class _ClassAttendanceViewState extends ConsumerState<ClassAttendanceView> {
  bool _generalScope = true;
  String? _selectedSessionId;

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(classAttendanceProvider(widget.classId));

    return Scaffold(
      appBar: AppBar(title: const Text('Asistencia')),
      body: attendanceAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
        data: (data) => _ClassAttendanceContent(
          classId: widget.classId,
          classTitle: widget.classTitle,
          data: data,
          generalScope: _generalScope,
          selectedSessionId: _selectedSessionId,
          onScopeChanged: (general) {
            setState(() => _generalScope = general);
            if (general) _selectedSessionId = null;
          },
          onSessionChanged: (sessionId) {
            setState(() => _selectedSessionId = sessionId);
          },
          onExport: () => _export(context, data),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, ClassAttendanceData data) async {
    try {
      await ClassAttendanceExporter.exportToExcel(
        data.students,
        widget.classTitle,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }
}

class _ClassAttendanceContent extends ConsumerWidget {
  const _ClassAttendanceContent({
    required this.classId,
    required this.classTitle,
    required this.data,
    required this.generalScope,
    required this.selectedSessionId,
    required this.onScopeChanged,
    required this.onSessionChanged,
    required this.onExport,
  });

  final String classId;
  final String classTitle;
  final ClassAttendanceData data;
  final bool generalScope;
  final String? selectedSessionId;
  final ValueChanged<bool> onScopeChanged;
  final ValueChanged<String> onSessionChanged;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = [...data.sessions]
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

    var selected = sessions.lastOrNull;
    if (selectedSessionId != null) {
      selected = sessions
          .where((s) => s.sessionId == selectedSessionId)
          .firstOrNull;
    }

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(classAttendanceProvider(classId)),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _scopeSelector(context),
            const SizedBox(height: 16),

            if (!generalScope && sessions.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: selected?.sessionId,
                decoration: const InputDecoration(
                  labelText: 'Sesión',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final s in sessions)
                    DropdownMenuItem<String>(
                      value: s.sessionId,
                      child: Text(
                        _sessionLabel(s),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onSessionChanged(v);
                },
              ),
              const SizedBox(height: 16),
            ],

            if (generalScope)
              _GeneralSection(data: data, sessions: sessions)
            else if (selected != null)
              _SessionSection(
                session: selected,
                capacity: data.capacity,
                enrolled: data.enrolled,
                sessionsList: sessions,
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No hay sesiones para esta clase.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),

            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Exportar a Excel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            _sectionTitle(
              context,
              'Inscritos (${data.students.length})',
            ),
            const SizedBox(height: 12),
            if (data.students.isEmpty)
              _EmptyBox(
                icon: Icons.group_outlined,
                text: 'Todavía no hay estudiantes inscritos.',
              )
            else
              for (final s in data.students) ...[
                _StudentTile(student: s),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _scopeSelector(BuildContext context) {
    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            Expanded(
              child: _ScopeButton(
                label: 'Resumen general',
                icon: Icons.assessment_outlined,
                selected: generalScope,
                onTap: () => onScopeChanged(true),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ScopeButton(
                label: 'Por sesión',
                icon: Icons.calendar_month_outlined,
                selected: !generalScope,
                onTap: () => onScopeChanged(false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sessionLabel(SessionStats s) {
    return '${DateFormatter.capitalize(DateFormatter.shortDay(s.sessionDate))} '
        '${DateFormatter.dayMonth(s.sessionDate)} · '
        '${DateFormat('HH:mm').format(s.startAt.toLocal())}';
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.textOnBg,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ScopeButton extends StatelessWidget {
  const _ScopeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneralSection extends StatelessWidget {
  const _GeneralSection({
    required this.data,
    required this.sessions,
  });

  final ClassAttendanceData data;
  final List<SessionStats> sessions;

  @override
  Widget build(BuildContext context) {
    final totalPresent = sessions.fold<int>(0, (a, s) => a + s.present);
    final totalLate = sessions.fold<int>(0, (a, s) => a + s.late);
    final totalAbsent = sessions.fold<int>(0, (a, s) => a + s.absent);
    final totalPending = sessions.fold<int>(0, (a, s) => a + s.pending);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.meeting_room_outlined,
                label: 'Capacidad',
                value: data.capacity?.toString() ?? '—',
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.group_outlined,
                label: 'Inscritos',
                value: '${data.enrolled}',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.task_alt_outlined,
                label: 'Asistencias',
                value: '${totalPresent + totalLate}',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.event_busy_outlined,
                label: 'Ausencias',
                value: '$totalAbsent',
                color: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _chartCard(
          context,
          'Distribución de asistencia',
          child: AttendanceDonutChart(
            centerTop: '${totalPresent + totalLate}',
            centerBottom: 'asistencias',
            slices: [
              if (totalPresent > 0)
                AttendanceSlice(
                  value: totalPresent.toDouble(),
                  color: AppColors.success,
                  label: 'Presente',
                ),
              if (totalLate > 0)
                AttendanceSlice(
                  value: totalLate.toDouble(),
                  color: AppColors.warning,
                  label: 'Tarde',
                ),
              if (totalAbsent > 0)
                AttendanceSlice(
                  value: totalAbsent.toDouble(),
                  color: AppColors.error,
                  label: 'Ausente',
                ),
              if (totalPending > 0)
                AttendanceSlice(
                  value: totalPending.toDouble(),
                  color: Colors.blueGrey,
                  label: 'Pendiente',
                ),
            ],
          ),
        ),
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _chartCard(
            context,
            'Asistencia por sesión (${sessions.length})',
            child: AttendanceBarChart(
              groups: [
                for (final s in sessions)
                  AttendanceBarGroup(
                    label: DateFormatter.dayMonth(s.sessionDate),
                    values: [
                      if (s.present > 0)
                        AttendanceBarValue(
                          value: s.present.toDouble(),
                          color: AppColors.success,
                        ),
                      if (s.late > 0)
                        AttendanceBarValue(
                          value: s.late.toDouble(),
                          color: AppColors.warning,
                        ),
                      if (s.absent > 0)
                        AttendanceBarValue(
                          value: s.absent.toDouble(),
                          color: AppColors.error,
                        ),
                    ],
                  ),
              ],
              legends: const [
                AttendanceBarLegend(label: 'Presente', color: AppColors.success),
                AttendanceBarLegend(label: 'Tarde', color: AppColors.warning),
                AttendanceBarLegend(label: 'Ausente', color: AppColors.error),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SessionSection extends StatelessWidget {
  const _SessionSection({
    required this.session,
    required this.capacity,
    required this.enrolled,
    required this.sessionsList,
  });

  final SessionStats session;
  final int? capacity;
  final int enrolled;
  final List<SessionStats> sessionsList;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.task_alt_outlined,
                label: 'Presentes',
                value: '${session.present}',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.schedule_outlined,
                label: 'Tarde',
                value: '${session.late}',
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.event_busy_outlined,
                label: 'Ausentes',
                value: '${session.absent}',
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.pending_actions_outlined,
                label: 'Pendientes',
                value: '${session.pending}',
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _chartCard(
          context,
          'Estado de la sesión',
          child: AttendanceDonutChart(
            centerTop: '${session.present + session.late}',
            centerBottom: 'asistieron',
            slices: [
              if (session.present > 0)
                AttendanceSlice(
                  value: session.present.toDouble(),
                  color: AppColors.success,
                  label: 'Presente',
                ),
              if (session.late > 0)
                AttendanceSlice(
                  value: session.late.toDouble(),
                  color: AppColors.warning,
                  label: 'Tarde',
                ),
              if (session.absent > 0)
                AttendanceSlice(
                  value: session.absent.toDouble(),
                  color: AppColors.error,
                  label: 'Ausente',
                ),
              if (session.pending > 0)
                AttendanceSlice(
                  value: session.pending.toDouble(),
                  color: Colors.blueGrey,
                  label: 'Pendiente',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _chartCard(BuildContext context, String title, {required Widget child}) {
  return Card(
    color: context.cardBg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      side: BorderSide(color: context.divider),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student});

  final ClassStudent student;

  @override
  Widget build(BuildContext context) {
    final statusLabel = student.lastAttendanceStatus != null
        ? switch (student.lastAttendanceStatus) {
            'present' => 'Presente',
            'late' => 'Tarde',
            'absent' => 'Ausente',
            _ => student.lastAttendanceStatus!,
          }
        : 'Sin registrar';
    final statusColor = student.lastAttendanceStatus == 'present'
        ? AppColors.success
        : student.lastAttendanceStatus == 'late'
            ? AppColors.warning
            : student.lastAttendanceStatus == 'absent'
                ? AppColors.error
                : Colors.blueGrey;

    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                student.fullName.isNotEmpty
                    ? student.fullName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName.isEmpty ? 'Estudiante' : student.fullName,
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${student.sessionsAttended}/${student.sessionsTotal} '
                    'sesiones asistidas',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (student.lastCheckInTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormatter.hourMin(student.lastCheckInTime!),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}