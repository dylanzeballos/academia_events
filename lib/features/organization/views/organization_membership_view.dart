import 'package:flutter/material.dart';

import '../../../core/utils/display_labels.dart';
import '../../../data/services/membership_service.dart';

class OrganizationMembershipView extends StatefulWidget {
  const OrganizationMembershipView({super.key, required this.organizationId});
  final String organizationId;

  @override
  State<OrganizationMembershipView> createState() => _OrganizationMembershipViewState();
}

class _OrganizationMembershipViewState extends State<OrganizationMembershipView> {
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
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return const Center(child: Text('No se pudo cargar la información de membresía.'));
          final memberships = snapshot.data![0] as List<Map<String, dynamic>>;
          final plans = snapshot.data![1] as List<Map<String, dynamic>>;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Membresía de la organización', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (memberships.isEmpty)
                  const Card(child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Todavía no hay una membresía'),
                    subtitle: Text('Solicita un plan y registra el comprobante. La activación se realiza después de la verificación administrativa.'),
                  ))
                else
                  for (final membership in memberships)
                    Card(child: ListTile(
                      leading: const Icon(Icons.card_membership_outlined),
                      title: Text(_planName(membership['subscription_plans'])),
                      subtitle: Text('Estado: ${DisplayLabels.status(membership['status'])} · ${_period(membership)}'),
                    )),
                const SizedBox(height: 20),
                Text('Planes disponibles', style: Theme.of(context).textTheme.titleMedium),
                if (plans.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Text('No hay planes configurados todavía.')),
                for (final plan in plans)
                  Card(
                    child: ListTile(
                      title: Text(plan['name']?.toString() ?? 'Plan'),
                      subtitle: Text('${plan['description'] ?? 'Membresía organizacional'}\n${plan['price']} ${plan['currency']} · ${DisplayLabels.interval(plan['interval'])}'),
                      isThreeLine: true,
                      trailing: FilledButton(
                        onPressed: _busy ? null : () => _request(plan),
                        child: const Text('Solicitar'),
                      ),
                    ),
                  ),
                const SizedBox(height: 70),
              ],
            ),
          );
        },
      );

  Future<void> _request(Map<String, dynamic> plan) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Solicitar ${plan['name']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Importe: ${plan['price']} ${plan['currency']}. La pasarela aún no está conectada; el pago quedará pendiente de verificación manual.'),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Nota o referencia de pago (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear solicitud')),
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
          const SnackBar(content: Text('Solicitud registrada. La membresía quedará activa cuando administración verifique el pago.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo registrar la solicitud. Verifica tus permisos e inténtalo de nuevo.')),
        );
      }
    } finally {
      note.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  String _planName(dynamic plan) => plan is Map ? plan['name']?.toString() ?? 'Membresía' : 'Membresía';

  String _period(Map<String, dynamic> membership) {
    final start = membership['current_period_start']?.toString().split('T').first;
    final end = membership['current_period_end']?.toString().split('T').first;
    if (start == null && end == null) return 'Pendiente de fechas';
    return '${start ?? '—'} a ${end ?? '—'}';
  }
}
