import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/event_attendance_model.dart';
import '../../../providers/attendance_provider.dart';
import '../../../shared/widgets/attendance_bar_chart.dart';
import '../../../shared/widgets/attendance_donut_chart.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../utils/event_attendance_exporter.dart';

/// Vista dedicada de asistencia de un evento (solo staff de la organización).
class EventAttendanceView extends ConsumerWidget {
  const EventAttendanceView({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(eventAttendanceProvider(eventId));

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
        data: (data) => _EventAttendanceContent(
          data: data,
          eventId: eventId,
          eventTitle: eventTitle,
        ),
      ),
    );
  }
}

class _EventAttendanceContent extends ConsumerWidget {
  const _EventAttendanceContent({
    required this.data,
    required this.eventId,
    required this.eventTitle,
  });

  final EventAttendanceData data;
  final String eventId;
  final String eventTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(eventAttendanceProvider(eventId)),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, 'Resumen'),
            const SizedBox(height: 12),
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
                    icon: Icons.confirmation_number_outlined,
                    label: 'Vendidas',
                    value: '${data.ticketsSold}',
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
                    icon: Icons.event_available_outlined,
                    label: 'Disponibles',
                    value: data.ticketsAvailable?.toString() ?? '—',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.how_to_reg_outlined,
                    label: 'Ingresados',
                    value: '${data.checkedIn}',
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _sectionTitle(context, 'Gráficos'),
            const SizedBox(height: 12),
            _chartCard(
              context,
              title: 'Vendidas vs disponibles',
              child: data.capacity != null
                  ? AttendanceDonutChart(
                      centerTop: '${data.ticketsSold}',
                      centerBottom: 'vendidas',
                      slices: [
                        AttendanceSlice(
                          value: data.ticketsSold.toDouble(),
                          color: AppColors.primary,
                          label: 'Vendidas',
                        ),
                        if ((data.ticketsAvailable ?? 0) > 0)
                          AttendanceSlice(
                            value: (data.ticketsAvailable ?? 0).toDouble(),
                            color: Colors.grey,
                            label: 'Disponibles',
                          ),
                      ],
                    )
                  : const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'El evento no tiene una capacidad definida.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    ),
            ),
            if (data.byTicketType.isNotEmpty) ...[
              const SizedBox(height: 12),
              _chartCard(
                context,
                title: 'Por tipo de entrada',
                child: AttendanceBarChart(
                  groups: [
                    for (final t in data.byTicketType)
                      AttendanceBarGroup(
                        label: t.name,
                        values: [
                          AttendanceBarValue(
                            value: t.sold.toDouble(),
                            color: AppColors.primary,
                          ),
                          AttendanceBarValue(
                            value: t.checkedIn.toDouble(),
                            color: AppColors.success,
                          ),
                        ],
                      ),
                  ],
                  legends: const [
                    AttendanceBarLegend(label: 'Vendidas', color: AppColors.primary),
                    AttendanceBarLegend(label: 'Ingresaron', color: AppColors.success),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: () => _export(context),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Exportar a Excel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            _sectionTitle(context, 'Asistentes (${data.attendees.length})'),
            const SizedBox(height: 12),
            if (data.attendees.isEmpty)
              const _EmptyBox(
                icon: Icons.person_search_outlined,
                text: 'Todavía no hay asistentes.',
              )
            else
              for (final attendee in data.attendees) ...[
                _AttendeeTile(attendee: attendee),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      await EventAttendanceExporter.exportToExcel(data.attendees, eventTitle);
    } on AttendanceExportException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
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

  Widget _chartCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
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

class _AttendeeTile extends StatelessWidget {
  const _AttendeeTile({required this.attendee});

  final EventAttendee attendee;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final label = _statusLabel();

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
                attendee.fullName.isNotEmpty
                    ? attendee.fullName[0].toUpperCase()
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
                    attendee.fullName.isEmpty ? 'Invitado' : attendee.fullName,
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${attendee.ticketNumber} · ${attendee.ticketType}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (attendee.accessPoint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Punto: ${attendee.accessPoint}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
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
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (attendee.checkInTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormatter.hourMin(attendee.checkInTime!),
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

  String _statusLabel() {
    if (attendee.checkedIn) return 'Ingresó';
    if (attendee.ticketStatus == 'used') return 'Usado';
    return 'Pendiente';
  }

  Color _statusColor() {
    if (attendee.checkedIn) return AppColors.success;
    if (attendee.ticketStatus == 'used') return Colors.blueGrey;
    return AppColors.warning;
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