// lib/features/academy/views/academy_events_view.dart
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
import '../../events/views/event_attendance_view.dart';
import 'academy_archived_events_view.dart';

class AcademyEventsView extends ConsumerWidget {
  const AcademyEventsView({super.key});

  Future<void> _navigateToCreate(BuildContext context, WidgetRef ref) async {
    final result = await context.push<bool>(AppRoutes.eventCreate);
    if (result == true || context.mounted) {
      ref.invalidate(orgEventsProvider);
    }
  }

  Future<void> _navigateToDetail(BuildContext context, WidgetRef ref, String eventId) async {
    final result = await context.push<bool>('${AppRoutes.eventDetail}/$eventId');
    if (result == true || context.mounted) {
      ref.invalidate(orgEventsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(orgEventsProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageClasses ?? false;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          'Eventos',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Eventos Concluidos',
            icon: Icon(Icons.history_rounded, color: context.textOnBg, size: 24),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AcademyArchivedEventsView(),
                ),
              );
            },
          ),
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
          // Filtrar solo los activos (la fecha de fin aún no expiró)
          final activeEvents = allEvents.where((e) => !e.endTime.isBefore(now)).toList();

          // El último creado de primero
          activeEvents.sort((a, b) {
            final aCreated = a.createdAt ?? a.startTime;
            final bCreated = b.createdAt ?? b.startTime;
            return bCreated.compareTo(aCreated);
          });

          if (activeEvents.isEmpty) {
            return AppEmptyState(
              icon: Icons.event_available_outlined,
              title: 'Sin eventos activos',
              message: canManage
                  ? 'Organiza y publica tu primer evento.'
                  : 'No hay eventos disponibles por el momento.',
              actionLabel: canManage ? 'Crear evento' : null,
              onAction: canManage ? () => _navigateToCreate(context, ref) : null,
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(orgEventsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: activeEvents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final event = activeEvents[index];
                return AcademyEventCardItem(
                  event: event,
                  isArchived: false,
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

class AcademyEventCardItem extends StatelessWidget {
  const AcademyEventCardItem({
    super.key,
    required this.event,
    required this.onTap,
    this.isArchived = false,
  });

  final EventModel event;
  final VoidCallback onTap;
  final bool isArchived;

  String _formatDate(DateTime dt) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.divider.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner con Badges flotantes
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 8,
                      child: hasCover
                          ? Image.network(
                              event.coverImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _fallbackBanner(context),
                            )
                          : _fallbackBanner(context),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (event.categoryName != null && event.categoryName!.isNotEmpty)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.label_outline_rounded, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                event.categoryName!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isArchived
                              ? Colors.black87
                              : (event.isPublished ? AppColors.success : Colors.grey.shade800),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isArchived
                              ? 'Concluido'
                              : (event.isPublished ? 'Publicado' : 'Borrador'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isArchived ? Colors.grey.shade700 : AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(event.startTime),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido con detalles y botón de asistencia
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isArchived ? context.textMuted : context.textOnBg,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (event.capacity != null) ...[
                          Icon(Icons.people_outline_rounded, size: 14, color: context.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${event.capacity} cupos',
                            style: TextStyle(color: context.textMuted, fontSize: 12),
                          ),
                          const SizedBox(width: 14),
                        ],
                        if (event.startingPrice != null) ...[
                          Icon(Icons.confirmation_number_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            event.startingPrice == 0
                                ? 'Gratuito'
                                : 'Desde ${event.startingPrice!.toStringAsFixed(0)} Bs.',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EventAttendanceView(
                                eventId: event.id,
                                eventTitle: event.title,
                              ),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.assessment_outlined, size: 16),
                          label: const Text('Ver asistencia', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackBanner(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_rounded, size: 36, color: AppColors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 4),
            Text(
              event.title.isNotEmpty ? event.title : 'Evento',
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}