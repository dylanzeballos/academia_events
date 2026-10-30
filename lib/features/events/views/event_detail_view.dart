// lib/features/events/views/event_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/event_model.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/layout_mode_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../widgets/detail/event_detail_header.dart';
import '../widgets/detail/event_location_section.dart';
import '../widgets/detail/event_publish_action_bar.dart';
import '../widgets/detail/event_schedule_card.dart';
import '../widgets/detail/event_ticket_action_bar.dart';
import '../widgets/detail/event_tickets_section.dart';
import 'event_attendance_view.dart';
import 'event_access_points_view.dart';

class EventDetailView extends ConsumerWidget {
  const EventDetailView({super.key, required this.eventId});

  final String eventId;

  Future<void> _deleteEvent(
    BuildContext context,
    WidgetRef ref,
    EventModel event,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(
          'Eliminar evento',
          style: TextStyle(color: context.textOnBg),
        ),
        content: Text(
          '¿Estás seguro de eliminar "${event.title}"? Esta acción borrará todas sus entradas, ubicaciones y datos asociados.',
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(eventsRepositoryProvider).deleteEvent(event.id);
      ref.invalidate(orgEventsProvider);
      ref.invalidate(allEventsProvider);
      ref.invalidate(weekEventsProvider);

      if (context.mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Evento eliminado correctamente'),
            backgroundColor: context.cardBg,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.error(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final isAcademyMode =
        ref.watch(effectiveLayoutModeProvider) == AppLayoutMode.academy;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: eventAsync.when(
          data: (event) => Text(
            event.title,
            style: TextStyle(
              color: context.textOnBg,
              fontWeight: FontWeight.bold,
            ),
          ),
          loading: () =>
              Text('Cargando...', style: TextStyle(color: context.textMuted)),
          error: (_, _) =>
              Text('Evento', style: TextStyle(color: context.textOnBg)),
        ),
        actions: [
          if (isAcademyMode)
            eventAsync.maybeWhen(
              data: (event) => IconButton(
                tooltip: 'Puntos de acceso',
                icon: Icon(
                  Icons.meeting_room_outlined,
                  color: context.textOnBg,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventAccessPointsView(
                      eventId: event.id,
                      organizationId: event.organizationId,
                      eventTitle: event.title,
                    ),
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          if (isAcademyMode)
            eventAsync.maybeWhen(
              data: (event) => IconButton(
                tooltip: 'Ver asistencia',
                icon: Icon(Icons.assessment_outlined, color: context.textOnBg),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventAttendanceView(
                      eventId: event.id,
                      eventTitle: event.title,
                    ),
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          if (isAcademyMode)
            eventAsync.maybeWhen(
              data: (event) => IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () => _deleteEvent(context, ref, event),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: eventAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorState(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
        ),
        data: (event) =>
            _EventDetailContent(event: event, isAcademyMode: isAcademyMode),
      ),
      bottomNavigationBar: eventAsync.maybeWhen(
        data: (event) {
          if (isAcademyMode) {
            if (event.status == 'draft') {
              return EventPublishActionBar(event: event);
            }
            return null;
          }

          if (event.status == 'published') {
            return EventTicketActionBar(event: event);
          }

          return null;
        },
        orElse: () => null,
      ),
    );
  }
}

class _EventDetailContent extends StatelessWidget {
  const _EventDetailContent({required this.event, required this.isAcademyMode});

  final EventModel event;
  final bool isAcademyMode;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.colorForOrganization(event.organizationId);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAcademyMode) _OrganizerStatusBanner(status: event.status),

          EventDetailHeader(event: event, accentColor: accent),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EventScheduleCard(event: event, accentColor: accent),

                if (event.description != null &&
                    event.description!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Descripción',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description!,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                EventTicketsSection(event: event, accentColor: accent),

                const SizedBox(height: 20),
                EventLocationSection(event: event, accentColor: accent),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizerStatusBanner extends StatelessWidget {
  const _OrganizerStatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isDraft = status == 'draft';
    final bgColor = isDraft ? AppColors.warning : AppColors.success;

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            isDraft ? Icons.edit_note : Icons.check_circle_outline,
            color: AppColors.onPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isDraft
                  ? 'Borrador: Este evento aún no es visible para el público.'
                  : 'Publicado: Visible y habilitado para compra de entradas.',
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
