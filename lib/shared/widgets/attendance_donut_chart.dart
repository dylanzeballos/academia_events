import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/utils/theme_extensions.dart';

class AttendanceSlice {
  const AttendanceSlice({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;
}

/// Donut con leyenda, usado para distribuciones (vendido/disponible,
/// presente/tarde/ausente/pendiente, etc.).
class AttendanceDonutChart extends StatelessWidget {
  const AttendanceDonutChart({
    super.key,
    required this.slices,
    required this.centerTop,
    required this.centerBottom,
    this.height = 220,
    this.total,
  });

  final List<AttendanceSlice> slices;
  final String centerTop;
  final String centerBottom;
  final double height;
  final double? total;

  @override
  Widget build(BuildContext context) {
    final filtered = slices.where((s) => s.value > 0).toList();
    final sum = total ?? filtered.fold<double>(0, (acc, s) => acc + s.value);

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 46,
                startDegreeOffset: -90,
                sections: [
                  for (final s in filtered)
                    PieChartSectionData(
                      value: s.value,
                      color: s.color,
                      radius: 30,
                      showTitle: false,
                    ),
                  if (filtered.isEmpty)
                    PieChartSectionData(
                      value: 1,
                      color: Colors.grey.withValues(alpha: 0.15),
                      radius: 30,
                      showTitle: false,
                    ),
                ],
                centerSpaceColor: Colors.transparent,
              ),
              duration: const Duration(milliseconds: 300),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            centerTop,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            centerBottom,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (sum <= 0 || filtered.isEmpty) ...[
            const SizedBox(height: 4),
            const Text(
              'Sin datos todavía',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in slices)
                _LegendItem(slice: s, total: sum),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.slice, required this.total});

  final AttendanceSlice slice;
  final double total;

  @override
  Widget build(BuildContext context) {
    final isTotal = total > 0;
    final percent =
        isTotal ? (slice.value / total * 100).toStringAsFixed(0) : '0';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: slice.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${slice.label} ${isTotal ? '($percent%)' : ''}',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}