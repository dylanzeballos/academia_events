// lib/features/organization/views/organization_membership_view.dart
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/display_labels.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/services/membership_service.dart';
import '../../../data/services/pagosya_service.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../tickets/views/pagosya_checkout_screen.dart';

class OrganizationMembershipView extends StatefulWidget {
  const OrganizationMembershipView({super.key, required this.organizationId});
  final String organizationId;

  @override
  State<OrganizationMembershipView> createState() =>
      _OrganizationMembershipViewState();
}

class _OrganizationMembershipViewState
    extends State<OrganizationMembershipView> {
  /// Días antes del vencimiento en los que se habilita renovar.
  static const int renewalWindowDays = 7;

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
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator();
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'No se pudo cargar la información de membresía.',
            onRetry: _reload,
          );
        }
        final memberships = snapshot.data![0] as List<Map<String, dynamic>>;
        final plans = snapshot.data![1] as List<Map<String, dynamic>>;

        final active = _activeMembership(memberships);
        final pending = _pendingMembership(memberships);
        final activeEnd = active == null
            ? null
            : DateTime.tryParse(active['current_period_end']?.toString() ?? '');
        final canRenewNow =
            active != null &&
            activeEnd != null &&
            activeEnd.difference(DateTime.now()) <=
                const Duration(days: renewalWindowDays);

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle(
                title: 'Estado de la membresía',
                subtitle: 'La membresía mantiene la academia activa y habilita la publicación.',
              ),
              const SizedBox(height: 12),
              if (memberships.isEmpty)
                const _NoMembershipCard()
              else
                for (final membership in memberships)
                  _MembershipStatusCard(membership: membership),
              const SizedBox(height: 24),
              if (active != null && !canRenewNow)
                _RenewalNotice(
                  endsAt: activeEnd,
                  from: activeEnd?.subtract(
                    const Duration(days: renewalWindowDays),
                  ),
                )
              else if (pending != null)
                _PendingPaymentCard(
                  busy: _busy,
                  onContinue: () =>
                      _pay(subscriptionId: pending['id'].toString()),
                )
              else ...[
                _SectionTitle(
                  title: active != null
                      ? 'Renovar membresía'
                      : 'Planes disponibles',
                  subtitle: active != null
                      ? 'La renovación se suma al período que todavía tenés.'
                      : 'Pagás con QR y la membresía se activa al confirmarse.',
                ),
                const SizedBox(height: 12),
                if (plans.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'La plataforma todavía no publicó planes.',
                      style: TextStyle(color: context.textMuted, fontSize: 13),
                    ),
                  )
                else
                  for (final plan in plans)
                    _PlanOfferCard(
                      plan: plan,
                      busy: _busy,
                      label: active != null ? 'Renovar' : 'Comprar',
                      onBuy: () => _purchase(plan, isRenewal: active != null),
                    ),
              ],
              const SizedBox(height: 70),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _activeMembership(List<Map<String, dynamic>> list) {
    final now = DateTime.now();
    Map<String, dynamic>? best;
    DateTime? bestEnd;

    for (final membership in list) {
      if (membership['status'] != 'active') continue;
      final end = DateTime.tryParse(
        membership['current_period_end']?.toString() ?? '',
      );
      if (end != null && !end.isAfter(now)) continue;
      if (best == null ||
          (end != null && (bestEnd == null || end.isAfter(bestEnd)))) {
        best = membership;
        bestEnd = end;
      }
    }
    return best;
  }

  Map<String, dynamic>? _pendingMembership(List<Map<String, dynamic>> list) {
    for (final membership in list) {
      if (membership['status'] == 'pending') return membership;
    }
    return null;
  }

  /// Compra o renovación directa: registra la suscripción pendiente y genera
  /// el QR de pago. Si PagosYa no está conectado, muestra el error exacto.
  Future<void> _purchase(
    Map<String, dynamic> plan, {
    required bool isRenewal,
  }) async {
    setState(() => _busy = true);
    try {
      final result = isRenewal
          ? await _service.renew(
              organizationId: widget.organizationId,
              planId: plan['id'].toString(),
            )
          : await _service.request(
              organizationId: widget.organizationId,
              planId: plan['id'].toString(),
            );

      final subscriptionId = result['subscription_id']?.toString();
      if (subscriptionId == null || subscriptionId.isEmpty) {
        throw Exception(
          'La membresía no se pudo registrar (sin subscription_id).',
        );
      }
      await _pay(subscriptionId: subscriptionId, keepBusy: true);
    } catch (e) {
      if (mounted) AppFeedback.error(context, _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay({
    required String subscriptionId,
    bool keepBusy = false,
  }) async {
    if (!keepBusy && mounted) setState(() => _busy = true);
    try {
      final checkout = await const PagosyaService().createCheckout(
        kind: 'membership',
        referenceId: subscriptionId,
      );
      if (!mounted) return;

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PagosyaCheckoutScreen(checkout: checkout),
        ),
      );

      await _reload();
      if (mounted && paid == true) {
        AppFeedback.success(context, 'Membresía activada correctamente.');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, _errorText(e));
    } finally {
      if (mounted && !keepBusy) setState(() => _busy = false);
    }
  }

  /// Mensaje limpio: sin el volcado de `PostgrestException`.
  String _errorText(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

/// Aviso cuando la membresía está activa y todavía no se puede renovar.
class _RenewalNotice extends StatelessWidget {
  const _RenewalNotice({required this.endsAt, required this.from});

  final DateTime? endsAt;
  final DateTime? from;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 20,
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tenés una membresía activa',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (endsAt != null) 'Vence el ${_date(endsAt!)}.',
                    if (from != null)
                      'Podrás renovarla desde el ${_date(from!)}.',
                  ].join(' '),
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

/// Pago pendiente: se retoma sin crear otra suscripción.
class _PendingPaymentCard extends StatelessWidget {
  const _PendingPaymentCard({required this.busy, required this.onContinue});

  final bool busy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions_rounded,
                size: 20,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tenés un pago pendiente',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Terminá el pago para activar la membresía. No hace falta comprar de '
            'nuevo.',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_2, size: 18),
            label: const Text('Continuar pago'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
            ),
            onPressed: busy ? null : onContinue,
          ),
        ],
      ),
    );
  }
}

