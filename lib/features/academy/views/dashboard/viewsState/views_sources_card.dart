import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

import 'stats_shared_widgets.dart';

class ViewsSourcesCard extends StatefulWidget {
  const ViewsSourcesCard({super.key, required this.sources});
  final List<Map<String, dynamic>> sources;

  @override
  State<ViewsSourcesCard> createState() => _ViewsSourcesCardState();
}

class _ViewsSourcesCardState extends State<ViewsSourcesCard> {
  int? _selected;

  static const _palette = [
    AppColors.primary,
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
  ];

  ({String name, String desc, IconData icon}) _info(String raw) {
    switch (raw.toLowerCase()) {
      case 'qr':
        return (
          name: 'Código QR',
          desc: 'Escanearon tu QR',
          icon: Icons.qr_code_2_rounded,
        );
      case 'web':
        return (
          name: 'Sitio web',
          desc: 'Entraron desde el navegador',
          icon: Icons.language_rounded,
        );
      case 'app':
        return (
          name: 'Aplicación',
          desc: 'Te encontraron dentro de la app',
          icon: Icons.smartphone_rounded,
        );
      default:
        final n = raw.isEmpty ? 'Otro' : raw[0].toUpperCase() + raw.substring(1);
        return (name: n, desc: 'Otro origen', icon: Icons.touch_app_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.sources;
    final values = sources.map((s) => (s['count'] as num).toDouble()).toList();
    final colors = [
      for (var i = 0; i < sources.length; i++) _palette[i % _palette.length],
    ];
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();

    final topInfo = _info(sources.first['source'] as String);
    final topPct = (values.first / total * 100).round();

    final sel = _selected;
    final centerValue = sel == null ? total.toInt() : values[sel].toInt();
    final centerLabel =
        sel == null ? 'visitas' : _info(sources[sel]['source'] as String).name;

    return StatsSectionCard(
      title: 'Origen de las visitas',
      subtitle: 'Toca un origen para resaltarlo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.first.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(topInfo.icon, color: colors.first, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sources.length == 1
                        ? 'Todas las visitas llegaron por ${topInfo.name}'
                        : 'La mayoría llega por ${topInfo.name} ($topPct%)',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, t, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(150, 150),
                      painter: _DonutPainter(
                        values: values,
                        colors: colors,
                        trackColor: context.divider,
                        progress: t,
                        selected: sel,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(centerValue * t).round()}',
                          style: TextStyle(
                            color: context.textOnBg,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          centerLabel,
                          style: TextStyle(
                            color: sel == null
                                ? context.textMuted
                                : colors[sel],
                            fontSize: 11.5,
                            fontWeight: sel == null
                                ? FontWeight.w500
                                : FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < sources.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == sources.length - 1 ? 0 : 10),
              child: _SourceRow(
                info: _info(sources[i]['source'] as String),
                color: colors[i],
                count: values[i].toInt(),
                percent: values[i] / total,
                selected: sel == i,
                dimmed: sel != null && sel != i,
                onTap: () => setState(() => _selected = sel == i ? null : i),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.info,
    required this.color,
    required this.count,
    required this.percent,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final ({String name, String desc, IconData icon}) info;
  final Color color;
  final int count;
  final double percent;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dimmed ? 0.45 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : context.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(info.icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.name,
                          style: TextStyle(
                            color: context.textOnBg,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          info.desc,
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${(percent * 100).round()}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: percent),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v.clamp(0.03, 1.0),
                    minHeight: 7,
                    backgroundColor: context.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
    required this.progress,
    required this.selected,
  });

  final List<double> values;
  final List<Color> colors;
  final Color trackColor;
  final double progress;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    const strokeSel = 22.0;
    final rect = (Offset.zero & size).deflate(strokeSel / 2);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    final gap = values.length > 1 ? 0.05 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2 * progress;
      final draw = math.max(sweep - gap, 0.0);
      final isSel = selected == i;
      final dimmed = selected != null && !isSel;
      if (draw > 0) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          draw,
          false,
          Paint()
            ..color = colors[i].withValues(alpha: dimmed ? 0.3 : 1)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.butt
            ..strokeWidth = isSel ? strokeSel : stroke,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.selected != selected;
}