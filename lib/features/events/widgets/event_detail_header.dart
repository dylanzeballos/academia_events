import 'package:flutter/material.dart';

import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/event_model.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';

class EventDetailHeader extends StatelessWidget {
  const EventDetailHeader({
    super.key,
    required this.event,
    required this.accentColor,
  });

  final EventModel event;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: event.coverImageUrl == null
              ? null
              : () => FullscreenImageViewer.show(
                    context,
                    event.coverImageUrl!,
                    tag: 'detail-cover-${event.id}',
                  ),
          child: Hero(
            tag: 'detail-cover-${event.id}',
            child: event.coverImageUrl != null
                ? Image.network(
                    event.coverImageUrl!,
                    height: 220,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            height: 220,
                            color: context.cardBg,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                    errorBuilder: (_, _, _) => _BannerPlaceholder(color: accentColor),
                  )
                : _BannerPlaceholder(color: accentColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.categoryName != null) ...[
                Chip(
                  label: Text(event.categoryName!),
                  backgroundColor: accentColor.withValues(alpha: 0.12),
                  labelStyle: TextStyle(color: accentColor, fontSize: 12),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
              ],
              Text(
                event.title,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              if (event.organizationName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 15, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      event.organizationName,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      color: color.withValues(alpha: 0.25),
      child: Center(
        child: Icon(Icons.image_outlined, color: color, size: 48),
      ),
    );
  }
}