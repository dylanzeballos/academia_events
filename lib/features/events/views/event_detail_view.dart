import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/event_model.dart';
import '../../../providers/events_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';

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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Evento eliminado')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        title: eventAsync.when(
          data: (event) => Text(event.title),
          loading: () => const Text('Cargando...'),
          error: (_, _) => const Text('Evento'),
        ),
        actions: [
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
        data: (event) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.categoryName != null)
                Chip(
                  label: Text(event.categoryName!),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                ),
              const SizedBox(height: 16),
              const Text(
                'Descripción:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                (event.description != null && event.description!.isNotEmpty)
                    ? event.description!
                    : 'Sin descripción.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Inicio: ${event.startTime.toString().split('.')[0]}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event_busy, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Fin: ${event.endTime.toString().split('.')[0]}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}