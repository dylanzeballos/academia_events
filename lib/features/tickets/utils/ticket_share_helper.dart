// lib/features/tickets/utils/ticket_share_helper.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/theme_extensions.dart';

class TicketShareHelper {
  /// Captura un widget y lo comparte vía WhatsApp u otras apps
  static Future<void> shareTicketImage({
    required BuildContext context,
    required ScreenshotController screenshotController,
    required String ticketNumber,
    required String eventTitle,
  }) async {
    try {
      final Uint8List? imageBytes = await screenshotController.capture(
        delay: const Duration(milliseconds: 100),
      );

      if (imageBytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No se pudo generar la imagen del ticket'),
              backgroundColor: context.cardBg,
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/Ticket_$ticketNumber.png').create();
      await file.writeAsBytes(imageBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '¡Aquí está tu entrada para $eventTitle!\nTicket: $ticketNumber',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir ticket: $e'),
            backgroundColor: context.cardBg,
          ),
        );
      }
    }
  }
}