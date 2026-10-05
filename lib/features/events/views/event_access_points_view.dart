import 'package:flutter/material.dart';

import '../../../core/utils/display_labels.dart';
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
        appBar: AppBar(title: Text('Accesos · ${widget.eventTitle}')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editPoint(),
          icon: const Icon(Icons.add),
          label: const Text('Crear acceso'),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _points,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(active ? Icons.meeting_room_outlined : Icons.do_not_disturb_on_outlined),
        title: Text(point['name']?.toString() ?? 'Acceso'),
        subtitle: Text('${active ? 'Activo' : 'Inactivo'} · ${staff.length} miembros asignados'),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') _editPoint(point);
            if (action == 'toggle') _togglePoint(point, active);
            if (action == 'staff') _assignStaff(point);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'toggle', child: Text(active ? 'Desactivar' : 'Activar')),
            const PopupMenuItem(value: 'staff', child: Text('Asignar miembros')),
          ],
        ),
        children: [
          if ((point['description'] as String?)?.isNotEmpty == true)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(point['description'].toString())),
          if (staff.isEmpty)
            const ListTile(title: Text('Sin miembros asignados'))
          else
            for (final entry in staff)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_outline),
                title: Text(_memberName(entry['organization_members'] as Map?)),
                trailing: IconButton(
                  tooltip: 'Quitar del acceso',
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: () => _removeStaff(point, entry),
                ),
              ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _assignStaff(point),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Asignar staff'),
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
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Crear acceso' : 'Editar acceso'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, maxLength: 100, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Descripción (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
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
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text('Staff autorizado · ${point['name']}', style: Theme.of(context).textTheme.titleLarge),
              for (final member in members)
                CheckboxListTile(
                  value: current.contains(member['id'].toString()),
                  title: Text(_memberName(member)),
                  subtitle: Text(DisplayLabels.role(member['role'])),
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
