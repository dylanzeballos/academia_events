import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/event_model.dart';
import '../../../providers/events_provider.dart';

class EventDetailView extends ConsumerWidget {
  const EventDetailView({super.key, required this.event});

  final EventModel event;

  Future<void> _deleteEvent(BuildContext context, WidgetRef ref) async {
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
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Evento eliminado')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(event.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteEvent(context, ref),
          ),
        ],
      ),
      body: Padding(
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
    );
  }
}
