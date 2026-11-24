import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

import 'stats_shared_widgets.dart';

class ViewsHistoryCard extends StatefulWidget {
  const ViewsHistoryCard({super.key, required this.history});
  final List<Map<String, dynamic>> history;

  @override
  State<ViewsHistoryCard> createState() => _ViewsHistoryCardState();
}

class _ViewsHistoryCardState extends State<ViewsHistoryCard> {
  late List<Map<String, dynamic>> _data;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _data = widget.history.reversed.toList();
    _selected = _data.isEmpty ? 0 : _data.length - 1;
  }

  @override
  void didUpdateWidget(covariant ViewsHistoryCard old) {
    super.didUpdateWidget(old);
    if (old.history != widget.history) {
      _data = widget.history.reversed.toList();
      _selected = _data.isEmpty ? 0 : _data.length - 1;
    }
  }

  DateTime _date(String ym) {
    final p = ym.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]));
  }

  String _long(String ym) {
    final label = DateFormat('MMMM yyyy', 'es').format(_date(ym));
    return label[0].toUpperCase() + label.substring(1);
  }

  String _short(String ym) {
    final label = DateFormat('MMM', 'es').format(_date(ym));
    return label[0].toUpperCase() + label.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_data.isEmpty) {
      return StatsSectionCard(
        title: 'Historial mensual',
        subtitle: 'Últimos 12 meses',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.insights_rounded,
                    size: 40, color: context.textMuted),
                const SizedBox(height: 8),
                Text(
                  'Aún no hay visitas registradas',
                  style: TextStyle(color: context.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final counts = _data.map((e) => (e['views_count'] as num).toInt()).toList();
    final maxV = math.max(counts.reduce(math.max), 1);
    final best = counts.indexOf(counts.reduce(math.max));
    final sel = _data[_selected];
    final selCount = (sel['views_count'] as num).toInt();
    final selUniq = (sel['unique_users'] as num?)?.toInt() ?? 0;

    const barArea = 140.0;

    return StatsSectionCard(
      title: 'Historial mensual',
      subtitle: 'Toca una barra para ver el detalle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey(_selected),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _long(sel['year_month'] as String),
                              style: TextStyle(
                                color: context.textOnBg,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_selected == best) ...[
                              const SizedBox(width: 8),
                              const Text('🏆', style: TextStyle(fontSize: 13)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$selUniq usuarios únicos',
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$selCount',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    selCount == 1 ? 'visita' : 'visitas',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: barArea + 26,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < _data.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TweenAnimationBuilder<double>(
                              key: ValueKey('bar_$i'),
                              tween: Tween(
                                begin: 0,
                                end: math.max(counts[i] / maxV, 0.04),
                              ),
                              duration: Duration(milliseconds: 700 + i * 70),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) {
                                final isSel = i == _selected;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: barArea * v,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: isSel
                                        ? const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              AppColors.primary,
                                              AppColors.secondary,
                                            ],
                                          )
                                        : null,
                                    color: isSel
                                        ? null
                                        : AppColors.primary
                                            .withValues(alpha: 0.28),
                                    boxShadow: isSel
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _short(_data[i]['year_month'] as String),
                              style: TextStyle(
                                color: i == _selected
                                    ? context.textOnBg
                                    : context.textMuted,
                                fontSize: 10,
                                fontWeight: i == _selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}