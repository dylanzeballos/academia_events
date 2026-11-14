import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Muestra una sola vez el secreto del webhook recién creado o rotado.
Future<void> showWebhookSecretDialog(BuildContext context, String secret) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Secreto del webhook'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Se muestra una sola vez. Guardalo como secreto de Edge Functions:',
          ),
          const SizedBox(height: 8),
          SelectableText(secret, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          const Text(
            'supabase secrets set PAGOSYA_WEBHOOK_SECRET=...',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: secret));
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: const Text('Copiar y cerrar'),
        ),
      ],
    ),
  );
}
