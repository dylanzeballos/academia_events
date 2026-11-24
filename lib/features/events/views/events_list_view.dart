// lib/features/events/views/events_list_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/event_model.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';

class EventsListView extends ConsumerWidget {
  const EventsListView({super.key});

  Future<void> _navigateToCreate(BuildContext context, WidgetRef ref) async {
    final result = await context.push<bool>(AppRoutes.eventCreate);
    if (result == true || context.mounted) {
      ref.invalidate(orgEventsProvider);
    }
  }

  Future<void> _navigateToDetail(
    BuildContext context,
    WidgetRef ref,
    String eventId,
  ) async {
    final result = await context.push<bool>(
      '${AppRoutes.eventDetail}/$eventId',
    );
    if (result == true || context.mounted) {
      ref.invalidate(orgEventsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(orgEventsProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageClasses ?? false;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text('Eventos', style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.textMuted),
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
        data: (events) {
          if (events.isEmpty) {
            return AppEmptyState(
              icon: Icons.event_outlined,
              title: 'Sin eventos',
              message: canManage
                  ? 'Organiza y publica tu primer evento.'
                  : 'Todavía no hay eventos para mostrar.',
              actionLabel: canManage ? 'Crear evento' : null,
              onAction: canManage ? () => _navigateToCreate(context, ref) : null,
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(orgEventsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final event = events[index];
                return _EventTile(
                  event: event,
                  canManage: canManage,
                  onTap: () => _navigateToDetail(context, ref, event.id),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _navigateToCreate(context, ref),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: AppColors.onPrimary),
            )
          : null,
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.canManage,
    required this.onTap,
  });

  final EventModel event;
  final bool canManage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  event.title.isNotEmpty ? event.title[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (event.categoryName != null) ...[
                          Icon(Icons.category_outlined,
                              size: 12, color: context.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            event.categoryName!,
                            style: TextStyle(color: context.textMuted, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (event.capacity != null) ...[
                          Icon(Icons.people_outline,
                              size: 12, color: context.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${event.capacity} pers.',
                            style: TextStyle(color: context.textMuted, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: event.isPublished
                      ? AppColors.success.withValues(alpha: 0.15)
                      : context.textMuted.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  event.isPublished ? 'Publicado' : 'Borrador',
                  style: TextStyle(
                    color: event.isPublished ? AppColors.success : context.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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