class _NoMembershipCard extends StatelessWidget {
  const _NoMembershipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: context.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todavía no hay una membresía',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comprá un plan para mantener la academia activa y poder '
                  'publicar clases y eventos.',
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipStatusCard extends StatelessWidget {
  const _MembershipStatusCard({required this.membership});

  final Map<String, dynamic> membership;

  Color get _color => switch (membership['status']) {
    'active' => AppColors.success,
    'pending' => AppColors.warning,
    'cancelled' || 'expired' => AppColors.error,
    _ => AppColors.primary,
  };

  String get _planName {
    final plan = membership['subscription_plans'];
    return plan is Map ? plan['name']?.toString() ?? 'Membresía' : 'Membresía';
  }

  String get _period {
    final start = membership['current_period_start']
        ?.toString()
        .split('T')
        .first;
    final end = membership['current_period_end']?.toString().split('T').first;
    if (start == null && end == null) return 'Fechas pendientes';
    return '${start ?? '—'} al ${end ?? '—'}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _planName,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  DisplayLabels.status(membership['status']),
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Vigencia: $_period',
            style: TextStyle(color: context.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _PlanOfferCard extends StatelessWidget {
  const _PlanOfferCard({
    required this.plan,
    required this.busy,
    required this.label,
    required this.onBuy,
  });

  final Map<String, dynamic> plan;
  final bool busy;
  final String label;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final name = plan['name']?.toString() ?? 'Plan';
    final description = plan['description']?.toString();
    final price = plan['price'];
    final currency = plan['currency']?.toString() ?? 'BOB';
    final interval = DisplayLabels.interval(plan['interval']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$price $currency',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            interval,
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
          if (description != null && description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.qr_code_2, size: 18),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              ),
              onPressed: busy ? null : onBuy,
            ),
          ),
        ],
      ),
    );
  }
}
