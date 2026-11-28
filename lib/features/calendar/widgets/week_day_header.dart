import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/theme_extensions.dart';

class WeekDayHeader extends StatelessWidget {
  const WeekDayHeader({
    super.key,
    required this.day,
    required this.isSelected,
    required this.onTap,
    this.eventCount = 0,
    this.zoom = 1,
  });

  final DateTime day;
  final bool isSelected;
  final VoidCallback onTap;
  final int eventCount;
  final double zoom;

  bool get _isToday {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        margin: EdgeInsets.symmetric(horizontal: 2 * zoom, vertical: 4 * zoom),
        padding: EdgeInsets.symmetric(vertical: 6 * zoom),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium * zoom),
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
                fontSize: 9 * zoom,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.onPrimary : context.textMuted,
              ),
            ),
            SizedBox(height: 2 * zoom),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormatter.dayNumber(day),
                  style: TextStyle(
                    fontSize: 15 * zoom,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                    color: isSelected
                        ? AppColors.onPrimary
                        : _isToday
                        ? AppColors.primary
                        : context.textOnBg,
                  ),
                ),
                if (eventCount > 0) ...[
                  SizedBox(width: 3 * zoom),
                  Container(
                    width: 5 * zoom,
                    height: 5 * zoom,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
