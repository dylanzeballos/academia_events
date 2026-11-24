import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/providers/organization_provider.dart';

import 'dashboard/viewsState/stats_shared_widgets.dart';
import 'dashboard/viewsState/views_hero_card.dart';
import 'dashboard/viewsState/views_history_card.dart';
import 'dashboard/viewsState/views_mini_kpi.dart';
import 'dashboard/viewsState/views_sources_card.dart';

class OrganizationViewsStatsView extends ConsumerWidget {
  const OrganizationViewsStatsView({super.key, required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = organizationViewsStatsProvider(organizationId);
    final statsAsync = ref.watch(provider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Estadísticas de visitas',
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => StatsErrorState(
          error: err,
          onRetry: () => ref.invalidate(provider),
        ),
        data: (stats) {
          final history = stats.monthlyHistory;

          final now = DateTime.now();
          final prevKey = DateFormat('yyyy-MM')
              .format(DateTime(now.year, now.month - 1));
          final prev =
              history
                  .where((e) => e['year_month'] == prevKey)
                  .map((e) => (e['views_count'] as num).toInt())
                  .firstOrNull ??
              0;

          final avg = history.isEmpty
              ? 0
              : (history.fold<int>(
                          0,
                          (s, e) => s + (e['views_count'] as num).toInt(),
                        ) /
                        history.length)
                    .round();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(provider);
              try {
                await ref.read(provider.future);
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                StatsReveal(
                  index: 0,
                  child: ViewsHeroCard(
                    current: stats.currentMonthViews,
                    previous: prev,
                    uniqueUsers: stats.uniqueMonthUsers,
                    trend: history.reversed
                        .map((e) => (e['views_count'] as num).toDouble())
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                StatsReveal(
                  index: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: ViewsMiniKpi(
                          icon: Icons.all_inclusive_rounded,
                          value: stats.totalViews,
                          label: 'Total histórico',
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ViewsMiniKpi(
                          icon: Icons.people_alt_rounded,
                          value: stats.uniqueMonthUsers,
                          label: 'Únicos este mes',
                          color: const Color(0xFF14B8A6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ViewsMiniKpi(
                          icon: Icons.show_chart_rounded,
                          value: avg,
                          label: 'Promedio mensual',
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (stats.monthSources.isNotEmpty) ...[
                  StatsReveal(
                    index: 2,
                    child: ViewsSourcesCard(sources: stats.monthSources),
                  ),
                  const SizedBox(height: 12),
                ],
                StatsReveal(
                  index: 3,
                  child: ViewsHistoryCard(history: history),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
