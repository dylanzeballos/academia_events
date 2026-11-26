import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../shared/widgets/app_section_card.dart';

/// Configuración del webhook global de PagosYa.
class PagosyaWebhookCard extends StatelessWidget {
  const PagosyaWebhookCard({
    super.key,
    required this.url,
    required this.enabled,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    this.error,
  });

  final String url;
  final bool enabled;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Webhook global',
      icon: Icons.webhook_outlined,
      children: [
        if (error != null)
          Text(
            'No se pudo leer el webhook: $error',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          )
        else ...[
          Text(
            url.isEmpty ? 'Sin URL registrada.' : url,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          AppStatusChip(
            label: enabled ? 'Activo' : 'Pausado',
            color: enabled ? AppColors.success : AppColors.warning,
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: busy ? null : onEdit,
              icon: const Icon(Icons.link),
              label: const Text('Configurar URL'),
            ),
            if (url.isNotEmpty)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: busy ? null : onToggle,
                icon: Icon(enabled ? Icons.pause : Icons.play_arrow),
                label: Text(enabled ? 'Pausar' : 'Activar'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Últimos eventos recibidos por el webhook y reintento de fallidos.
class PagosyaEventsCard extends StatelessWidget {
  const PagosyaEventsCard({
    super.key,
    required this.events,
    required this.busy,
    required this.onRetry,
  });

  final List<Map<String, dynamic>> events;
  final bool busy;
  final ValueChanged<String> onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Últimos eventos del webhook',
      icon: Icons.inbox_outlined,
      children: [
        if (events.isEmpty)
          Text(
            'Sin eventos recibidos.',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          )
        else
          for (final event in events) _eventRow(context, event),
      ],
    );
  }

  Widget _eventRow(BuildContext context, Map<String, dynamic> event) {
    final failed = event['status'] == 'failed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: failed ? AppColors.error : AppColors.success,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['event_type']?.toString() ?? 'evento',
                  style: TextStyle(color: context.textOnBg, fontSize: 12.5),
                ),
                if (event['error'] != null)
                  Text(
                    event['error'].toString(),
                    style: TextStyle(color: AppColors.error, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (failed)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: busy
                  ? null
                  : () => onRetry(event['event_id'].toString()),
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }
}
