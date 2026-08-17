import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';

/// Cabecera de un día en el selector semanal (Lun / 16).
class WeekDayHeader extends StatelessWidget {
  const WeekDayHeader({
    super.key,
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final bool isSelected;
  final VoidCallback onTap;

  bool get _isToday {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: _isToday && !isSelected
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormatter.shortDay(day).toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormatter.dayNumber(day),
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : _isToday
                        ? AppColors.primary
                        : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
