// lib/features/tickets/views/pagosya_checkout_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/pagosya_checkout_model.dart';
import '../../../data/services/pagosya_service.dart';
import '../../../providers/ticket_provider.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_responsive_body.dart';
import 'ticket_qr_screen.dart';

/// Muestra el QR / enlace de pago y espera la confirmación del backend.
/// La app nunca marca una orden como pagada por sí sola.
class PagosyaCheckoutScreen extends ConsumerStatefulWidget {
  const PagosyaCheckoutScreen({super.key, required this.checkout});

  final PagosyaCheckout checkout;

  @override
  ConsumerState<PagosyaCheckoutScreen> createState() =>
      _PagosyaCheckoutScreenState();
}

class _PagosyaCheckoutScreenState extends ConsumerState<PagosyaCheckoutScreen> {
  static const _pollInterval = Duration(seconds: 4);
  static const _maxAttempts = 75; // ~5 minutos

  Timer? _timer;
  bool _checking = false;
  bool _finishing = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_pollInterval, (_) => _poll(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll({required bool silent}) async {
    if (!mounted || _checking || _finishing) return;
    if (_attempts >= _maxAttempts) {
      _timer?.cancel();
      return;
    }
    _attempts++;
    setState(() => _checking = true);

    try {
      final status = await const PagosyaService().refreshCheckout(
        orderId: widget.checkout.isTicket ? widget.checkout.orderId : null,
        intentId: widget.checkout.intentId,
      );

      if (status.paid) {
        await _finish();
      } else if (!silent && mounted) {
        AppFeedback.info(
          context,
          'Todavía no registramos el pago. Si ya pagaste, espera unos segundos.',
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        AppFeedback.error(context, friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      } else {
        _checking = false;
      }
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();

    try {
      if (!widget.checkout.isTicket) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      final result = await ref
          .read(ticketRepositoryProvider)
          .fetchOrderTickets(widget.checkout.orderId);

      if (!mounted) return;

      ref.invalidate(userGroupedTicketsProvider);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TicketQrScreen(result: result)),
      );
    } catch (e) {
      _finishing = false;
      if (!mounted) return;
      AppFeedback.error(context, friendlyError(e));
    }
  }

  Future<void> _openGateway() async {
    final url = widget.checkout.checkoutUrl;
    if (url == null || url.isEmpty) return;

    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      AppFeedback.error(context, 'No se pudo abrir la pasarela de pago.');
    }
  }

  Uint8List? get _qrBytes {
    final raw = widget.checkout.qrDataUrl;
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
    final checkout = widget.checkout;
    final qrBytes = _qrBytes;
    final title = switch (checkout.kind) {
      'class_pass' => 'Pagar pase de clase',
      'membership' => 'Pagar membresía',
      _ => 'Pagar orden ${checkout.orderNumber}',
    };

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: AppResponsiveBody(
        maxWidth: 560,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                border: Border.all(color: context.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total a pagar',
                    style: TextStyle(color: context.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${checkout.currency} ${checkout.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escanea el QR desde tu banca móvil o abre la pasarela. '
                    'El pago se acredita automáticamente al confirmarse.',
                    style: TextStyle(color: context.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (qrBytes != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                  child: Image.memory(qrBytes, width: 240, height: 240),
                ),
              )
            else if (checkout.hasQr)
              Center(
                child: Image.network(
                  checkout.qrDataUrl!,
                  width: 240,
                  height: 240,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 20),
            if (checkout.hasUrl)
              FilledButton.icon(
                onPressed: _openGateway,
                icon: const Icon(Icons.open_in_new),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                ),
                label: const Text('Abrir pasarela de pago'),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _finishing ? null : () => _poll(silent: false),
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: BorderSide(color: context.divider),
              ),
              label: const Text('Ya pagué, verificar'),
            ),
            const SizedBox(height: 16),
            Text(
              checkout.isTicket
                  ? 'El cobro vence a los 15 minutos. Si cierras la app, el pago se '
                        'confirma igualmente y verás tus entradas en "Mis entradas".'
                  : 'El cobro vence a los 15 minutos. La operación se activa '
                        'automáticamente cuando el backend confirma el pago.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
