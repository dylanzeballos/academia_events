// lib/features/events/widgets/detail/event_qr_section.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';
import '../../../../shared/widgets/fullscreen_image_viewer.dart';

class EventQrSection extends StatelessWidget {
  const EventQrSection({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context) {
    if (event.qrImageUrl == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Código QR',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () => FullscreenImageViewer.show(
              context,
              event.qrImageUrl!,
              tag: 'detail-qr-${event.id}',
            ),
            child: Hero(
              tag: 'detail-qr-${event.id}',
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  border: Border.all(color: context.divider),
                ),
                child: Image.network(
                  event.qrImageUrl!,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          width: 200,
                          height: 200,
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        ),
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Toca para agrandar · Escanea para pagar o ingresar',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}