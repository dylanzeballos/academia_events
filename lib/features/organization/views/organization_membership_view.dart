// lib/features/organization/views/organization_membership_view.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/display_labels.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/services/membership_service.dart';

class OrganizationMembershipView extends StatefulWidget {
  const OrganizationMembershipView({super.key, required this.organizationId});
  final String organizationId;

  @override
  State<OrganizationMembershipView> createState() =>
      _OrganizationMembershipViewState();
}

class _OrganizationMembershipViewState
    extends State<OrganizationMembershipView> {
  final _service = const MembershipService();
  late Future<List<dynamic>> _data;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<List<dynamic>> _load() => Future.wait([
        _service.fetchOrganizationMemberships(widget.organizationId),
        _service.fetchPlans(),
      ]);

  Future<void> _reload() async {
    setState(() => _data = _load());
    await _data;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.scaffoldBg,
        body: FutureBuilder<List<dynamic>>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'No se pudo cargar la información de membresía.',
                  style: TextStyle(color: context.textMuted),
                ),
              );
            }
            final memberships = snapshot.data![0] as List<Map<String, dynamic>>;
            final plans = snapshot.data![1] as List<Map<String, dynamic>>;
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Membresía de la organización',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (memberships.isEmpty)
                    Card(
                      color: context.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        side: BorderSide(color: context.divider),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.info_outline, color: context.textMuted),
                        title: Text('Todavía no hay una membresía', style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Solicita un plan y registra el comprobante. La activación se realiza después de la verificación administrativa.',
                          style: TextStyle(color: context.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    for (final membership in memberships)
                      Card(
                        color: context.cardBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                          side: BorderSide(color: context.divider),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.card_membership_outlined, color: AppColors.primary),
                          title: Text(_planName(membership['subscription_plans']), style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'Estado: ${DisplayLabels.status(membership['status'])} · ${_period(membership)}',
                            style: TextStyle(color: context.textMuted, fontSize: 13),
                          ),
                        ),
                      ),
                  const SizedBox(height: 20),
                  Text(
                    'Planes disponibles',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (plans.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('No hay planes configurados todavía.', style: TextStyle(color: context.textMuted)),
                    ),
                  for (final plan in plans)
                    Card(
                      color: context.cardBg,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                        side: BorderSide(color: context.divider),
                      ),
                      child: ListTile(
                        title: Text(plan['name']?.toString() ?? 'Plan', style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${plan['description'] ?? 'Membresía organizacional'}\n${plan['price']} ${plan['currency']} · ${DisplayLabels.interval(plan['interval'])}',
                          style: TextStyle(color: context.textMuted, fontSize: 13),
                        ),
                        isThreeLine: true,
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSmall)),
                          ),
                          onPressed: _busy ? null : () => _request(plan),
                          child: const Text('Solicitar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 70),
                ],
              ),
            );
          },
        ),
      );

  Future<void> _request(Map<String, dynamic> plan) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Solicitar ${plan['name']}', style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Importe: ${plan['price']} ${plan['currency']}. La pasarela aún no está conectada; el pago quedará pendiente de verificación manual.',
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              style: TextStyle(color: context.textOnBg),
              decoration: InputDecoration(
                labelText: 'Nota o referencia de pago (opcional)',
                labelStyle: TextStyle(color: context.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear solicitud'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      note.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.request(
        organizationId: widget.organizationId,
        planId: plan['id'].toString(),
        paymentNote: note.text.trim(),
      );
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Solicitud registrada. La membresía quedará activa cuando administración verifique el pago.',
            ),
            backgroundColor: context.cardBg,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No se pudo registrar la solicitud. Verifica tus permisos e inténtalo de nuevo.',
            ),
            backgroundColor: context.cardBg,
          ),
        );
      }
    } finally {
      note.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  String _planName(dynamic plan) =>
      plan is Map ? plan['name']?.toString() ?? 'Membresía' : 'Membresía';

  String _period(Map<String, dynamic> membership) {
    final start =
        membership['current_period_start']?.toString().split('T').first;
    final end = membership['current_period_end']?.toString().split('T').first;
    if (start == null && end == null) return 'Pendiente de fechas';
    return '${start ?? '—'} a ${end ?? '—'}';
  }
}