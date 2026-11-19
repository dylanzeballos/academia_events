import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:academia_events/core/theme/app_colors.dart';

import 'stats_shared_widgets.dart';

class ViewsHeroCard extends StatelessWidget {
  const ViewsHeroCard({
    super.key,
    required this.current,
    required this.previous,
    required this.uniqueUsers,
    required this.trend,
  });

  final int current;
  final int previous;
  final int uniqueUsers;
  final List<double> trend;

  @override
  Widget build(BuildContext context) {
    final hasPrev = previous > 0;
    final pct = hasPrev ? ((current - previous) / previous * 100) : 0.0;
    final up = current >= previous;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              Color.lerp(AppColors.primary, AppColors.secondary, 0.85)!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -40,
              top: -40,
              child: _GlowCircle(size: 170, alpha: 0.10),
            ),
            const Positioned(
              left: -30,
              bottom: -60,
              child: _GlowCircle(size: 150, alpha: 0.07),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.visibility_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Visitas este mes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatsCountUp(
                        value: current,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (hasPrev)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  up
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${up ? '+' : ''}${pct.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasPrev
                        ? 'vs mes anterior ($previous) · $uniqueUsers usuarios únicos'
                        : '$uniqueUsers usuarios únicos · se reinicia cada mes',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                    ),
                  ),
                  if (trend.length >= 2) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 64,
                      width: double.infinity,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1400),
                        curve: Curves.easeOutCubic,
                        builder: (_, t, _) => CustomPaint(
                          painter:
                              _SparklinePainter(values: trend, progress: t),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.alpha});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.progress});
  final List<double> values;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);

    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          i * dx,
          size.height - 6 - ((values[i] - minV) / range) * (size.height - 14),
        ),
    ];

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final midX = (a.dx + b.dx) / 2;
      line.cubicTo(midX, a.dy, midX, b.dy, b.dx, b.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    if (progress > 0.98) {
      canvas.drawCircle(pts.last, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        pts.last,
        9,
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.values != values;
}