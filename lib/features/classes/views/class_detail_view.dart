import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/dance_class_session_model.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/loading_indicator.dart';

class ClassDetailView extends ConsumerStatefulWidget {
  const ClassDetailView({super.key});

  @override
  ConsumerState<ClassDetailView> createState() => _ClassDetailViewState();
}

class _ClassDetailViewState extends ConsumerState<ClassDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classAsync = ref.watch(selectedClassProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageClasses ?? false;

    return classAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (danceClass) {
        if (danceClass == null) {
          return const Scaffold(body: Center(child: Text('Clase no encontrada')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(danceClass.title),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'INFO'),
                Tab(text: 'HORARIOS'),
                Tab(text: 'SESIONES'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _InfoTab(danceClass: danceClass, canManage: canManage),
              const _SchedulesTab(),
              const _SessionsTab(),
            ],
          ),
        );
      },
    );
  }
}

class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.danceClass, required this.canManage});

  final dynamic danceClass;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: danceClass.coverImageUrl != null
                  ? NetworkImage(danceClass.coverImageUrl!)
                  : null,
              child: danceClass.coverImageUrl == null
                  ? Text(
                      danceClass.title.isNotEmpty ? danceClass.title[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          _InfoRow(label: 'Nombre', value: danceClass.title),
          if (danceClass.description != null && danceClass.description!.isNotEmpty)
            _InfoRow(label: 'Descripción', value: danceClass.description!),
          if (danceClass.instructorName != null)
            _InfoRow(label: 'Instructor', value: danceClass.instructorName!),
          if (danceClass.capacity != null)
            _InfoRow(label: 'Cupos', value: '${danceClass.capacity}'),
          _InfoRow(
            label: 'Precio',
            value: '${danceClass.price} ${danceClass.currency}',
          ),
          _InfoRow(
            label: 'Estado',
            value: danceClass.isPublished ? 'Publicada' : 'Borrador',
          ),
          if (danceClass.startTime != null)
            _InfoRow(
              label: 'Inicio',
              value: '${danceClass.startTime!.day}/${danceClass.startTime!.month}/${danceClass.startTime!.year}',
            ),
          if (danceClass.endTime != null)
            _InfoRow(
              label: 'Fin',
              value: '${danceClass.endTime!.day}/${danceClass.endTime!.month}/${danceClass.endTime!.year}',
            ),
          if (canManage) ...[
            const SizedBox(height: 24),
            AppButton(
              label: danceClass.isPublished ? 'Despublicar' : 'Publicar',
              onPressed: () async {
                final repo = ref.read(danceClassRepositoryProvider);
                final newStatus = danceClass.isPublished ? 'draft' : 'published';
                await repo.updateClass(danceClass.id, {'status': newStatus});
                ref.invalidate(selectedClassProvider);
                ref.invalidate(orgClassesProvider);
              },
              isOutlined: true,
              icon: danceClass.isPublished ? Icons.unpublished_outlined : Icons.publish,
            ),
          ],
        ],
      ),
    );
  }
}

class _SchedulesTab extends ConsumerWidget {
  const _SchedulesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(classSchedulesProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageSchedules ?? false;

    return schedulesAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (schedules) {
        if (schedules.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_outlined, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 12),
                const Text(
                  'Sin horarios definidos',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: schedules.length,
          itemBuilder: (context, index) {
            final s = schedules[index];
            return Card(
              color: context.cardBg,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                side: BorderSide(color: context.divider),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    s.dayName.substring(0, 2),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                title: Text(
                  s.dayName,
                  style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${s.startTime} - ${s.endTime}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                trailing: canManage
                    ? PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                        onSelected: (value) async {
                          final repo = ref.read(danceClassRepositoryProvider);
                          if (value == 'toggle') {
                            await repo.updateSchedule(s.id, {'is_active': !s.isActive});
                            ref.invalidate(classSchedulesProvider);
                          } else if (value == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Eliminar horario'),
                                content: Text('¿Eliminar ${s.dayName} ${s.startTime}-${s.endTime}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await repo.deleteSchedule(s.id);
                              ref.invalidate(classSchedulesProvider);
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(s.isActive ? 'Desactivar' : 'Activar'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

class _SessionsTab extends ConsumerWidget {
  const _SessionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(classSessionsProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canCancelSession ?? false;

    return sessionsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (sessions) {
        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 12),
                const Text(
                  'Sin sesiones generadas',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Genera sesiones desde la pestaña de horarios.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) => _SessionTile(
            session: sessions[index],
            canManage: canManage,
          ),
        );
      },
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session, required this.canManage});

  final DanceClassSessionModel session;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = '${session.sessionDate.day.toString().padLeft(2, '0')}/${session.sessionDate.month.toString().padLeft(2, '0')}/${session.sessionDate.year}';
    final startStr = '${session.startAt.hour.toString().padLeft(2, '0')}:${session.startAt.minute.toString().padLeft(2, '0')}';
    final endStr = '${session.endAt.hour.toString().padLeft(2, '0')}:${session.endAt.minute.toString().padLeft(2, '0')}';

    Color statusColor;
    switch (session.status) {
      case 'scheduled':
        statusColor = AppColors.primary;
        break;
      case 'completed':
        statusColor = AppColors.success;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      color: context.cardBg,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(
            session.isCompleted
                ? Icons.check
                : session.isCancelled
                    ? Icons.close
                    : Icons.calendar_today,
            color: statusColor,
            size: 18,
          ),
        ),
        title: Text(
          dateStr,
          style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '$startStr - $endStr',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        trailing: canManage && session.isScheduled
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                onSelected: (value) async {
                  final repo = ref.read(danceClassRepositoryProvider);
                  if (value == 'complete') {
                    await repo.completeSession(session.id);
                    ref.invalidate(classSessionsProvider);
                  } else if (value == 'cancel') {
                    final reasonCtrl = TextEditingController();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Cancelar sesión'),
                        content: TextField(
                          controller: reasonCtrl,
                          decoration: const InputDecoration(hintText: 'Razón (opcional)'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Cancelar', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await repo.cancelSession(
                        sessionId: session.id,
                        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                      );
                      ref.invalidate(classSessionsProvider);
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'complete', child: Text('Marcar completada')),
                  const PopupMenuItem(value: 'cancel', child: Text('Cancelar', style: TextStyle(color: AppColors.error))),
                ],
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  session.statusDisplayName,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: context.textOnBg, fontSize: 15)),
        ],
      ),
    );
  }
}
