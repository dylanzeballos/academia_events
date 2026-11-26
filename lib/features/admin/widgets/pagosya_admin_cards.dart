import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../shared/widgets/app_section_card.dart';

/// Registro de la plataforma como comercio de PagosYa y estado de su banco.
class PagosyaPlatformCard extends StatelessWidget {
  const PagosyaPlatformCard({
    super.key,
    required this.affiliateId,
    required this.bankStatus,
    required this.busy,
    required this.onRegister,
    required this.onConnectBank,
    required this.onRefresh,
    this.error,
  });

  final String? affiliateId;
  final String? bankStatus;
  final bool busy;
  final VoidCallback onRegister;
  final VoidCallback onConnectBank;
  final VoidCallback onRefresh;
  final String? error;

  bool get _registered => (affiliateId ?? '').isNotEmpty;

  bool get _bankConnected => (bankStatus ?? '').toLowerCase() == 'connected';

  String get _bankLabel {
    final status = (bankStatus ?? '').trim();
    if (status.isEmpty) return 'Sin conectar';
    switch (status.toLowerCase()) {
      case 'connected':
        return 'Conectado';
      case 'pending':
      case 'in_progress':
        return 'Pendiente';
      case 'rejected':
      case 'failed':
        return 'Rechazado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Plataforma',
      icon: Icons.account_balance_outlined,
      children: [
        Text(
          _registered
              ? 'La plataforma ya está registrada como comercio en PagosYa. '
                    'Las membresías y publicaciones se cobran a esta cuenta.'
              : 'Registrá la plataforma como comercio para cobrar membresías y '
                    'publicaciones con QR. Es un paso único y requiere la clave spk_.',
          style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
        ),
        if (!_registered) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: busy ? null : onRegister,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Registrar plataforma'),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comercio de la plataforma',
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      affiliateId!,
                      style: TextStyle(color: context.textOnBg, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppStatusChip(
                label: _bankLabel,
                color: _bankConnected ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _bankConnected
                ? 'El banco está conectado: las membresías ya se pueden cobrar.'
                : 'Conectá el banco para recibir el dinero de las membresías. '
                      'Sin banco, PagosYa rechaza el cobro con '
                      'BANK_INTEGRATION_REQUIRED.',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              'No se pudo consultar el banco: $error',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_bankConnected)
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: busy ? null : onConnectBank,
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Conectar banco'),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: busy ? null : onConnectBank,
                  icon: const Icon(Icons.sync_outlined),
                  label: const Text('Reconectar banco'),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: busy ? null : onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualizar estado'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Cupo del plan y capacidad usada (acción overview).
class PagosyaPlanCard extends StatelessWidget {
  const PagosyaPlanCard({super.key, required this.overview, this.error});

  final Map<String, dynamic>? overview;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final license = overview?['license'];
    final limit = license is Map ? license['merchant_limit'] : null;
    final merchants = overview?['merchants'] ?? overview?['data'];
    final used =
        overview?['capacity_used'] ??
        (merchants is List ? merchants.length : null);

    return AppSectionCard(
      title: 'Plan y cartera',
      icon: Icons.insights_outlined,
      children: [
        if (error != null)
          _muted(context, 'No se pudo consultar el plan: $error')
        else if (overview == null)
          _muted(context, 'Consultando plan...')
        else ...[
          _muted(
            context,
            'Comercios afiliados: ${used ?? '—'}'
            '${limit != null ? ' de $limit' : ''}',
          ),
          if (merchants is List && merchants.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final merchant in merchants.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${_merchantName(merchant)}',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ),
          ],
        ],
      ],
    );
  }

  String _merchantName(Object? merchant) {
    if (merchant is! Map) return merchant?.toString() ?? 'Comercio';
    return (merchant['display_name'] ??
            merchant['name'] ??
            merchant['id'] ??
            'Comercio')
        .toString();
  }

  Widget _muted(BuildContext context, String text) => Text(
    text,
    style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
  );
}

/// Organizaciones con cuenta de cobros y estado del banco.
class PagosyaAccountsCard extends StatelessWidget {
  const PagosyaAccountsCard({super.key, required this.accounts});

  final List<Map<String, dynamic>> accounts;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Comercios afiliados',
      icon: Icons.storefront_outlined,
      children: [
        if (accounts.isEmpty)
          Text(
            'Todavía no hay organizaciones con cuenta de cobros.',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          )
        else
          for (final account in accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _organizationName(account),
                      style: TextStyle(color: context.textOnBg, fontSize: 13),
                    ),
                  ),
                  _bankChip(account['bank_status']?.toString()),
                ],
              ),
            ),
      ],
    );
  }

  String _organizationName(Map<String, dynamic> account) {
    final org = account['organizations'];
    if (org is Map) return org['name']?.toString() ?? 'Organización';
    return account['organization_id']?.toString() ?? 'Organización';
  }

  Widget _bankChip(String? status) {
    final connected = status == 'connected';
    final normalized = status?.trim().toLowerCase();
    final label = switch (normalized) {
      null || '' => 'Sin banco',
      'connected' => 'Conectado',
      'pending' || 'in_progress' => 'Pendiente',
      'rejected' || 'failed' => 'Rechazado',
      _ => status!,
    };
    return AppStatusChip(
      label: label,
      color: connected ? AppColors.success : AppColors.warning,
    );
  }
}
