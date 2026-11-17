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
  static const _maxAttempts = 150; // ~10 minutos de sondeo silencioso
  static const _fallbackTtl = Duration(minutes: 15);

  Timer? _pollTimer;
  Timer? _countdownTimer;

  late final Uint8List? _qrBytes;
  late final DateTime _expiresAt;
  Duration _remaining = Duration.zero;

  bool _checking = false;
  bool _polling = false;
  bool _finishing = false;
  bool _expired = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();

    // Decodificar el QR una sola vez evita que se "recargue" en cada rebuild.
    _qrBytes = _decodeQr(widget.checkout.qrDataUrl);
    _expiresAt =
        widget.checkout.expiresAt ?? DateTime.now().add(_fallbackTtl);
    _remaining = _expiresAt.difference(DateTime.now());

    if (_remaining <= Duration.zero) {
      _expired = true;
      _remaining = Duration.zero;
    } else {
      _pollTimer = Timer.periodic(_pollInterval, (_) => _poll(silent: true));
      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tickCountdown(),
      );
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _tickCountdown() {
    if (!mounted || _expired) return;

    final left = _expiresAt.difference(DateTime.now());
    if (left <= Duration.zero) {
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _expired = true;
        _remaining = Duration.zero;
      });
      return;
    }

    if (left.inSeconds != _remaining.inSeconds) {
      setState(() => _remaining = left);
    }
  }

  Future<void> _poll({required bool silent}) async {
    if (!mounted || _polling || _checking || _finishing || _expired) return;
    if (_attempts >= _maxAttempts) {
      _pollTimer?.cancel();
      return;
    }
    _attempts++;
    _polling = true;

    // El sondeo silencioso no toca el estado visual: así el QR no parpadea.
    if (!silent) setState(() => _checking = true);

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
          widget.checkout.sandbox
              ? 'El sandbox no confirma pagos. Usá «Simular pago (sandbox)» '
                    'para completar la prueba.'
              : 'Todavía no registramos el pago. Si ya pagaste, espera unos segundos.',
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        AppFeedback.error(context, friendlyError(e));
      }
    } finally {
      _polling = false;
      if (!silent && mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _pollTimer?.cancel();
    _countdownTimer?.cancel();

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

  /// Confirma el checkout de prueba sin pago real. Solo existe en sandbox.
  Future<void> _simulatePayment() async {
    if (_checking || _finishing || _expired) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(
          'Simular pago (sandbox)',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Se marcará este pedido como pagado sin cobro real y se emitirán '
          'los tickets, butacas o el pase. ¿Continuar?',
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simular'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _checking = true);

    try {
      await const PagosyaService().sandboxConfirm(
        orderId: widget.checkout.isTicket ? widget.checkout.orderId : null,
        intentId: widget.checkout.isTicket ? null : widget.checkout.intentId,
      );
      await _finish();
    } catch (e) {
      if (mounted) AppFeedback.error(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  static Uint8List? _decodeQr(String? raw) {
    if (raw == null || !raw.startsWith('data:image')) return null;
    final comma = raw.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(raw.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  static String _formatRemaining(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
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
    final urgent = !_expired && _remaining <= const Duration(minutes: 1);
    final timerColor = _expired
        ? AppColors.error
        : (urgent ? AppColors.warning : context.textMuted);

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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _expired
                            ? Icons.timer_off_outlined
                            : Icons.timer_outlined,
                        size: 16,
                        color: timerColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _expired
                            ? 'Cobro expirado'
                            : 'Vence en ${_formatRemaining(_remaining)}',
                        style: TextStyle(
                          color: timerColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (checkout.sandbox) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.science_outlined,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Modo sandbox: este QR es ficticio y no procesa pagos. '
                        'Usá «Simular pago» para probar tickets y butacas.',
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (qrBytes != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                  child: Image.memory(
                    qrBytes,
                    width: 240,
                    height: 240,
                    gaplessPlayback: true,
                  ),
                ),
              )
            else if (checkout.hasQr)
              Center(
                child: Image.network(
                  checkout.qrDataUrl!,
                  width: 240,
                  height: 240,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 20),
            if (checkout.hasUrl)
              FilledButton.icon(
                onPressed: _expired ? null : _openGateway,
                icon: const Icon(Icons.open_in_new),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                ),
                label: const Text('Abrir pasarela de pago'),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _finishing || _expired
                  ? null
                  : () => _poll(silent: false),
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
            if (checkout.sandbox) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _checking || _finishing || _expired
                    ? null
                    : _simulatePayment,
                icon: const Icon(Icons.play_circle_outline),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                label: const Text('Simular pago (sandbox)'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _expired
                  ? 'El cobro expiró. Cerrá esta pantalla y generá uno nuevo.'
                  : checkout.isTicket
                  ? 'Si cierras la app, la confirmación no depende de esta '
                        'pantalla: verás tus entradas en "Mis entradas".'
                  : 'La operación se activa automáticamente cuando el backend '
                        'confirma el pago.',              textAlign: TextAlign.center,
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
