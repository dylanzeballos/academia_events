// lib/features/events/views/event_access_points_view.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/display_labels.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/services/event_access_service.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';

class EventAccessPointsView extends StatefulWidget {
  const EventAccessPointsView({
    super.key,
    required this.eventId,
    required this.organizationId,
    required this.eventTitle,
  });

  final String eventId;
  final String organizationId;
  final String eventTitle;

  @override
  State<EventAccessPointsView> createState() => _EventAccessPointsViewState();
}

class _EventAccessPointsViewState extends State<EventAccessPointsView> {
  final _service = const EventAccessService();
  late Future<List<Map<String, dynamic>>> _points;

  @override
  void initState() {
    super.initState();
    _points = _service.fetchPoints(widget.eventId);
  }

  Future<void> _reload() async {
    setState(() => _points = _service.fetchPoints(widget.eventId));
    await _points;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: context.cardBg,
          elevation: 0,
          title: Text(
            'Accesos · ${widget.eventTitle}',
            style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('fab_crear_acceso'),
          onPressed: () => _editPoint(),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: AppColors.onPrimary),
          label: const Text('Crear acceso', style: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.bold)),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _points,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snapshot.hasError) {
              return AppErrorState(
                message: friendlyError(snapshot.error ?? ''),
                onRetry: _reload,
              );
            }
            final points = snapshot.data ?? const [];
            if (points.isEmpty) {
              return const AppEmptyState(
                icon: Icons.meeting_room_outlined,
                title: 'Sin accesos',
                message:
                    'Este evento aún no tiene puntos de acceso. Crea el primero con el botón +.',
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _reload,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: points.length,
                itemBuilder: (context, index) => _accessCard(points[index]),
              ),
            );
          },
        ),
      );

  Widget _accessCard(Map<String, dynamic> point) {
    final staff = (point['event_access_point_staff'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final active = point['is_active'] == true;
    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        iconColor: AppColors.primary,
        collapsedIconColor: context.textMuted,
        leading: Icon(
          active ? Icons.meeting_room_outlined : Icons.do_not_disturb_on_outlined,
          color: active ? AppColors.success : AppColors.error,
        ),
        title: Text(
          point['name']?.toString() ?? 'Acceso',
          style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${active ? 'Activo' : 'Inactivo'} · ${staff.length} miembros asignados',
          style: TextStyle(color: context.textMuted, fontSize: 13),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: context.textMuted),
          color: context.cardBg,
          onSelected: (action) {
            if (action == 'edit') _editPoint(point);
            if (action == 'toggle') _togglePoint(point, active);
            if (action == 'staff') _assignStaff(point);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text('Editar', style: TextStyle(color: context.textOnBg))),
            PopupMenuItem(value: 'toggle', child: Text(active ? 'Desactivar' : 'Activar', style: TextStyle(color: context.textOnBg))),
            PopupMenuItem(value: 'staff', child: Text('Asignar miembros', style: TextStyle(color: context.textOnBg))),
          ],
        ),
        children: [
          if ((point['description'] as String?)?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  point['description'].toString(),
                  style: TextStyle(color: context.textMuted, fontSize: 13),
                ),
              ),
            ),
          if (staff.isEmpty)
            ListTile(title: Text('Sin miembros asignados', style: TextStyle(color: context.textMuted)))
          else
            for (final entry in staff)
              ListTile(
                dense: true,
                leading: Icon(Icons.person_outline, color: context.textMuted),
                title: Text(_memberName(entry['organization_members'] as Map?), style: TextStyle(color: context.textOnBg)),
                trailing: IconButton(
                  tooltip: 'Quitar del acceso',
                  icon: const Icon(Icons.person_remove_outlined, color: AppColors.error),
                  onPressed: () => _removeStaff(point, entry),
                ),
              ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _assignStaff(point),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Asignar staff'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPoint([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: existing?['name']?.toString());
    final description = TextEditingController(text: existing?['description']?.toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(existing == null ? 'Crear acceso' : 'Editar acceso', style: TextStyle(color: context.textOnBg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              maxLength: 100,
              style: TextStyle(color: context.textOnBg),
              decoration: InputDecoration(
                labelText: 'Nombre',
                labelStyle: TextStyle(color: context.textMuted),
              ),
            ),
            TextField(
              controller: description,
              style: TextStyle(color: context.textOnBg),
              decoration: InputDecoration(
                labelText: 'Descripción (opcional)',
                labelStyle: TextStyle(color: context.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: TextStyle(color: context.textMuted))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == true && name.text.trim().isNotEmpty) {
      await _run(() => _service.savePoint(
            id: existing?['id']?.toString(),
            eventId: widget.eventId,
            name: name.text,
            description: description.text,
          ));
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _assignStaff(Map<String, dynamic> point) async {
    try {
      final members = await _service.fetchOrganizationMembers(widget.organizationId);
      final current = ((point['event_access_point_staff'] as List? ?? const [])
              .cast<Map<String, dynamic>>())
          .map((row) => row['organization_member_id'].toString())
          .toSet();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: context.cardBg,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLarge)),
        ),
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Staff autorizado · ${point['name']}',
                  style: TextStyle(color: context.textOnBg, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final member in members)
                  CheckboxListTile(
                    activeColor: AppColors.primary,
                    value: current.contains(member['id'].toString()),
                    title: Text(_memberName(member), style: TextStyle(color: context.textOnBg)),
                    subtitle: Text(DisplayLabels.role(member['role']), style: TextStyle(color: context.textMuted)),
                    onChanged: (selected) async {
                      final memberId = member['id'].toString();
                      await _service.setMemberAssigned(point['id'].toString(), memberId, selected == true);
                      if (selected == true) {
                        current.add(memberId);
                      } else {
                        current.remove(memberId);
                      }
                      setSheetState(() {});
                      await _reload();
                    },
                  ),
              ],
            ),
          ),
        ),
      );
      await _reload();
    } catch (_) {
      if (mounted) {
        AppFeedback.error(
          context,
          'No se pudo asignar el personal. Inténtalo de nuevo.',
        );
      }
    }
  }

  Future<void> _togglePoint(Map<String, dynamic> point, bool active) async {
    final name = point['name']?.toString() ?? 'este acceso';
    final ok = await showAppConfirm(
      context,
      title: active ? 'Desactivar acceso' : 'Activar acceso',
      message: active
          ? '¿Desactivar "$name"? El personal no podrá usarlo.'
          : '¿Activar "$name" nuevamente?',
      confirmLabel: active ? 'Desactivar' : 'Activar',
      isDangerous: active,
    );
    if (!ok) return;
    await _run(() => _service.setActive(point['id'].toString(), !active));
  }

  Future<void> _removeStaff(
    Map<String, dynamic> point,
    Map<String, dynamic> entry,
  ) async {
    final memberName = _memberName(entry['organization_members'] as Map?);
    final ok = await showAppConfirm(
      context,
      title: 'Quitar del acceso',
      message: '¿Quitar a $memberName de este acceso?',
      confirmLabel: 'Quitar',
      isDangerous: true,
    );
    if (!ok) return;
    await _run(
      () => _service.setMemberAssigned(
        point['id'].toString(),
        entry['organization_member_id'].toString(),
        false,
      ),
    );
  }

  String _memberName(Map? member) {
    final profile = member?['profiles'];
    final first = profile is Map ? profile['first_name']?.toString() ?? '' : '';
    final last = profile is Map ? profile['last_name']?.toString() ?? '' : '';
    return '$first $last'.trim().isEmpty ? 'Miembro' : '$first $last'.trim();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _reload();
      if (mounted) AppFeedback.success(context, 'Cambios guardados.');
    } catch (error) {
      if (mounted) AppFeedback.error(context, friendlyError(error));
    }
  }
}