import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../shared/widgets/app_section_card.dart';

/// Registro de la plataforma como comercio de PagosYa.
class PagosyaPlatformCard extends StatelessWidget {
  const PagosyaPlatformCard({
    super.key,
    required this.affiliateId,
    required this.busy,
    required this.onRegister,
  });

  final String? affiliateId;
  final bool busy;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final registered = (affiliateId ?? '').isNotEmpty;

    return AppSectionCard(
      title: 'Plataforma',
      icon: Icons.account_balance_outlined,
      children: [
        Text(
          registered
              ? 'La plataforma ya está registrada como comercio en PagosYa.'
              : 'Registrá la plataforma como comercio para cobrar membresías y '
                    'publicaciones con QR. Es un paso único y requiere la clave spk_.',
          style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
        ),
        if (registered) ...[
          const SizedBox(height: 8),
          SelectableText(
            affiliateId!,
            style: TextStyle(color: context.textOnBg, fontSize: 12),
          ),
        ] else ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : onRegister,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Registrar plataforma'),
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
    return AppStatusChip(
      label: status ?? 'sin banco',
      color: connected ? AppColors.success : AppColors.warning,
    );
  }
}
