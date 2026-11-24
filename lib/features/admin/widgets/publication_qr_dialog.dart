// lib/features/admin/widgets/publication_qr_dialog.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/pagosya_checkout_model.dart';

Future<void> showPublicationQrDialog(
  BuildContext context,
  PagosyaCheckout checkout,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PublicationQrDialog(checkout: checkout),
  );
}

class _PublicationQrDialog extends StatelessWidget {
  const _PublicationQrDialog({required this.checkout});

  final PagosyaCheckout checkout;

  Uint8List? get _qrBytes {
    final raw = checkout.qrDataUrl;
    if (raw == null || !raw.startsWith('data:image')) return null;
    final comma = raw.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(raw.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrBytes = _qrBytes;
    final url = checkout.checkoutUrl;

    return AlertDialog(
      title: const Text('QR de publicación'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${checkout.currency} ${checkout.totalAmount.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (qrBytes != null)
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: Image.memory(qrBytes, width: 220, height: 220),
                ),
              )
            else if (checkout.hasQr)
              Center(
                child: Image.network(
                  checkout.qrDataUrl!,
                  width: 220,
                  height: 220,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 12),
            if (url != null && url.isNotEmpty) ...[
              SelectableText(
                url,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enlace copiado.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar enlace'),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Comparte este QR o enlace con la organización. El pago se '
              'registra automáticamente y recibirás una notificación.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
