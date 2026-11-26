import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:academia_events/core/theme/app_colors.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_transition.dart';
import '../../../core/utils/display_labels.dart';
import '../../../core/utils/public_urls.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../data/services/admin_service.dart';
import '../../../data/services/pagosya_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../widgets/event_category_dialog.dart';
import '../widgets/publication_qr_dialog.dart';
import 'pagosya_admin_view.dart';

class AdminDashboardView extends ConsumerStatefulWidget {
  const AdminDashboardView({super.key});

  @override
  ConsumerState<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends ConsumerState<AdminDashboardView> {
  static const _pageSize = 25;

  final _service = const AdminService();
  final _scrollController = ScrollController();
  AdminSection _section = AdminSection.dashboard;
  late Future<AdminSectionPage> _pageFuture;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageFuture = _fetchPage(_section, 0);
  }

  Future<AdminSectionPage> _fetchPage(AdminSection section, int page) {
    if (section == AdminSection.pagosya) {
      return Future.value(AdminSectionPage.empty);
    }
    return _service.fetch(section, limit: _pageSize, offset: page * _pageSize);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _select(AdminSection section) {
    setState(() {
      _section = section;
      _page = 0;
      _pageFuture = _fetchPage(section, 0);
    });
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  void _changePage(int page) {
    setState(() {
      _page = page;
      _pageFuture = _fetchPage(_section, page);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _refresh() async {
    if (_section == AdminSection.pagosya) {
      setState(() => _pageFuture = Future.value(AdminSectionPage.empty));
      return;
    }
    setState(() => _pageFuture = _fetchPage(_section, _page));
    try {
      await _pageFuture;
    } catch (error) {
      // El FutureBuilder muestra el error; solo lo registramos para depurar.
      debugPrint('[ADMIN ${_section.name}] refresh: $error');
    }
  }

  Future<void> _signOut() async {
    final ok = await showAppConfirm(
      context,
      title: 'Cerrar sesión',
      message: '¿Querés salir del panel de administración?',
      confirmLabel: 'Cerrar sesión',
      isDangerous: true,
      icon: Icons.logout_rounded,
    );
    if (!ok) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1000;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        actions: [
          const ThemeToggleButton(),
          if (_section != AdminSection.pagosya)
            IconButton(
              tooltip: 'Actualizar datos',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      drawer: wide ? null : Drawer(child: SafeArea(child: _navigation())),
      body: Row(
        children: [
          if (wide)
            Container(
              width: 272,
              decoration: BoxDecoration(
                color: context.surfaceHeader,
                border: Border(right: BorderSide(color: context.divider)),
              ),
              child: SafeArea(child: _navigation()),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(),
                Expanded(
                  child: _section == AdminSection.pagosya
                      ? const PagosyaAdminView()
                      : FutureBuilder<AdminSectionPage>(
                          future: _pageFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const _AdminListSkeleton();
                            }
                            if (snapshot.hasError) {
                              return AppErrorState(
                                message: friendlyError(snapshot.error ?? ''),
                                onRetry: _refresh,
                              );
                            }
                            final data =
                                snapshot.data ?? AdminSectionPage.empty;
                            if (_section == AdminSection.dashboard) {
                              return _DashboardSummary(
                                rows: data.items,
                                totalEvents: data.total,
                                pendingEvents:
                                    data.counts['pending_approval'] ??
                                    data.items
                                        .where(
                                          (row) =>
                                              row['moderation_status'] ==
                                              'pending_approval',
                                        )
                                        .length,
                                approvedEvents:
                                    data.counts['approved'] ??
                                    data.items
                                        .where(
                                          (row) =>
                                              row['moderation_status'] ==
                                              'approved',
                                        )
                                        .length,
                                onOpen: _select,
                                onRefresh: _refresh,
                              );
                            }
                            if (data.total == 0) {
                              return RefreshIndicator(
                                color: AppColors.primary,
                                onRefresh: _refresh,
                                child: ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(top: 48),
                                  children: [
                                    AppEmptyState(
                                      icon: _iconFor(_section),
                                      title:
                                          'No hay ${_section.label.toLowerCase()} para mostrar.',
                                      message: 'Cuando existan registros aparecerán aquí.',
                                    ),
                                  ],
                                ),
                              );
                            }
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final horizontal = constraints.maxWidth > 1080
                                    ? (constraints.maxWidth - 1000) / 2
                                    : 24.0;
                                final totalPages = data.total <= _pageSize
                                    ? 1
                                    : (data.total + _pageSize - 1) ~/ _pageSize;
                                var pageNumber = data.offset ~/ _pageSize;
                                if (pageNumber >= totalPages) {
                                  pageNumber = totalPages - 1;
                                }
                                final pageRows = data.items;
                                final start = pageRows.isEmpty
                                    ? 0
                                    : data.offset + 1;
                                final end = data.offset + pageRows.length;
                                final showFooter = totalPages > 1;

                                return RefreshIndicator(
                                  color: AppColors.primary,
                                  onRefresh: _refresh,
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      horizontal,
                                      8,
                                      horizontal,
                                      32,
                                    ),
                                    itemCount:
                                        pageRows.length + (showFooter ? 1 : 0),
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      if (index == pageRows.length) {
                                        return _paginationFooter(
                                          page: pageNumber,
                                          totalPages: totalPages,
                                          start: start,
                                          end: end,
                                          total: data.total,
                                        );
                                      }
                                      return _recordCard(pageRows[index]);
                                    },
                                  ),
                                );
                              },
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

  Widget _sectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final action = _section == AdminSection.categories
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _openCategoryForm,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva categoría'),
                )
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _section.label,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (!compact && action != null) ...[
                    const SizedBox(width: 12),
                    action,
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _sectionDescription(_section),
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (compact && action != null) ...[
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: action),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _paginationFooter({
    required int page,
    required int totalPages,
    required int start,
    required int end,
    required int total,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            label: 'Mostrando registros ${start + 1} a $end de $total',
            child: Text(
              'Mostrando ${start + 1}–$end de $total',
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: page > 0 ? () => _changePage(page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Anterior'),
              ),
              Text(
                'Página ${page + 1} de $totalPages',
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: page < totalPages - 1
                    ? () => _changePage(page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                label: const Text('Siguiente'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navigation() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panel central',
                      style: TextStyle(
                        color: context.textOnBg,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Administración de plataforma',
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final group in _navGroups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
            child: Text(
              group.label,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final section in group.sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: ListTile(
                dense: true,
                selected: _section == section,
                selectedTileColor: AppColors.primary.withValues(alpha: 0.10),
                selectedColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                minLeadingWidth: 22,
                leading: Icon(_iconFor(section), size: 20),
                title: Text(
                  section.label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: _section == section
                    ? const Icon(Icons.chevron_right_rounded, size: 18)
                    : null,
                onTap: () => _select(section),
              ),
            ),
        ],
      ],
    );
  }

  Widget _recordCard(Map<String, dynamic> row) {
    final title = _recordTitle(row);
    final detail = _recordDetail(row);
    final status = _readStatus(row);
    final hasStatus = status.isNotEmpty;
    final statusLabel = hasStatus ? _recordStatusLabel(status) : '';
    final hasActions = _hasActions(row);
    final semantics = [
      title,
      if (hasStatus) statusLabel,
      if (detail.isNotEmpty) detail,
    ].join('. ');

    return Semantics(
      container: true,
      label: semantics,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: context.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_section == AdminSection.organizations) ...[
                  _OrganizationLogo(
                    logoUrl: _text(row['logo_url']),
                    name: title,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
                if (hasStatus) ...[
                  const SizedBox(width: 12),
                  AppStatusChip(
                    label: statusLabel,
                    color: _statusColor(context, status),
                  ),
                ],
              ],
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                detail,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
            if (hasActions) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: context.divider),
              const SizedBox(height: 10),
              if (_section == AdminSection.events) _eventActions(row),
              if (_section == AdminSection.categories) _categoryActions(row),
              if (_section == AdminSection.organizations)
                _organizationActions(row),
              if (_section == AdminSection.memberships &&
                  _isPendingMembership(status))
                _membershipActions(row),
              if (_section == AdminSection.payouts &&
                  (status == 'pending' || status == 'processing'))
                _payoutStatusActions(row),
              if (_section == AdminSection.organizations) _payoutButton(row),
            ],
          ],
        ),
      ),
    );
  }

  bool _isPendingMembership(String status) =>
      status == 'pending' || status == 'past_due';

  String _recordStatusLabel(String status) {
    if (_section == AdminSection.users) {
      if (status == 'active') return 'Activo';
      if (status == 'inactive') return 'Inactivo';
    }
    return DisplayLabels.status(status, fallback: 'Sin estado');
  }

  bool _hasActions(Map<String, dynamic> row) {
    final status = _readStatus(row);
    return switch (_section) {
      AdminSection.events || AdminSection.organizations => true,
      AdminSection.categories => true,
      AdminSection.memberships => _isPendingMembership(status),
      AdminSection.payouts => status == 'pending' || status == 'processing',
      _ => false,
    };
  }

  Widget _eventActions(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final title = row['title']?.toString() ?? 'este evento';
    final status = _readStatus(row);
    final isPending = status == 'pending_approval' || status == 'pending';
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';
    final isSuspended = status == 'suspended';

    final actions =
        <String, ({String label, IconData icon, VoidCallback onTap})>{
          'approve': (
            label: isPending ? 'Aprobar y publicar' : 'Aprobar',
            icon: Icons.check,
            onTap: () => _moderate(id, title, 'approved'),
          ),
          'reactivate': (
            label: 'Reactivar',
            icon: Icons.play_arrow,
            onTap: () => _moderate(id, title, 'approved'),
          ),
          'reject': (
            label: 'Rechazar',
            icon: Icons.close,
            onTap: () => _moderate(id, title, 'rejected'),
          ),
          'suspend': (
            label: 'Suspender',
            icon: Icons.pause,
            onTap: () => _moderate(id, title, 'suspended'),
          ),
          'qr': (
            label: 'QR publicación',
            icon: Icons.qr_code_2,
            onTap: () => _generatePublication('event_publication', id, title),
          ),
        };

    final primaryKey = isPending
        ? 'approve'
        : isApproved
        ? 'qr'
        : (isRejected || isSuspended)
        ? 'reactivate'
        : 'approve';
    final secondaryKey = isPending
        ? 'reject'
        : isApproved
        ? 'suspend'
        : null;

    final primary = actions[primaryKey]!;
    final secondary = secondaryKey == null ? null : actions[secondaryKey]!;

    final available = <String>[
      if (!isApproved && !isRejected && !isSuspended) 'approve',
      if (isRejected || isSuspended) 'reactivate',
      if (!isRejected) 'reject',
      if (isApproved || isPending) 'suspend',
      'qr',
    ];
    final menuKeys = available
        .where((key) => key != primaryKey && key != secondaryKey)
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: primary.onTap,
          icon: Icon(primary.icon, size: 18),
          label: Text(primary.label),
        ),
        if (secondary != null)
          _action(secondary.label, secondary.icon, secondary.onTap),
        if (menuKeys.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: 'Más acciones del evento',
            onSelected: (key) => actions[key]!.onTap(),
            itemBuilder: (context) => [
              for (final key in menuKeys)
                PopupMenuItem(
                  value: key,
                  child: Row(
                    children: [
                      Icon(actions[key]!.icon, size: 20),
                      const SizedBox(width: 12),
                      Text(actions[key]!.label),
                    ],
                  ),
                ),
            ],
            icon: const Icon(Icons.more_horiz_rounded),
          ),
      ],
    );
  }

  Widget _categoryActions(Map<String, dynamic> row) {
    final active = row['is_active'] != false;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _action('Editar', Icons.edit_outlined, () => _openCategoryForm(row)),
        _action(
          active ? 'Desactivar' : 'Activar',
          active ? Icons.pause_circle_outline : Icons.play_circle_outline,
          () => _toggleCategory(row),
        ),
      ],
    );
  }

  Future<void> _openCategoryForm([Map<String, dynamic>? category]) async {
    final payload = await showEventCategoryDialog(context, category: category);
    if (payload == null || !mounted) return;

    try {
      await _service.saveEventCategory(
        id: payload['id'] as String?,
        name: payload['name'] as String,
        isActive: payload['isActive'] as bool,
      );
      await _refresh();
      if (mounted) {
        AppFeedback.success(
          context,
          category == null ? 'Categoría creada.' : 'Categoría actualizada.',
        );
      }
    } catch (error) {
      if (mounted) AppFeedback.error(context, friendlyError(error));
    }
  }

  Future<void> _toggleCategory(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    final active = row['is_active'] != false;
    final name = row['name']?.toString() ?? 'esta categoría';

    if (active) {
      final ok = await showAppConfirm(
        context,
        title: 'Desactivar categoría',
        message:
            '¿Desactivar "$name"? Dejará de aparecer en filtros y en el alta '
            'de eventos. Los eventos existentes la conservan.',
        confirmLabel: 'Desactivar',
        isDangerous: true,
        icon: Icons.pause_circle_outline,
      );
      if (!ok) return;
    }

    await _run(() => _service.setEventCategoryActive(id, !active));
  }

  Future<void> _generatePublication(
    String kind,
    String id,
    String title,
  ) async {
    final amountText = await showAppPrompt(
      context,
      title: 'Publicación',
      message: 'Monto a cobrar por publicar "$title".',
      label: 'Monto en BOB',
      confirmLabel: 'Generar QR',
    );
    if (amountText == null || !mounted) return;

    final validation = AppValidators.amount(amountText);
    if (validation != null) {
      AppFeedback.warning(context, validation);
      return;
    }
    final amount = double.parse(amountText.trim().replaceAll(',', '.'));

    try {
      final checkout = await const PagosyaService().createPublicationCheckout(
        kind: kind,
        referenceId: id,
        amount: amount,
      );
      if (!mounted) return;
      await showPublicationQrDialog(context, checkout);
    } catch (e) {
      if (mounted) AppFeedback.error(context, friendlyError(e));
    }
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
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: () => _setOrganizationActive(id, name, active),
        icon: Icon(
          active ? Icons.pause_circle_outline : Icons.play_circle_outline,
          size: 18,
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
      title: currentlyActive
          ? 'Suspender organización'
          : 'Activar organización',
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _action(
          'Verificar y activar',
          Icons.verified,
          () => _verifyMembership(id, true),
        ),
        _action(
          'Rechazar',
          Icons.cancel_outlined,
          () => _verifyMembership(id, false),
        ),
      ],
    );
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _action(
          'Marcar liquidada',
          Icons.check_circle_outline,
          () => _setPayoutStatus(id, 'paid'),
        ),
        _action(
          'Marcar fallida',
          Icons.error_outline,
          () => _setPayoutStatus(id, 'failed'),
        ),
      ],
    );
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
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: () => _registerPayout(row),
      icon: const Icon(Icons.payments_outlined, size: 18),
      label: const Text('Registrar liquidación'),
    ),
  );

  Widget _action(String label, IconData icon, VoidCallback onPressed) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
      );

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
    await _run(
      () => _service.registerPayout(
        organizationId: organization['id'].toString(),
        amount: amount,
        reference: reference,
      ),
    );
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
    return switch (_section) {
      AdminSection.users => _personName(row) ?? 'Usuario',
      AdminSection.organizations => _text(row['name']) ?? 'Organización',
      AdminSection.events => _text(row['title']) ?? 'Evento',
      AdminSection.categories => _text(row['name']) ?? 'Categoría',
      AdminSection.classes => _text(row['title']) ?? 'Clase',
      AdminSection.memberships =>
        _relatedName(row['organizations']) ??
            _relatedName(row['subscription_plans']) ??
            'Membresía',
      AdminSection.payments =>
        _money(row['amount'], row['currency']) ??
            DisplayLabels.paymentType(row['payment_type']),
      AdminSection.publicationPayments =>
        _money(row['amount'], row['currency']) ?? 'Pago de publicación',
      AdminSection.sales =>
        _text(row['order_number']) ?? _relatedName(row['events']) ?? 'Venta',
      AdminSection.payouts =>
        _money(row['amount'], row['currency']) ?? 'Liquidación',
      AdminSection.audit => DisplayLabels.action(row['action']),
      AdminSection.dashboard => _text(row['title']) ?? 'Evento',
      AdminSection.pagosya => 'PagosYa',
    };
  }

  String _recordDetail(Map<String, dynamic> row) {
    final values = <String?>[];

    switch (_section) {
      case AdminSection.users:
        final email = _text(row['email']);
        final phone = _text(row['phone_number']);
        final roles = row['roles'];
        final roleLabels = roles is List
            ? roles
                  .map((role) => DisplayLabels.role(role))
                  .where((label) => label.isNotEmpty)
                  .toSet()
                  .join(', ')
            : null;
        values.addAll([
          if (email != null) 'Email: $email',
          if (phone != null) 'Tel: $phone',
          if (roleLabels != null && roleLabels.isNotEmpty) 'Rol: $roleLabels',
          _date(row['created_at']),
        ]);
      case AdminSection.organizations:
        final membership = row['membership'];
        String? plan;
        String? membershipEnd;
        if (membership is Map) {
          final planName = _text(membership['name']);
          final membershipStatus = _text(membership['status']);
          membershipEnd = _date(membership['period_end']);
          if (planName != null) {
            plan = membershipStatus == null
                ? planName
                : '$planName (${DisplayLabels.status(membershipStatus)})';
          }
        }
        final eventsCount = row['events_count'];
        final classesCount = row['classes_count'];
        final verified = row['is_verified'];
        values.addAll([
          if (_text(row['email']) != null) 'Email: ${_text(row['email'])}',
          if (_text(row['phone_number']) != null)
            'Tel: ${_text(row['phone_number'])}',
          _text(row['location_name']),
          if (plan != null) 'Plan: $plan',
          if (eventsCount != null || classesCount != null)
            '${eventsCount ?? 0} eventos · ${classesCount ?? 0} clases',
          if (verified is bool)
            verified ? 'Organización verificada' : 'Sin verificar',
          if (membershipEnd != null) 'Membresía vence: $membershipEnd',
          _date(row['created_at']),
        ]);
      case AdminSection.events:
        final category =
            _text(row['category_name']) ??
            _relatedName(row['event_categories']);
        final publicationPaid = row['publication_paid'] == true;
        values.addAll([
          _relatedName(row['organizations']),
          if (category != null) 'Categoría: $category',
          if (row['start_at'] != null) 'Inicio: ${_date(row['start_at'])}',
          if (row['status'] != null)
            'Publicación: ${DisplayLabels.status(row['status'])}',
          'Pago de publicación: ${publicationPaid ? 'registrado' : 'pendiente'}',
          if (row['moderation_reason'] != null)
            'Motivo: ${row['moderation_reason']}',
          _date(row['created_at']),
        ]);
      case AdminSection.categories:
        final eventsCount = row['events_count'];
        values.addAll([
          if (eventsCount != null) 'Eventos: $eventsCount',
          _date(row['created_at']),
        ]);
      case AdminSection.classes:
        final category = _relatedName(row['dance_categories']);
        final price = _money(row['price'], row['currency']);
        final monthlyPrice = _money(row['price_monthly'], row['currency']);
        values.addAll([
          _relatedName(row['organizations']),
          if (category != null) 'Categoría: $category',
          if (row['start_at'] != null) 'Inicio: ${_date(row['start_at'])}',
          if (price != null) 'Sesión: $price',
          if (monthlyPrice != null) 'Mensual: $monthlyPrice',
          if (row['status'] != null)
            'Publicación: ${DisplayLabels.status(row['status'])}',
          _date(row['created_at']),
        ]);
      case AdminSection.memberships:
        final plan = row['subscription_plans'];
        String? planLabel;
        if (plan is Map) {
          final planName = _text(plan['name']);
          final interval = DisplayLabels.interval(
            row['billing_interval'] ?? plan['interval'],
          );
          final price = _money(plan['price'], plan['currency']);
          planLabel = [?planName, interval, ?price].join(' · ');
        }
        final paymentStatus = _text(row['payment_status']);
        final start = _date(row['current_period_start']);
        final end = _date(row['current_period_end']);
        values.addAll([
          if (planLabel != null && planLabel.isNotEmpty) 'Plan: $planLabel',
          if (paymentStatus != null)
            'Pago: ${DisplayLabels.status(paymentStatus)}',
          if (start != null && end != null)
            'Período: $start → $end'
          else if (start != null)
            'Desde: $start',
          _date(row['created_at']),
        ]);
      case AdminSection.payments:
        final plan = _relatedName(row['subscription_plans']);
        final orderNumber = _text(row['order_number']);
        values.addAll([
          _relatedName(row['organizations']),
          'Tipo: ${DisplayLabels.paymentType(row['payment_type'])}',
          if (plan != null) 'Plan: $plan',
          if (orderNumber != null) 'Orden: $orderNumber',
          if (row['provider'] != null)
            'Proveedor: ${DisplayLabels.provider(row['provider'])}',
          if (row['paid_at'] != null) 'Pagado: ${_date(row['paid_at'])}',
          if (row['created_at'] != null)
            'Registrado: ${_date(row['created_at'])}',
        ]);
      case AdminSection.publicationPayments:
        final payment = row['payments'];
        String? paymentLabel;
        if (payment is Map) {
          final status = _text(payment['status']);
          final provider = _text(payment['provider']);
          paymentLabel = [
            if (status != null) DisplayLabels.status(status),
            if (provider != null) DisplayLabels.provider(provider),
          ].join(' · ');
        }
        values.addAll([
          _relatedName(row['events']),
          if (paymentLabel != null && paymentLabel.isNotEmpty)
            'Pago: $paymentLabel',
          if (row['paid_at'] != null) 'Pagado: ${_date(row['paid_at'])}',
          if (row['created_at'] != null)
            'Registrado: ${_date(row['created_at'])}',
        ]);
      case AdminSection.sales:
        final subtotal = row['subtotal'];
        final fee = row['platform_fee'];
        String? organizer;
        if (subtotal is num && fee is num) {
          organizer = _money(subtotal - fee, row['currency']);
        }
        values.addAll([
          _relatedName(row['events']),
          if (_relatedName(row['profiles']) != null)
            'Comprador: ${_relatedName(row['profiles'])}',
          if (row['total_amount'] != null)
            'Total: ${_money(row['total_amount'], row['currency'])}',
          if (fee != null) 'Comisión: ${_money(fee, row['currency'])}',
          if (organizer != null) 'Organizador: $organizer',
          _date(row['created_at']),
        ]);
      case AdminSection.payouts:
        final metadata = row['metadata'];
        final reference = metadata is Map ? _text(metadata['reference']) : null;
        final start = _date(row['period_start']);
        final end = _date(row['period_end']);
        values.addAll([
          _relatedName(row['organizations']),
          if (start != null && end != null)
            'Período: $start → $end'
          else if (start != null)
            'Desde: $start',
          if (reference != null) 'Referencia: $reference',
          if (row['provider'] != null)
            'Proveedor: ${DisplayLabels.provider(row['provider'])}',
          if (row['processed_at'] != null)
            'Procesado: ${_date(row['processed_at'])}',
          if (row['created_at'] != null)
            'Registrado: ${_date(row['created_at'])}',
        ]);
      case AdminSection.audit:
        final person = _relatedName(row['profiles']);
        final entityType = _text(row['entity_type']);
        final entityId = _shortId(row['entity_id']);
        final newValues = row['new_values'];
        final changedFields = newValues is Map && newValues.isNotEmpty
            ? newValues.keys.take(3).join(', ')
            : null;
        values.addAll([
          ?person,
          if (entityType != null)
            'Entidad: $entityType${entityId == null ? '' : ' · $entityId'}',
          if (changedFields != null) 'Campos: $changedFields',
          _date(row['created_at']),
        ]);
      case AdminSection.dashboard:
        values.addAll([
          _relatedName(row['organizations']),
          _date(row['created_at']),
        ]);
      case AdminSection.pagosya:
        break;
    }

    return values
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');
  }

  String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _personName(Map<dynamic, dynamic> row) {
    final first = _text(row['first_name']);
    final last = _text(row['last_name']);
    final name = [first, last].whereType<String>().join(' ').trim();
    if (name.isNotEmpty) return name;
    return _text(row['phone_number']);
  }

  String? _relatedName(Object? related) {
    if (related is! Map) return null;
    final direct = _text(related['name']) ?? _text(related['title']);
    if (direct != null) return direct;
    return _personName(related);
  }

  String? _money(Object? value, Object? currency) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (amount == null) return null;
    final code = _text(currency) ?? 'BOB';
    final decimals = amount == amount.roundToDouble() ? 0 : 2;
    return '$code ${amount.toStringAsFixed(decimals)}';
  }

  String? _date(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text.split('T').first;
  }

  String? _shortId(Object? value) {
    final text = _text(value);
    if (text == null) return null;
    return text.length <= 8 ? text : '${text.substring(0, 8)}…';
  }

  IconData _iconFor(AdminSection section) => switch (section) {
    AdminSection.dashboard => Icons.dashboard_outlined,
    AdminSection.users => Icons.people_outline,
    AdminSection.organizations => Icons.apartment_outlined,
    AdminSection.events => Icons.event_outlined,
    AdminSection.categories => Icons.category_outlined,
    AdminSection.classes => Icons.school_outlined,
    AdminSection.memberships => Icons.card_membership_outlined,
    AdminSection.pagosya => Icons.account_balance_wallet_outlined,
    AdminSection.payments ||
    AdminSection.publicationPayments => Icons.payments_outlined,
    AdminSection.sales => Icons.shopping_bag_outlined,
    AdminSection.payouts => Icons.account_balance_outlined,
    AdminSection.audit => Icons.history,
  };
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({
    required this.rows,
    required this.totalEvents,
    required this.pendingEvents,
    required this.approvedEvents,
    required this.onOpen,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> rows;
  final int totalEvents;
  final int pendingEvents;
  final int approvedEvents;
  final ValueChanged<AdminSection> onOpen;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final pending = pendingEvents;
    final approved = approvedEvents;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 1080
            ? (constraints.maxWidth - 1000) / 2
            : 24.0;
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 32),
            children: [
              AppInfoCard(
                icon: pending == 0
                    ? Icons.check_circle_outline
                    : Icons.hourglass_top_outlined,
                color: pending == 0 ? AppColors.success : AppColors.warning,
                title: pending == 0
                    ? 'Sin eventos pendientes'
                    : '$pending ${pending == 1 ? 'evento pendiente' : 'eventos pendientes'} de revisión',
                message: pending == 0
                    ? 'Los eventos aprobados ya están visibles para el público.'
                    : 'Revisá los eventos enviados por las organizaciones y aprobalos o rechazalos.',
              ),
              if (pending != 0) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => onOpen(AdminSection.events),
                    icon: const Icon(Icons.rule_outlined, size: 18),
                    label: const Text('Revisar eventos'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Accesos rápidos',
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                  border: Border.all(color: context.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < _shortcuts.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: context.divider),
                      ListTile(
                        leading: Icon(
                          _shortcuts[i].icon,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        title: Text(
                          _shortcuts[i].section.label,
                          style: TextStyle(
                            color: context.textOnBg,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _shortcuts[i].description,
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: context.textMuted,
                          size: 20,
                        ),
                        onTap: () => onOpen(_shortcuts[i].section),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Revisión reciente',
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (rows.isNotEmpty)
                    Text(
                      '$approved ${approved == 1 ? 'aprobado' : 'aprobados'} de $totalEvents',
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingMedium),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    border: Border.all(color: context.divider),
                  ),
                  child: Text(
                    'Todavía no hay eventos para revisar. Cuando una organización envíe uno, aparecerá acá.',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    border: Border.all(color: context.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.take(8).length; i++) ...[
                        if (i > 0) Divider(height: 1, color: context.divider),
                        ListTile(
                          leading: const Icon(
                            Icons.event_note_outlined,
                            size: 22,
                          ),
                          title: Text(
                            rows[i]['title']?.toString() ?? 'Evento',
                            style: TextStyle(
                              color: context.textOnBg,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            DisplayLabels.status(
                              rows[i]['moderation_status'],
                              fallback: 'Sin moderación',
                            ),
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: context.textMuted,
                            size: 20,
                          ),
                          onTap: () => onOpen(AdminSection.events),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OrganizationLogo extends StatelessWidget {
  const _OrganizationLogo({required this.logoUrl, required this.name});

  final String? logoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final url = organizationLogoUrl(logoUrl);
    final fallback = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: name.isEmpty
          ? const Icon(
              Icons.apartment_outlined,
              color: AppColors.primary,
              size: 22,
            )
          : Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        child: SizedBox(
          width: 44,
          height: 44,
          child: url == null
              ? fallback
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return ColoredBox(
                      color: context.surfaceDeep,
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AdminListSkeleton extends StatelessWidget {
  const _AdminListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando datos',
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, _) => Container(
          height: 92,
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: context.divider),
          ),
        ),
      ),
    );
  }
}

class _AdminNavGroup {
  const _AdminNavGroup(this.label, this.sections);

  final String label;
  final List<AdminSection> sections;
}

const _navGroups = <_AdminNavGroup>[
  _AdminNavGroup('General', [AdminSection.dashboard]),
  _AdminNavGroup('Comunidad', [AdminSection.users, AdminSection.organizations]),
  _AdminNavGroup('Contenido', [
    AdminSection.events,
    AdminSection.classes,
    AdminSection.categories,
  ]),
  _AdminNavGroup('Membresías y pagos', [
    AdminSection.memberships,
    AdminSection.payments,
    AdminSection.publicationPayments,
    AdminSection.sales,
    AdminSection.payouts,
  ]),
  _AdminNavGroup('Plataforma', [AdminSection.pagosya, AdminSection.audit]),
];

class _AdminShortcut {
  const _AdminShortcut(this.section, this.icon, this.description);

  final AdminSection section;
  final IconData icon;
  final String description;
}

const _shortcuts = <_AdminShortcut>[
  _AdminShortcut(
    AdminSection.organizations,
    Icons.apartment_outlined,
    'Estado, cobros y liquidaciones de cada academia.',
  ),
  _AdminShortcut(
    AdminSection.memberships,
    Icons.card_membership_outlined,
    'Solicitudes pendientes y suscripciones activas.',
  ),
  _AdminShortcut(
    AdminSection.payments,
    Icons.payments_outlined,
    'Pagos de membresías, entradas y publicaciones.',
  ),
  _AdminShortcut(
    AdminSection.pagosya,
    Icons.account_balance_wallet_outlined,
    'Integración de cobros, planes y webhooks.',
  ),
];

String _sectionDescription(AdminSection section) => switch (section) {
  AdminSection.dashboard =>
    'Revisá la actividad de la plataforma y accedé a cada área.',
  AdminSection.users => 'Cuentas registradas en la plataforma y sus roles.',
  AdminSection.organizations =>
    'Academias y organizaciones: estado, cuenta de cobros y liquidaciones.',
  AdminSection.events =>
    'Moderá eventos, aprobá publicaciones y generá el QR cuando corresponda.',
  AdminSection.categories =>
    'Categorías disponibles para clasificar eventos y clases.',
  AdminSection.classes =>
    'Clases creadas por las organizaciones y su estado de publicación.',
  AdminSection.memberships =>
    'Solicitudes de membresía pendientes de verificación y suscripciones.',
  AdminSection.payments => 'Pagos registrados en la plataforma.',
  AdminSection.pagosya =>
    'Integración de cobros, planes de membresía y webhooks.',
  AdminSection.publicationPayments => 'Pagos de publicación de eventos.',
  AdminSection.sales => 'Órdenes y ventas de entradas, clases y pases.',
  AdminSection.payouts => 'Liquidaciones a organizaciones.',
  AdminSection.audit => 'Registro de acciones administrativas.',
};

String _readStatus(Map<String, dynamic> row) {
  final moderationStatus = row['moderation_status'];
  if (moderationStatus != null) return moderationStatus.toString();
  final status = row['status'];
  if (status != null) return status.toString();
  final isActive = row['is_active'];
  if (isActive is bool) return isActive ? 'active' : 'inactive';
  return '';
}

Color _statusColor(BuildContext context, String status) {
  return switch (status) {
    'approved' ||
    'active' ||
    'paid' ||
    'completed' ||
    'accepted' ||
    'published' ||
    'issued' ||
    'used' ||
    'present' => AppColors.success,
    'rejected' ||
    'failed' ||
    'suspended' ||
    'absent' ||
    'declined' => AppColors.error,
    'pending' ||
    'pending_approval' ||
    'processing' ||
    'past_due' ||
    'late' ||
    'scheduled' ||
    'draft' ||
    'open' ||
    'inactive' ||
    'expired' ||
    'cancelled' ||
    'canceled' => AppColors.warning,
    _ => context.textMuted,
  };
}
