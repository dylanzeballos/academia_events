// lib/features/organization/views/organization_payments_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/services/pagosya_service.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_responsive_body.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/pagosya_bank_status_card.dart';
import '../widgets/pagosya_onboarding_card.dart';
import '../widgets/pagosya_payments_actions.dart';

/// Cobros QR de la organización (PagosYa SaaS).
/// El comercio conecta su propio banco; la plataforma solo lo acompaña.
class OrganizationPaymentsView extends ConsumerStatefulWidget {
  const OrganizationPaymentsView({super.key, required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<OrganizationPaymentsView> createState() =>
      _OrganizationPaymentsViewState();
}

class _OrganizationPaymentsViewState
    extends ConsumerState<OrganizationPaymentsView> {
  static const _service = PagosyaService();

  Map<String, dynamic>? _account;
  Map<String, dynamic>? _summary;
  bool? _canManage;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      final results = await Future.wait<dynamic>([
        if (userId != null)
          supabase
              .from('organization_members')
              .select('role')
              .eq('organization_id', widget.organizationId)
              .eq('user_id', userId)
              .eq('is_active', true)
              .maybeSingle()
        else
          Future<dynamic>.value(null),
        supabase
            .from('organization_payment_accounts')
            .select('affiliate_id, bank_status, branding_mode, payment_ui')
            .eq('organization_id', widget.organizationId)
            .maybeSingle(),
      ]);

      final member = results[0] as Map<String, dynamic>?;
      final role = member?['role']?.toString();

      if (!mounted) return;
      setState(() {
        _canManage =
            role != null && const {'owner', 'admin', 'manager'}.contains(role);
        _account = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _canManage = false;
        _loading = false;
      });
    }
  }

  Future<void> _adjust(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) AppFeedback.error(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate() => _adjust(() async {
    await _service.merchantCreate(widget.organizationId);
    await _load();
    if (mounted) {
      AppFeedback.success(context, 'Cuenta de cobros creada.');
    }
  });

  Future<void> _refreshStatus() => _adjust(() async {
    final summary = await _service.merchantSummary(widget.organizationId);
    await _load();
    if (!mounted) return;
    setState(() => _summary = summary);
    AppFeedback.success(context, 'Estado actualizado.');
  });

  Future<void> _openSession(Future<Map<String, dynamic>> Function() action) =>
      _adjust(() async {
        final result = await action();
        final url = result['url'] as String?;
        if (url == null || url.isEmpty) {
          throw Exception('PagosYa no devolvió un enlace válido');
        }
        final ok = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!ok && mounted) {
          AppFeedback.error(context, 'No se pudo abrir PagosYa.');
        }
      });

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator();
    if (_canManage != true) return const PagosyaNoPermission();

    return AppResponsiveBody(
      maxWidth: 760,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Text(
              'Cobros QR',
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cada organización cobra en su propio banco. PagosYa cobra la '
              'comisión al comercio (1 % Embedded o 2 % White Label).',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              AppInfoCard(
                icon: Icons.error_outline,
                color: AppColors.error,
                title: 'No se pudo cargar el estado',
                message: _error!,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
              const SizedBox(height: 16),
            ],
            if (_account == null)
              PagosyaOnboardingCard(busy: _busy, onActivate: _activate)
            else ...[
              PagosyaBankStatusCard(account: _account!, summary: _summary),
              const SizedBox(height: 12),
              PagosyaPaymentsActions(
                busy: _busy,
                onConnectBank: () => _openSession(
                  () => _service.bankSession(widget.organizationId),
                ),
                onRefresh: _refreshStatus,
                onCommissions: () => _openSession(
                  () => _service.commissionSession(widget.organizationId),
                ),
              ),
              const SizedBox(height: 12),
              const AppInfoCard(
                icon: Icons.info_outline,
                color: AppColors.primary,
                title: 'Cómo funciona el alta',
                message:
                    'El enlace bancario vence a los 30 minutos. El titular acepta '
                    'las condiciones, completa los datos BANECO y firma. Cuando el '
                    'banco entrega las credenciales, vuelve a este menú para '
                    'guardarlas. Solo bank.status = connected habilita cobros.',
              ),
              const SizedBox(height: 12),
              AppSectionCard(
                title: 'Comisión del comercio',
                icon: Icons.percent,
                children: [
                  Text(
                    _commissionText(_account!),
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppSectionCard(
                title: 'ID de comercio',
                icon: Icons.badge_outlined,
                trailing: IconButton(
                  tooltip: 'Copiar ID',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text: _account!['affiliate_id']?.toString() ?? '',
                      ),
                    );
                    if (context.mounted) {
                      AppFeedback.success(context, 'ID copiado.');
                    }
                  },
                ),
                children: [
                  SelectableText(
                    _account!['affiliate_id']?.toString() ?? '-',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Identificador de la cuenta de cobros en PagosYa.',
                    style: TextStyle(color: context.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _commissionText(Map<String, dynamic> account) {
    final whiteLabel = account['branding_mode'] == 'white_label';
    final rate = whiteLabel ? '2 %' : '1 %';
    return '${whiteLabel ? 'White Label' : 'Embedded'} · $rate sobre ventas '
        'confirmadas. El ciclo cierra cada 7 días y la factura vence 24 h '
        'después. La mensualidad de la plataforma se paga aparte.';
  }
}
