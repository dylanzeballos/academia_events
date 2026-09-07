import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event_model.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';

/// Vista previa del evento al tocar su bloque en el calendario
/// (estilo Google Calendar). Desde aquí se accede al detalle completo.
class EventPreviewSheet {
  const EventPreviewSheet._();

  static void show(BuildContext context, EventModel event) {
    final color = AppColors.colorForOrganization(event.organizationId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreviewContent(event: event, color: color),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.event, required this.color});

  final EventModel event;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final location = event.location;
    final duration = DateFormatter.durationMinutes(
      event.startTime,
      event.endTime,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLarge),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Franja de color + handle ──────────────────────────
            Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLarge),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    DateFormatter.timeRange(event.startTime, event.endTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  if (event.organizationName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${event.organizationName} · ${_durationLabel(duration)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Categoría ────────────────────────────────────
                  if (event.categoryName != null) ...[
                    Chip(
                      label: Text(event.categoryName!),
                      backgroundColor: color.withValues(alpha: 0.15),
                      labelStyle: TextStyle(color: color, fontSize: 12),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Foto del evento ──────────────────────────────
                  if (event.coverImageUrl != null)
                    GestureDetector(
                      onTap: () => FullscreenImageViewer.show(
                        context,
                        event.coverImageUrl!,
                        tag: 'cover-${event.id}',
                      ),
                      child: Hero(
                        tag: 'cover-${event.id}',
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusMedium),
                          child: SizedBox(
                            height: 150,
                            width: double.infinity,
                            child: Image.network(
                              event.coverImageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (event.coverImageUrl != null)
                    const SizedBox(height: 14),

                  // ── Descripción ──────────────────────────────────
                  if (event.description != null &&
                      event.description!.isNotEmpty) ...[
                    Text(
                      event.description!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textOnBg.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Ubicación ────────────────────────────────────
                  if (location?.locationName != null ||
                      location?.addressLine1 != null)
                    Row(
                      children: [
                        Icon(Icons.place_outlined, color: color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              ?location?.locationName,
                              ?location?.addressLine1,
                            ].join(' · '),
                            style: TextStyle(
                              color: context.textOnBg.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (location?.locationName != null ||
                      location?.addressLine1 != null)
                    const SizedBox(height: 6),

                  // ── Hora exacta ──────────────────────────────────
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          color: color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormatter.fullDate(event.startTime),
                          style: TextStyle(
                            color: context.textOnBg.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Ver detalle completo ─────────────────────────
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.eventDetail, extra: event.id);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text(
                      'Ver detalle completo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }
}
