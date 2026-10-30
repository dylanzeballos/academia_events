// lib/features/academy/views/academy_archived_events_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/events_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import 'academy_events_view.dart' show AcademyEventCardItem;

class AcademyArchivedEventsView extends ConsumerWidget {
  const AcademyArchivedEventsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(orgEventsProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textOnBg, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Eventos Concluidos',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: Icon(Icons.refresh_rounded, color: context.textMuted),
            onPressed: () => ref.refresh(orgEventsProvider),
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorState(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(orgEventsProvider),
        ),
        data: (allEvents) {
          // Filtrar únicamente los eventos pasados
          final finishedEvents = allEvents.where((e) => e.endTime.isBefore(now)).toList();

          // Ordenar los concluidos del más reciente al más antiguo
          finishedEvents.sort((a, b) => b.endTime.compareTo(a.endTime));

          if (finishedEvents.isEmpty) {
            return const AppEmptyState(
              icon: Icons.history_rounded,
              title: 'Sin eventos concluidos',
              message: 'Aquí se mostrarán los eventos cuya fecha límite ya haya finalizado.',
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(orgEventsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: finishedEvents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final event = finishedEvents[index];
                return AcademyEventCardItem(
                  event: event,
                  isArchived: true,
                  onTap: () {
                    context.push('${AppRoutes.eventDetail}/${event.id}');
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}