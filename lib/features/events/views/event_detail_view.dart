import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/event_model.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/layout_mode_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/detail/event_detail_header.dart';
import '../widgets/detail/event_location_section.dart';
import '../widgets/detail/event_publish_action_bar.dart';
import '../widgets/detail/event_schedule_card.dart';
import '../widgets/detail/event_ticket_action_bar.dart';
import '../widgets/detail/event_tickets_section.dart';
import 'event_attendance_view.dart';

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
        title: const Text('Eliminar evento'),
        content: Text('¿Estás seguro de eliminar "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(eventsRepositoryProvider).deleteEvent(event.id);
      ref.invalidate(orgEventsProvider);
      ref.invalidate(allEventsProvider);
      ref.invalidate(weekEventsProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento eliminado')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final isAcademyMode =
        ref.watch(effectiveLayoutModeProvider) == AppLayoutMode.academy;

    return Scaffold(
      appBar: AppBar(
        title: eventAsync.when(
          data: (event) => Text(event.title),
          loading: () => const Text('Cargando...'),
          error: (_, _) => const Text('Evento'),
        ),
        actions: [
          if (isAcademyMode)
            eventAsync.maybeWhen(
              data: (event) => IconButton(
                tooltip: 'Ver asistencia',
                icon: const Icon(Icons.assessment_outlined),
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
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteEvent(context, ref, event),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: eventAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (event) => _EventDetailContent(
          event: event,
          isAcademyMode: isAcademyMode,
        ),
      ),
      bottomNavigationBar: eventAsync.maybeWhen(
        data: (event) {
          // ── MODO ACADEMIA: Solo muestra acción de publicar si está en borrador
          if (isAcademyMode) {
            if (event.status == 'draft') {
              return EventPublishActionBar(event: event);
            }
            return null; // Ya publicado, no requiere barra flotante
          }

          // ── MODO USUARIO NORMAL: Solo muestra comprar si está publicado
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
  const _EventDetailContent({
    required this.event,
    required this.isAcademyMode,
  });

  final EventModel event;
  final bool isAcademyMode;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.colorForOrganization(event.organizationId);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── BANNER DE ESTADO EXCLUSIVO PARA EL ORGANIZADOR ─────────
          if (isAcademyMode)
            _OrganizerStatusBanner(status: event.status),

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
                      color: context.textOnBg.withValues(alpha: 0.8),
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

/// Banner visible solo para la academia para identificar si el evento ya está al aire
class _OrganizerStatusBanner extends StatelessWidget {
  const _OrganizerStatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isDraft = status == 'draft';

    return Container(
      width: double.infinity,
      color: isDraft ? Colors.amber.shade800 : Colors.green.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            isDraft ? Icons.edit_note : Icons.check_circle_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isDraft
                  ? 'Borrador: Este evento aún no es visible para el público.'
                  : 'Publicado: Visible y habilitado para compra de entradas.',
              style: const TextStyle(
                color: Colors.white,
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