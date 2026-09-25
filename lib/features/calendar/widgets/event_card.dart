import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event_model.dart';
import '../../../../providers/organization_provider.dart';
import '../../../../shared/widgets/fullscreen_image_viewer.dart';

/// Bloque de evento para el timeline.
///
/// Estilo Google Calendar: el tramo NO se pinta a todo color (eso producía
/// un fondo "eléctrico"), sino con un tinte translúcido del color del evento,
/// una franja de acento a la izquierda, textos grandes en blanco y la info
/// organizada en columnas para que se lea mejor en pantallas pequeñas.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final EventModel event;
  final VoidCallback? onTap;

  Color get _color => AppColors.colorForOrganization(event.organizationId);

  @override
  Widget build(BuildContext context) {
    final durationMin =
        DateFormatter.durationMinutes(event.startTime, event.endTime);
    final isShort = durationMin < 45;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // Tinte translúcido sobre el fondo neutro: sin bloque de color sólido.
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          border: Border.all(
            color: _color.withValues(alpha: 0.65),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: isShort
            ? _ShortContent(event: event, color: _color)
            : _FullContent(event: event, color: _color),
      ),
    );
  }
}

class _FullContent extends ConsumerWidget {
  const _FullContent({required this.event, required this.color});

  final EventModel event;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoUrl = ref
        .watch(orgLogoUrlProvider(event.organizationLogoUrl))
        .whenOrNull(data: (url) => url);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Franja de acento vertical (identifica el color sin invadir).
          Container(width: 4, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      DateFormatter.timeRange(event.startTime, event.endTime),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
                if (event.organizationName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (logoUrl != null)
                        GestureDetector(
                          onTap: () => FullscreenImageViewer.show(
                            context,
                            logoUrl,
                            tag: 'calendar-card-org-logo-${event.id}',
                          ),
                          child: Hero(
                            tag: 'calendar-card-org-logo-${event.id}',
                            child: CircleAvatar(
                              radius: 9,
                              backgroundImage: NetworkImage(logoUrl),
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.apartment,
                            size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.organizationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
                if (event.location?.locationName != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.place, size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!.locationName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortContent extends ConsumerWidget {
  const _ShortContent({required this.event, required this.color});

  final EventModel event;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durationMin =
        DateFormatter.durationMinutes(event.startTime, event.endTime);
    final isVeryShort = durationMin < 20;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(width: 4, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormatter.timeRange(event.startTime, event.endTime),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isVeryShort ? 11 : 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!isVeryShort) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}