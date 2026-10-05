import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_transition.dart';
import '../../../core/utils/display_labels.dart';
import '../../../data/services/admin_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';

class AdminDashboardView extends ConsumerStatefulWidget {
  const AdminDashboardView({super.key});

  @override
  ConsumerState<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends ConsumerState<AdminDashboardView> {
  final _service = const AdminService();
  AdminSection _section = AdminSection.dashboard;
  late Future<List<Map<String, dynamic>>> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _service.fetch(_section);
  }

  void _select(AdminSection section) {
    setState(() {
      _section = section;
      _rows = _service.fetch(section);
    });
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _refresh() async {
    setState(() => _rows = _service.fetch(_section));
    await _rows;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      drawer: wide ? null : Drawer(child: SafeArea(child: _navigation())) ,
      body: Row(
        children: [
          if (wide)
            SizedBox(width: 250, child: _navigation()),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                  child: Text(_section.label,
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _rows,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return AppErrorState(
                          message: friendlyError(snapshot.error ?? ''),
                          onRetry: _refresh,
                        );
                      }
                      final rows = snapshot.data ?? const [];
                      if (_section == AdminSection.dashboard) {
                        return _DashboardSummary(rows: rows, onOpen: _select);
                      }
                      if (rows.isEmpty) {
                        return AppEmptyState(
                          icon: _iconFor(_section),
                          title: 'No hay ${_section.label.toLowerCase()} para mostrar.',
                          message:
                              'Cuando existan registros aparecerán aquí.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _recordCard(rows[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigation() => ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const ListTile(
            leading: Icon(Icons.admin_panel_settings_outlined),
            title: Text('Panel central', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final section in AdminSection.values)
            ListTile(
              selected: _section == section,
              leading: Icon(_iconFor(section)),
              title: Text(section.label),
              onTap: () => _select(section),
            ),
        ],
      );

  Widget _recordCard(Map<String, dynamic> row) {
    final title = _recordTitle(row);
    final detail = _recordDetail(row);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              _statusChip(_status(row)),
            ]),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_section == AdminSection.events) _eventActions(row),
            if (_section == AdminSection.organizations) _organizationActions(row),
            if (_section == AdminSection.memberships && _status(row) == 'pending')
              _membershipActions(row),
            if (_section == AdminSection.payouts &&
                (_status(row) == 'pending' || _status(row) == 'processing'))
              _payoutStatusActions(row),
            if (_section == AdminSection.organizations) _payoutButton(row),
          ],
        ),
      ),
    );
  }

  Widget _eventActions(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final title = row['title']?.toString() ?? 'este evento';
    return Wrap(spacing: 8, runSpacing: 4, children: [
      _action('Aprobar', Icons.check, () => _moderate(id, title, 'approved')),
      _action('Rechazar', Icons.close, () => _moderate(id, title, 'rejected')),
      _action('Suspender', Icons.pause, () => _moderate(id, title, 'suspended')),
      _action('Reactivar', Icons.play_arrow,
          () => _moderate(id, title, 'approved')),
    ]);
  }

  Future<void> _moderate(String id, String title, String status) async {
    if (status == 'approved') {
      final ok = await showAppConfirm(
        context,
        title: 'Aprobar evento',
        message: '¿Aprobar y publicar "$title"? Será visible para el público.',
        confirmLabel: 'Aprobar',
        icon: Icons.verified_outlined,
      );
      if (!ok) return;
      await _run(() => _service.moderateEvent(id, 'approved'));
      return;
    }
    final isReject = status == 'rejected';
    final reason = await showAppPrompt(
      context,
      title: isReject ? 'Rechazar evento' : 'Suspender evento',
      message: isReject
          ? 'Indica el motivo del rechazo de "$title".'
          : 'Indica el motivo de la suspensión de "$title" (opcional).',
      label: 'Motivo',
      isDangerous: true,
      isRequired: isReject,
      confirmLabel: isReject ? 'Rechazar' : 'Suspender',
    );
    if (reason == null) return;
    await _run(() => _service.moderateEvent(id, status, reason: reason));
  }

  Widget _organizationActions(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final active = row['is_active'] == true;
    final name = row['name']?.toString() ?? 'esta organización';
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _setOrganizationActive(id, name, active),
        icon: Icon(
          active ? Icons.pause_circle_outline : Icons.play_circle_outline,
        ),
        label: Text(active ? 'Suspender organización' : 'Activar organización'),
      ),
    );
  }

  Future<void> _setOrganizationActive(
    String id,
    String name,
    bool currentlyActive,
  ) async {
    final ok = await showAppConfirm(
      context,
      title: currentlyActive ? 'Suspender organización' : 'Activar organización',
      message: currentlyActive
          ? '¿Suspender "$name"? No podrá operar mientras esté suspendida.'
          : '¿Activar "$name" nuevamente?',
      confirmLabel: currentlyActive ? 'Suspender' : 'Activar',
      isDangerous: currentlyActive,
    );
    if (!ok) return;
    await _run(() => _service.setOrganizationActive(id, !currentlyActive));
  }

  Widget _membershipActions(Map<String, dynamic> row) {
    final id = row['id'].toString();
    return Wrap(spacing: 8, children: [
      _action('Verificar y activar', Icons.verified,
          () => _verifyMembership(id, true)),
      _action('Rechazar', Icons.cancel_outlined,
          () => _verifyMembership(id, false)),
    ]);
  }

  Future<void> _verifyMembership(String id, bool approve) async {
    final ok = await showAppConfirm(
      context,
      title: approve ? 'Activar membresía' : 'Rechazar membresía',
      message: approve
          ? '¿Confirmas que el pago fue verificado y activas la membresía?'
          : '¿Rechazar esta solicitud de membresía?',
      confirmLabel: approve ? 'Activar' : 'Rechazar',
      isDangerous: !approve,
      icon: approve ? Icons.verified_outlined : Icons.cancel_outlined,
    );
    if (!ok) return;
    await _run(() => _service.verifyMembership(id, approve));
  }

  Widget _payoutStatusActions(Map<String, dynamic> row) {
    final id = row['id'].toString();
    return Wrap(spacing: 8, children: [
      _action('Marcar liquidada', Icons.check_circle_outline,
          () => _setPayoutStatus(id, 'paid')),
      _action('Marcar fallida', Icons.error_outline,
          () => _setPayoutStatus(id, 'failed')),
    ]);
  }

  Future<void> _setPayoutStatus(String id, String status) async {
    final isPaid = status == 'paid';
    final ok = await showAppConfirm(
      context,
      title: isPaid
          ? 'Marcar liquidación como pagada'
          : 'Marcar liquidación como fallida',
      message: isPaid
          ? '¿Confirmas que la liquidación fue pagada?'
          : '¿Marcar esta liquidación como fallida?',
      confirmLabel: 'Confirmar',
      isDangerous: !isPaid,
    );
    if (!ok) return;
    await _run(() => _service.setPayoutStatus(id, status));
  }

  Widget _payoutButton(Map<String, dynamic> row) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _registerPayout(row),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Registrar liquidación'),
        ),
      );

  Widget _action(String label, IconData icon, VoidCallback onPressed) =>
      OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 17), label: Text(label));

  Future<void> _registerPayout(Map<String, dynamic> organization) async {
    final name = organization['name']?.toString() ?? 'la organización';
    final amountText = await showAppPrompt(
      context,
      title: 'Registrar liquidación',
      message: 'Monto a liquidar a $name.',
      label: 'Monto en BOB',
      confirmLabel: 'Continuar',
    );
    if (amountText == null) return;
    if (!mounted) return;
    final amount = double.tryParse(amountText.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      AppFeedback.warning(context, 'Ingresa un monto válido.');
      return;
    }
    final reference = await showAppPrompt(
      context,
      title: 'Referencia de liquidación',
      message: 'Número de comprobante o referencia del pago (opcional).',
      label: 'Referencia',
      confirmLabel: 'Continuar',
    );
    if (reference == null || !mounted) return;
    final ok = await showAppConfirm(
      context,
      title: 'Confirmar liquidación',
      message: 'Se registrará una liquidación de $amount BOB a $name.',
      confirmLabel: 'Registrar',
      icon: Icons.payments_outlined,
    );
    if (!ok) return;
    await _run(() => _service.registerPayout(
          organizationId: organization['id'].toString(),
          amount: amount,
          reference: reference,
        ));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _refresh();
      if (mounted) AppFeedback.success(context, 'Cambios guardados.');
    } catch (error) {
      if (mounted) AppFeedback.error(context, friendlyError(error));
    }
  }

  String _recordTitle(Map<String, dynamic> row) {
    for (final key in ['title', 'name', 'order_number', 'action', 'payment_type']) {
      final value = row[key]?.toString();
      if (value != null && value.isNotEmpty) {
        if (key == 'action') return DisplayLabels.action(value);
        if (key == 'payment_type') return DisplayLabels.paymentType(value);
        return value;
      }
    }
    final amount = row['amount'] ?? row['total_amount'];
    if (amount != null) return '$amount ${row['currency'] ?? 'BOB'}';
    return row['id']?.toString() ?? 'Registro';
  }

  String _recordDetail(Map<String, dynamic> row) {
    final related = row['organizations'] ?? row['events'] ?? row['profiles'];
    final name = related is Map ? related['name'] ?? related['title'] ?? related['first_name'] : null;
    final values = <String>[
      if (name != null) name.toString(),
      if (row['payment_type'] != null) 'Tipo: ${DisplayLabels.paymentType(row['payment_type'])}',
      if (row['provider'] != null) 'Proveedor: ${DisplayLabels.provider(row['provider'])}',
      if (row['platform_fee'] != null) 'Comisión: ${row['platform_fee']} ${row['currency'] ?? ''}',
      if (row['subtotal'] != null && row['platform_fee'] != null)
        'Organizador: ${((row['subtotal'] as num) - (row['platform_fee'] as num)).toStringAsFixed(2)} ${row['currency'] ?? ''}',
      if (row['created_at'] != null) row['created_at'].toString().split('T').first,
      if (row['moderation_reason'] != null) 'Motivo: ${row['moderation_reason']}',
    ];
    return values.join(' · ');
  }

  String _status(Map<String, dynamic> row) {
    final moderationStatus = row['moderation_status'];
    if (moderationStatus != null) return moderationStatus.toString();
    final status = row['status'];
    if (status != null) return status.toString();
    final isActive = row['is_active'];
    if (isActive is bool) return isActive ? 'active' : 'inactive';
    return '';
  }

  Widget _statusChip(String status) => Chip(
        label: Text(DisplayLabels.status(status, fallback: '—')),
        visualDensity: VisualDensity.compact,
      );

  IconData _iconFor(AdminSection section) => switch (section) {
        AdminSection.dashboard => Icons.dashboard_outlined,
        AdminSection.users => Icons.people_outline,
        AdminSection.organizations => Icons.apartment_outlined,
        AdminSection.events => Icons.event_outlined,
        AdminSection.categories => Icons.category_outlined,
        AdminSection.classes => Icons.school_outlined,
        AdminSection.memberships => Icons.card_membership_outlined,
        AdminSection.payments || AdminSection.publicationPayments || AdminSection.classPublicationPayments => Icons.payments_outlined,
        AdminSection.sales => Icons.shopping_bag_outlined,
        AdminSection.payouts => Icons.account_balance_outlined,
        AdminSection.audit => Icons.history,
      };
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({required this.rows, required this.onOpen});
  final List<Map<String, dynamic>> rows;
  final ValueChanged<AdminSection> onOpen;

  @override
  Widget build(BuildContext context) {
    final pending = rows.where((row) => row['moderation_status'] == 'pending_approval').length;
    final approved = rows.where((row) => row['moderation_status'] == 'approved').length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Vista general', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _SummaryCard(label: 'Eventos pendientes', value: '$pending', icon: Icons.hourglass_top, onTap: () => onOpen(AdminSection.events)),
          _SummaryCard(label: 'Eventos aprobados', value: '$approved', icon: Icons.verified_outlined, onTap: () => onOpen(AdminSection.events)),
          _SummaryCard(label: 'Organizaciones', value: 'Ver', icon: Icons.apartment, onTap: () => onOpen(AdminSection.organizations)),
          _SummaryCard(label: 'Finanzas', value: 'Consultar', icon: Icons.payments_outlined, onTap: () => onOpen(AdminSection.payments)),
        ]),
        const SizedBox(height: 24),
        Text('Revisión reciente', style: Theme.of(context).textTheme.titleMedium),
        for (final row in rows.take(8))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_note_outlined),
            title: Text(row['title']?.toString() ?? 'Evento'),
            subtitle: Text(DisplayLabels.status(row['moderation_status'], fallback: 'Sin moderación')),
            onTap: () => onOpen(AdminSection.events),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                Text(label),
              ]),
            ),
          ),
        ),
      );
}

