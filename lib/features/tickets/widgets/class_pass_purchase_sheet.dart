import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_enrollment_model.dart';
import '../../../providers/checkin_provider.dart';

/// Compra (pago simulado) de un pase de clase sobre una inscripción.
class ClassPassPurchaseSheet extends ConsumerStatefulWidget {
  const ClassPassPurchaseSheet({super.key, required this.enrollment});

  final ClassEnrollmentModel enrollment;

  @override
  ConsumerState<ClassPassPurchaseSheet> createState() =>
      _ClassPassPurchaseSheetState();
}

class _ClassPassPurchaseSheetState extends ConsumerState<ClassPassPurchaseSheet> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final purchaseAsync =
        _started ? ref.watch(purchaseClassPassProvider(widget.enrollment.id)) : null;

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
              if (purchaseAsync == null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    setState(() => _started = true);
                    ref.invalidate(purchaseClassPassProvider(widget.enrollment.id));
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Confirmar pago (simulado)'),
                )
              else
                purchaseAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorPanel(
                    message: e.toString(),
                    onRetry: () {
                      ref.invalidate(purchaseClassPassProvider(widget.enrollment.id));
                    },
                    onClose: () {
                      setState(() => _started = false);
                      Navigator.of(context).pop();
                    },
                  ),
                  data: (result) {
                    final success = result['success'] == true;
                    if (!success) {
                      return _ErrorPanel(
                        message: (result['reason'] as String?) ??
                            'No se pudo comprar el pase.',
                        onRetry: null,
                        onClose: () => Navigator.of(context).pop(),
                      );
                    }
                    // Refrescar pases y tickets para las demás vistas.
                    ref.invalidate(myClassPassesProvider);
                    ref.invalidate(myClassTicketsProvider);
                    return _SuccessPanel(
                      result: result,
                      onDone: () => Navigator.of(context).pop(),
                    );
                  },
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
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No se pudo calcular el precio.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
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
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.event_available, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    count == 1
                        ? '1 sesión programada'
                        : '$count sesiones programadas',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              if (lastDate != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.flag_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Última sesión: ${DateFormat('d MMM yyyy', 'es').format(lastDate)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatAmount(price, currency)} por sesión',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              const Text(
                'Incluye un ticket con QR por cada sesión programada desde hoy.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({required this.result, required this.onDone});

  final Map<String, dynamic> result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final generated = result['tickets_generated'] as int? ?? 0;
    final endsAt = result['ends_at'] != null
        ? DateTime.tryParse(result['ends_at'] as String)
        : null;
    final total = (result['total_amount'] as num?) ?? 0;
    final currency = (result['currency'] as String?) ?? 'BOB';
    final symbol = currency.trim().toUpperCase() == 'BOB' ? 'Bs. ' : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 56),
        const SizedBox(height: 12),
        Text(
          'Pase activado',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          generated == 1
              ? 'Se generó 1 ticket de sesión.'
              : 'Se generaron $generated tickets de sesión.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        if (total > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Total pagado: $symbol${total.toStringAsFixed(2)}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
        if (endsAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Última sesión incluida: ${DateFormat('d MMM yyyy', 'es').format(endsAt.toLocal())}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: onDone,
          child: const Text('Listo'),
        ),
      ],
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
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 20),
        if (onRetry != null)
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          )
        else
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: onClose,
            child: const Text('Entendido'),
          ),
      ],
    );
  }
}