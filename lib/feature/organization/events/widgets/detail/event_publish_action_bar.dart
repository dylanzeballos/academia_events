import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/data/models/event_model.dart';
import 'package:academia_events/providers/events_provider.dart';
import 'package:academia_events/shared/widgets/app_feedback.dart';

class EventPublishActionBar extends ConsumerStatefulWidget {
  const EventPublishActionBar({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<EventPublishActionBar> createState() =>
      _EventPublishActionBarState();
}

class _EventPublishActionBarState extends ConsumerState<EventPublishActionBar> {
  bool _isProcessing = false;

  Future<void> _handlePublish() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(
          'Publicar evento',
          style: TextStyle(color: context.textOnBg),
        ),
        content: Text(
          'Al publicar "${widget.event.title}", el evento será visible para todos los usuarios y podrán adquirir entradas.',
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar y Publicar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      await ref.read(eventsRepositoryProvider).updateEvent(widget.event.id, {
        'status': 'published',
        'published_at': DateTime.now().toIso8601String(),
      });

      ref.invalidate(eventDetailProvider(widget.event.id));
      ref.invalidate(orgEventsProvider);
      ref.invalidate(allEventsProvider);
      ref.invalidate(weekEventsProvider);

      if (mounted) {
        AppFeedback.success(context, 'Evento publicado correctamente.');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.error(context, friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.scaffoldBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handlePublish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.rocket_launch_outlined),
                label: Text(
                  _isProcessing ? 'Publicando...' : 'Publicar Evento',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
