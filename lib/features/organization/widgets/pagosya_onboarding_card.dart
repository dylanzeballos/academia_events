import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../shared/widgets/app_section_card.dart';

/// Alta del comercio en PagosYa (una sola vez por organización).
class PagosyaOnboardingCard extends StatelessWidget {
  const PagosyaOnboardingCard({
    super.key,
    required this.busy,
    required this.onActivate,
  });

  final bool busy;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Activá los cobros QR',
      icon: Icons.qr_code_2,
      children: [
        Text(
          'Se crea el vínculo de la organización con PagosYa. El titular no '
          'necesita una cuenta en PagosYa: solo conecta su banco.',
          style: TextStyle(color: context.textMuted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: busy ? null : onActivate,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add_card),
          label: Text(busy ? 'Activando...' : 'Activar cobros QR'),
        ),
      ],
    );
  }
}
