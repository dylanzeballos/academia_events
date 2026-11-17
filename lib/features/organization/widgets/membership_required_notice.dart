import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/membership_provider.dart';
import '../views/organization_membership_view.dart';

/// Aviso bloqueante cuando la organización no tiene una membresía activa.
class MembershipRequiredNotice extends ConsumerWidget {
  const MembershipRequiredNotice({
    super.key,
    required this.organizationId,
    this.error = false,
  });

  final String organizationId;
  final bool error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                error ? Icons.error_outline : Icons.card_membership_outlined,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error
                      ? 'No pudimos verificar tu membresía'
                      : 'Se requiere una membresía activa',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            error
                ? 'Revisá tu conexión e intentá de nuevo.'
                : 'Para crear eventos y clases necesitás una membresía vigente. '
                      'Además, tu organización aparece en el carrusel del '
                      'calendario principal.',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (!error) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: context.scaffoldBg,
                      appBar: AppBar(
                        backgroundColor: context.cardBg,
                        title: const Text('Membresías'),
                      ),
                      body: OrganizationMembershipView(
                        organizationId: organizationId,
                      ),
                    ),
                  ),
                );
                if (context.mounted) {
                  ref.invalidate(
                    organizationMembershipProvider(organizationId),
                  );
                }
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textOnBg,
                side: BorderSide(color: context.divider),
              ),
              label: const Text('Ver membresías'),
            ),
          ],
        ],
      ),
    );
  }
}
