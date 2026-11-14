// lib/features/tickets/widgets/class_pass_purchase_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_enrollment_model.dart';
import '../../../data/services/pagosya_service.dart';
import '../../../providers/checkin_provider.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../tickets/views/pagosya_checkout_screen.dart';

class ClassPassPurchaseSheet extends ConsumerStatefulWidget {
  const ClassPassPurchaseSheet({super.key, required this.enrollment});

  final ClassEnrollmentModel enrollment;

  @override
  ConsumerState<ClassPassPurchaseSheet> createState() =>
      _ClassPassPurchaseSheetState();
}

class _ClassPassPurchaseSheetState
    extends ConsumerState<ClassPassPurchaseSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final checkout = await const PagosyaService().createCheckout(
        kind: 'class_pass',
        referenceId: widget.enrollment.id,
      );

      if (!mounted) return;

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PagosyaCheckoutScreen(checkout: checkout),
        ),
      );

      if (paid == true) {
        ref.invalidate(myClassPassesProvider);
        ref.invalidate(myClassTicketsProvider);
        ref.invalidate(classPassQuoteProvider(widget.enrollment.id));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Comprar pase',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _Summary(enrollment: widget.enrollment),
              const SizedBox(height: 20),
              if (_error != null) ...[
                _ErrorPanel(
                  message: _error!,
                  onRetry: null,
                  onClose: () => setState(() => _error = null),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  ),
                ),
                onPressed: _busy ? null : _pay,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.qr_code_2),
                label: Text(
                  _busy ? 'Generando cobro...' : 'Pagar con QR',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Se abrirá el QR de pago. El pase se activa automáticamente al confirmarse.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.enrollment});

  final ClassEnrollmentModel enrollment;

  String _formatAmount(num amount, String currency) {
    final symbol = currency.trim().toUpperCase() == 'BOB' ? 'Bs. ' : '';
    final value = amount.toStringAsFixed(2);
    if (symbol.isNotEmpty) return '$symbol$value';
    return '$value $currency';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteAsync = ref.watch(classPassQuoteProvider(enrollment.id));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: context.divider),
      ),
      child: quoteAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No se pudo calcular el precio.',
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
          ),
        ),
        data: (quote) {
          final count = (quote['session_count'] as int?) ?? 0;
          final price = (quote['price'] as num?) ?? 0;
          final total = (quote['total_amount'] as num?) ?? 0;
          final currency = (quote['currency'] as String?) ?? 'BOB';
          final lastDate = quote['last_session_date'] != null
              ? DateTime.tryParse(quote['last_session_date'] as String)
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school_outlined, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      enrollment.classTitle ?? 'Clase',
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (enrollment.organizationName != null) ...[
                const SizedBox(height: 4),
                Text(
                  enrollment.organizationName!,
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 16,
                    color: context.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    count == 1
                        ? '1 sesión programada'
                        : '$count sesiones programadas',
                    style: TextStyle(color: context.textMuted, fontSize: 13),
                  ),
                ],
              ),
              if (lastDate != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 16,
                      color: context.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Última sesión: ${DateFormat('d MMM yyyy', 'es').format(lastDate)}',
                      style: TextStyle(color: context.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 16,
                    color: context.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatAmount(price, currency)} por sesión',
                    style: TextStyle(color: context.textMuted, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total a pagar',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatAmount(total, currency),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Incluye un ticket con QR por cada sesión programada desde hoy.',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 56),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 20),
        if (onRetry != null)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.textOnBg,
              side: BorderSide(color: context.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
            onPressed: onRetry,
            child: const Text('Reintentar'),
          )
        else
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
            onPressed: onClose,
            child: const Text('Entendido'),
          ),
      ],
    );
  }
}
