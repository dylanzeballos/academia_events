import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/event_model.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/layout_mode_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/event_detail_header.dart';
import '../widgets/event_location_section.dart';
import '../widgets/event_qr_section.dart';
import '../widgets/event_schedule_card.dart';
import '../widgets/event_ticket_action_bar.dart';

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
        data: (event) => _EventDetailContent(event: event),
      ),
      bottomNavigationBar: !isAcademyMode
          ? eventAsync.maybeWhen(
              data: (event) => EventTicketActionBar(eventId: event.id),
              orElse: () => null,
            )
          : null,
    );
  }
}

class _EventDetailContent extends StatelessWidget {
  const _EventDetailContent({required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.calendarEventColors;
    final accent = colors[event.colorIndex % colors.length];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EventDetailHeader(event: event, accentColor: accent),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EventScheduleCard(event: event, accentColor: accent),
                if (event.description != null && event.description!.isNotEmpty) ...[
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
                EventLocationSection(event: event, accentColor: accent),
                const SizedBox(height: 20),
                EventQrSection(event: event),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}