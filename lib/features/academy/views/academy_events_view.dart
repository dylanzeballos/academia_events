import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';

final orgEventsProvider = FutureProvider((ref) async {
  final orgId = ref.watch(selectedOrganizationIdProvider);
  if (orgId == null) return [];
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.fetchOrganizationEvents(orgId);
});

class AcademyEventsView extends ConsumerWidget {
  const AcademyEventsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(orgEventsProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageClasses ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos'),
      ),
      body: eventsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_outlined, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'Sin eventos',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea tu primer evento para empezar.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orgEventsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final event = events[index];
                return Card(
                  color: context.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    side: BorderSide(color: context.divider),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
               
                    onTap: () => context.push(AppRoutes.eventDetail, extra: event),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                      child: const Icon(Icons.event, color: AppColors.secondary, size: 20),
                    ),
                    title: Text(
                      event.title,
                      style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${event.startTime.day}/${event.startTime.month}/${event.startTime.year}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: event.isPublished
                            ? AppColors.success.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event.isPublished ? 'Publicado' : 'Borrador',
                        style: TextStyle(
                          color: event.isPublished ? AppColors.success : Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),

      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoutes.eventCreate),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}