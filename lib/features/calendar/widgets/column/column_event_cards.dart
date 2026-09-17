import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';
import '../event_preview_sheet.dart';

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class ColumnEventBlock extends StatelessWidget {
  const ColumnEventBlock({
    super.key,
    required this.event,
    this.onTap,
    this.compact = false,
  });

  final EventModel event;
  final VoidCallback? onTap;
  final bool compact;

  Color get _color => AppColors.colorForOrganization(event.organizationId);

  @override
  Widget build(BuildContext context) {
    final themeColor = _color;
    final price = event.startingPrice;
    final priceLabel = price != null ? '\$${price.toInt()} USD' : 'Free';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A24).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: themeColor.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.all(compact ? 6 : 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fila superior: Chip de Hora + Nombre de Academia ──
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 5 : 7,
                    vertical: compact ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _hhmm(event.startTime),
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: compact ? 9 : 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (event.organizationName.isNotEmpty)
                  Expanded(
                    child: Text(
                      event.organizationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: themeColor.withValues(alpha: 0.95),
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),

            // ── Categoría en mayúsculas (ej: SOCIAL MIX, FIESTA LATINA) ──
            if ((event.categoryName ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  (event.categoryName ?? '').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: themeColor.withValues(alpha: 0.85),
                    fontSize: compact ? 8 : 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

            // ── Título del evento ──
            Text(
              event.title,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),

            // ── Subtítulo / Descripción resumida ──
            if (!compact && (event.description?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 3),
              Expanded(
                child: Text(
                  event.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD37B58),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              ),
            ] else
              const Spacer(),

            // ── Barra inferior: Precio + Flecha de acción ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  priceLabel,
                  style: TextStyle(
                    color: themeColor,
                    fontSize: compact ? 10 : 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: compact ? 12 : 14,
                  color: themeColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ClusterSummaryBlock extends StatelessWidget {
  const ClusterSummaryBlock({
    super.key,
    required this.events,
    required this.onTap,
  });

  final List<EventModel> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstColor = AppColors.colorForOrganization(
      events.first.organizationId,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A24).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: firstColor.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: firstColor.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.event_note, size: 14, color: firstColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${events.length} eventos',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: firstColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.expand_more, size: 16, color: firstColor),
          ],
        ),
      ),
    );
  }
}

void showClusterSheet(BuildContext context, List<EventModel> events) {
  final sorted = [...events]..sort((a, b) => a.startTime.compareTo(b.startTime));

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusLarge),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: context.textOnBg.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        '${sorted.length} eventos en este horario',
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final event = sorted[i];
                      final color = AppColors.colorForOrganization(event.organizationId);
                      final price = event.startingPrice;
                      final priceLabel = price != null ? '\$${price.toInt()} USD' : 'Free';

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          EventPreviewSheet.show(context, event);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1A24).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withValues(alpha: 0.45)),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _hhmm(event.startTime),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.textOnBg,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (event.organizationName.isNotEmpty)
                                      Text(
                                        event.organizationName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                priceLabel,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.chevron_right, size: 16, color: color),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}