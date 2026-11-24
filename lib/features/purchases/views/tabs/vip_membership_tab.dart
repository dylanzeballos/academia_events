import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../qr_payment_view.dart';

class VipMembershipTab extends StatelessWidget {
  const VipMembershipTab({super.key});

  @override
  Widget build(BuildContext context) {
    const double vipPrice = 350.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PASE VIP ALL-ACCESS',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                      child: const Text(
                        'ILIMITADO',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${vipPrice.toInt()} BOB / mes',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Entrena todos los días en cualquier disciplina',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Lo que incluye tu membresía VIP:',
            style: TextStyle(color: context.textOnBg, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const _VipItem(
            icon: Icons.all_inclusive,
            title: 'Sesiones ilimitadas',
            desc: 'Acceso a todas las clases de la academia.',
          ),
          const _VipItem(
            icon: Icons.qr_code_rounded,
            title: 'Check-in Preferencial',
            desc: 'Acceso rápido con escáner QR sin límite de asistencias al día.',
          ),
          const _VipItem(
            icon: Icons.stars_rounded,
            title: 'Talleres y Eventos VIP',
            desc: 'Descuentos exclusivos y reportes mensuales.',
          ),
          const SizedBox(height: 24),

          AppButton(
            label: 'Obtener Pase VIP con QR',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const QrPaymentView(
                    title: 'Pase VIP All-Access',
                    details: 'Membresía mensual ilimitada (30 días)',
                    amount: vipPrice,
                    isVip: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VipItem extends StatelessWidget {
  const _VipItem({required this.icon, required this.title, required this.desc});

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: context.textOnBg, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: context.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}