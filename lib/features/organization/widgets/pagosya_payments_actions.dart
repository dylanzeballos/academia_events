import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';

/// Acciones del comercio: banco, estado y comisiones.
class PagosyaPaymentsActions extends StatelessWidget {
  const PagosyaPaymentsActions({
    super.key,
    required this.busy,
    required this.onConnectBank,
    required this.onRefresh,
    required this.onCommissions,
  });

  final bool busy;
  final VoidCallback onConnectBank;
  final VoidCallback onRefresh;
  final VoidCallback onCommissions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          onPressed: busy ? null : onConnectBank,
          icon: const Icon(Icons.account_balance_outlined),
          label: const Text('Conectar banco'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onRefresh,
          icon: const Icon(Icons.sync),
          label: const Text('Actualizar estado'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onCommissions,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Ver comisiones'),
        ),
      ],
    );
  }
}

/// Mensaje para miembros sin permisos de administración.
class PagosyaNoPermission extends StatelessWidget {
  const PagosyaNoPermission({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Solo el propietario o un administrador de la organización '
          'puede gestionar los cobros.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textMuted),
        ),
      ),
    );
  }
}
