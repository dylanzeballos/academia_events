import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../shared/widgets/app_section_card.dart';

/// Estado de la conexión bancaria del comercio.
class PagosyaBankStatusCard extends StatelessWidget {
  const PagosyaBankStatusCard({super.key, required this.account, this.summary});

  final Map<String, dynamic> account;
  final Map<String, dynamic>? summary;

  @override
  Widget build(BuildContext context) {
    final bank = summary?['bank'];
    final summaryStatus = bank is Map ? bank['status'] : null;
    final status = (account['bank_status'] ?? summaryStatus)?.toString();
    final connected = status == 'connected';
    final color = connected ? AppColors.success : AppColors.warning;

    final credentials = bank is Map ? bank['credentials_saved'] : null;
    final aes = bank is Map ? bank['aes_configured'] : null;

    return AppSectionCard(
      title: connected ? 'Banco conectado' : 'Banco pendiente',
      icon: connected ? Icons.verified : Icons.pending_outlined,
      trailing: status == null || status.isEmpty
          ? null
          : AppStatusChip(label: status, color: color),
      children: [
        Text(
          connected
              ? 'Los cobros QR están habilitados para esta organización.'
              : 'Guardar credenciales o enviar la carta todavía no habilita '
                    'cobros. PagosYa completa la clave AES y aprueba la conexión.',
          style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
        ),
        if (credentials != null || aes != null) ...[
          const SizedBox(height: 8),
          Text(
            'Credenciales: ${credentials == true ? 'sí' : 'no'} · '
            'AES: ${aes == true ? 'sí' : 'no'}',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
