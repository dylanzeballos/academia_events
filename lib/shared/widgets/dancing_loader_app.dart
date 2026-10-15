import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';

class DancingLoader extends StatelessWidget {
  const DancingLoader({
    super.key,
    this.size = 200,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardBg.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: context.divider,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Lottie.network(
                  'https://assets2.lottiefiles.com/packages/lf20_t1q9y92m.json',
                  width: size * 0.9,
                  height: size * 0.9,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return SizedBox(
                      width: size * 0.5,
                      height: size * 0.5,
                      child: CircularProgressIndicator(
                        color: accent,
                        strokeWidth: 3,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 140,
            child: LinearProgressIndicator(
              color: accent,
              backgroundColor: context.divider,
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cargando aplicación...',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 13,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}