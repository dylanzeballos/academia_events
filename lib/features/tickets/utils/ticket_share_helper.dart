import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class TicketShareHelper {
  /// Captura un widget y lo comparte vía WhatsApp u otras apps
  static Future<void> shareTicketImage({
    required BuildContext context,
    required ScreenshotController screenshotController,
    required String ticketNumber,
    required String eventTitle,
  }) async {
    try {
      // 1. Tomar captura del ticket
      final Uint8List? imageBytes = await screenshotController.capture(
        delay: const Duration(milliseconds: 100),
      );

      if (imageBytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo generar la imagen del ticket')),
          );
        }
        return;
      }

      // 2. Guardar temporalmente en el dispositivo
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/Ticket_$ticketNumber.png').create();
      await file.writeAsBytes(imageBytes);

      // 3. Abrir la hoja para compartir (WhatsApp, Guardar en galería, etc.)
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '¡Aquí está tu entrada para $eventTitle!\nTicket: $ticketNumber',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir ticket: $e')),
        );
      }
    }
  }
}