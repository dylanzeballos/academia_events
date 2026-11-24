import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';

/// Encabezado de días de la grilla semanal. El día actual se destaca para que
/// la academia sepa de un vistazo dónde está parada.
class ScheduleHeader extends StatelessWidget {
  const ScheduleHeader({
    super.key,
    required this.colWidth,
    required this.daysOfWeek,
    required this.headerHeight,
    this.highlightToday = true,
  });

  final double colWidth;
  final List<(int, String, String)> daysOfWeek;
  final double headerHeight;
  final bool highlightToday;

  @override
  Widget build(BuildContext context) {
    // 1 = lunes … 7 = domingo; en la grilla el domingo es 0.
    final today = highlightToday ? DateTime.now().weekday % 7 : -1;

    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        color: context.surfaceHeader,
        border: Border(bottom: BorderSide(color: context.divider, width: 1.2)),
      ),
      child: Row(
        children: daysOfWeek.map((d) {
          final isToday = d.$1 == today;
          final color = isToday ? AppColors.primary : context.textMuted;

          return SizedBox(
            width: colWidth,
            child: Semantics(
              label: isToday ? 'hoy' : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        d.$3,
                        style: TextStyle(
                          color: color,
                          fontWeight: isToday
                              ? FontWeight.w900
                              : FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 2.5,
                      width: isToday ? 18 : 0,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
