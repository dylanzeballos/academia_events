import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AttendanceBarValue {
  const AttendanceBarValue({required this.value, required this.color});

  final double value;
  final Color color;
}

class AttendanceBarGroup {
  const AttendanceBarGroup({required this.label, required this.values});

  final String label;
  final List<AttendanceBarValue> values;

  double get total => values.fold<double>(0, (acc, v) => acc + v.value);
}

class AttendanceBarLegend {
  const AttendanceBarLegend({required this.label, required this.color});

  final String label;
  final Color color;
}

/// Barras agrupadas (varias series por grupo), usadas para ventas por tipo de
/// entrada o asistencia por sesión.
class AttendanceBarChart extends StatelessWidget {
  const AttendanceBarChart({
    super.key,
    required this.groups,
    this.height = 220,
    this.legends = const [],
  });

  final List<AttendanceBarGroup> groups;
  final double height;
  final List<AttendanceBarLegend> legends;

  @override
  Widget build(BuildContext context) {
    final shown = groups.length > 12 ? groups.sublist(groups.length - 12) : groups;
    final maxSummary =
        shown.fold<double>(0, (acc, g) => g.total > acc ? g.total : acc);
    final maxY = maxSummary <= 0 ? 4.0 : (maxSummary * 1.2).ceilToDouble();
    final interval = _niceInterval(maxY);

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                minY: 0,
                barTouchData: BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: interval,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= shown.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            shown[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey, fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                groupsSpace: 12,
                barGroups: [
                  for (var i = 0; i < shown.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        for (final v in shown[i].values)
                          BarChartRodData(
                            toY: v.value,
                            color: v.color,
                            width: 6,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 300),
            ),
          ),
          if (legends.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final l in legends)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: l.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l.label,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  double _niceInterval(double maxY) {
    final candidates = [2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0];
    for (final c in candidates) {
      if (maxY / c <= 5) return c;
    }
    return 500.0;
  }
}