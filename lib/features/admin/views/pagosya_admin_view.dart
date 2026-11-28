// lib/features/admin/views/pagosya_admin_view.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../data/services/admin_service.dart';
import '../../../data/services/pagosya_service.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_responsive_body.dart';
import '../widgets/membership_plan_dialog.dart';
import '../widgets/pagosya_admin_cards.dart';
import '../widgets/pagosya_plans_card.dart';
import '../widgets/pagosya_webhook_cards.dart';
import '../widgets/pagosya_webhook_secret_dialog.dart';

/// Panel de control de PagosYa para administradores de plataforma.
class PagosyaAdminView extends StatefulWidget {
  const PagosyaAdminView({super.key});

  @override
  State<PagosyaAdminView> createState() => _PagosyaAdminViewState();
}

class _PagosyaAdminViewState extends State<PagosyaAdminView> {
  static const _service = PagosyaService();
  static const _adminService = AdminService();

  Map<String, dynamic>? _config;
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _webhook;
  Map<String, dynamic>? _platformSummary;
  List<Map<String, dynamic>> _accounts = const [];
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _plans = const [];
  String? _overviewError;
  String? _webhookError;
  String? _platformError;
  String? _plansError;

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
      _overviewError = null;
      _webhookError = null;
      _platformError = null;
      _plansError = null;
      _overview = null;
      _webhook = null;
      _platformSummary = null;
    });

    try {
      final config = await supabase
          .from('payment_platform_config')
          .select(
            'affiliate_id, external_id, updated_at, event_publication_price',
          )
          .eq('id', true)
          .maybeSingle();

      final accounts = await supabase
          .from('organization_payment_accounts')
          .select(
            'organization_id, affiliate_id, bank_status, organizations(name)',
          )
          .order('created_at', ascending: false)
          .limit(100);

      final events = await supabase
          .from('pagosya_webhook_events')
          .select('event_id, event_type, status, error, received_at')
          .order('received_at', ascending: false)
          .limit(20);

      if (!mounted) return;
      setState(() {
        _config = config;
        _accounts = _asList(accounts);
        _events = _asList(events);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
      return;
    }

    // Datos remotos: un fallo no debe romper el panel.
    try {
      final plans = await _adminService.fetchMembershipPlans();
      if (mounted) setState(() => _plans = plans);
    } catch (e) {
      if (mounted) setState(() => _plansError = friendlyError(e));
    }

    try {
      final overview = await _service.overview();
      if (mounted) setState(() => _overview = overview);
    } catch (e) {
      if (mounted) setState(() => _overviewError = e.toString());
    }

    try {
      final webhook = await _service.webhookGet();
      if (mounted) setState(() => _webhook = webhook);
    } catch (e) {
      if (mounted) setState(() => _webhookError = e.toString());
    }

    final affiliate = _config?['affiliate_id']?.toString() ?? '';
    if (affiliate.isNotEmpty) {
      try {
        final summary = await _service.platformMerchantSummary();
        if (mounted) setState(() => _platformSummary = summary);
      } catch (e) {
        if (mounted) setState(() => _platformError = friendlyError(e));
      }
    }
  }

  List<Map<String, dynamic>> _asList(Object? value) => (value as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted) AppFeedback.success(context, success);
    } catch (e) {
      if (mounted) AppFeedback.error(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _registerPlatform() => _run(() async {
    await _service.registerPlatformMerchant();
  }, 'Plataforma registrada en PagosYa.');

  Future<void> _connectPlatformBank() async {
    setState(() => _busy = true);
    try {
      final result = await _service.platformBankSession();
      final url = result['url'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('PagosYa no devolvió un enlace bancario');
      }
      if (!mounted) return;
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        AppFeedback.error(context, 'No se pudo abrir PagosYa.');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshPlatformBank() => _run(() async {
    await _service.platformMerchantSummary();
  }, 'Estado del banco actualizado.');

  Future<void> _openPlanForm([Map<String, dynamic>? plan]) async {
    final payload = await showMembershipPlanDialog(context, plan: plan);
    if (payload == null || !mounted) return;

    final id = payload['id'] as String?;
    await _run(() async {
      await _adminService.saveMembershipPlan(
        id: id,
        name: payload['name'] as String,
        description: payload['description'] as String?,
        price: (payload['price'] as num).toDouble(),
        currency: payload['currency'] as String,
        interval: payload['interval'] as String,
        isActive: payload['isActive'] as bool,
        canCreateEvents: payload['canCreateEvents'] as bool,
        canCreateClasses: payload['canCreateClasses'] as bool,
        showInCalendar: payload['showInCalendar'] as bool,
        maxEventsPerMonth: payload['maxEventsPerMonth'] as int?,
        maxClassesPerMonth: payload['maxClassesPerMonth'] as int?,
      );
    }, plan == null ? 'Plan creado.' : 'Plan actualizado.');
  }

  Future<void> _togglePlan(Map<String, dynamic> plan) async {
    final id = plan['id']?.toString();
    if (id == null || id.isEmpty) return;
    final active = plan['is_active'] != false;
    if (active) {
      final name = plan['name']?.toString() ?? 'este plan';
      final ok = await showAppConfirm(
        context,
        title: 'Desactivar plan',
        message:
            '"$name" dejará de ofrecerse en la app y no habilitará publicar '
            'clases ni eventos. Podés reactivarlo cuando quieras.',
        confirmLabel: 'Desactivar',
        isDangerous: true,
        icon: Icons.pause_circle_outline,
      );
      if (!ok || !mounted) return;
    }
    await _run(
      () => _adminService.setMembershipPlanActive(id, !active),
      active ? 'Plan desactivado.' : 'Plan activado.',
    );
  }

  Future<void> _editPublicationPrice() async {
    final current = _eventPublicationPrice;
    final text = await showAppPrompt(
      context,
      title: 'Precio de publicación',
      message:
          'Precio único que paga cualquier organización para publicar un '
          'evento. Se cobra al generar el QR desde el panel.',
      label: 'Precio en BOB',
      initialValue: current == null
          ? ''
          : current.toStringAsFixed(current == current.roundToDouble() ? 0 : 2),
      confirmLabel: 'Guardar',
    );
    if (text == null || !mounted) return;

    final validation = AppValidators.amount(text);
    if (validation != null) {
      AppFeedback.warning(context, validation);
      return;
    }
    final price = double.parse(text.trim().replaceAll(',', '.'));

    setState(() => _busy = true);
    try {
      await _adminService.setEventPublicationPrice(price);
      await _load();
      if (mounted) AppFeedback.success(context, 'Precio actualizado.');
    } catch (e) {
      if (mounted) AppFeedback.error(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editWebhook() async {
    final url = await showAppPrompt(
      context,
      title: 'Webhook global',
      message:
          'URL HTTPS pública en el puerto 443. Sin redirecciones, '
          'parámetros ni IPs privadas.',
      label: 'URL del webhook',
      confirmLabel: 'Guardar',
    );
    if (url == null || !mounted) return;

    final validation = AppValidators.httpsUrl(url);
    if (validation != null) {
      AppFeedback.warning(context, validation);
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await _service.webhookSet(
        url: url.trim(),
        enabled: true,
        rotate: _webhookUrl.isEmpty,
      );
      await _load();
      if (!mounted) return;

      final secret = _findSecret(result);
      if (secret != null) {
        await showWebhookSecretDialog(context, secret);
      } else {
        AppFeedback.success(context, 'Webhook actualizado.');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleWebhook() async {
    if (_webhookUrl.isEmpty) return _editWebhook();
    if (_webhookEnabled) {
      final ok = await showAppConfirm(
        context,
        title: 'Pausar webhook',
        message:
            'Mientras esté pausado, PagosYa no confirmará pagos automáticamente. '
            '¿Querés pausarlo igual?',
        confirmLabel: 'Pausar',
        isDangerous: true,
        icon: Icons.pause_circle_outline,
      );
      if (!ok || !mounted) return;
    }
    await _run(() async {
      await _service.webhookSet(url: _webhookUrl, enabled: !_webhookEnabled);
    }, _webhookEnabled ? 'Webhook pausado.' : 'Webhook activado.');
  }

  Future<void> _retryEvent(String eventId) => _run(() async {
    await _service.webhookRetry(eventId);
  }, 'Reintento solicitado.');

  String? _findSecret(Map<String, dynamic> result) {
    const keys = ['secret', 'webhook_secret', 'signing_secret'];
    final nested = result['webhook'];
    final sources = <Map>[result, if (nested is Map) nested];
    for (final source in sources) {
      for (final key in keys) {
        final value = source[key];
        if (value is String && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _webhookSource {
    final nested = _webhook?['webhook'];
    return nested is Map ? Map<String, dynamic>.from(nested) : _webhook;
  }

  String get _webhookUrl => _webhookSource?['url']?.toString() ?? '';
  bool get _webhookEnabled => _webhookSource?['enabled'] == true;

  double? get _eventPublicationPrice {
    final value = _config?['event_publication_price'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _PagosyaSkeleton();

    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }

    final affiliate = _config?['affiliate_id']?.toString();

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.clamp(0, 1100).toDouble();
        final wide = available >= 900;
        final cardWidth = wide ? (available - 48) / 2 : null;

        final cards = <Widget>[
          PagosyaPlatformCard(
            affiliateId: affiliate,
            bankStatus: _platformSummary?['bank_status']?.toString(),
            busy: _busy,
            error: _platformError,
            onRegister: _registerPlatform,
            onConnectBank: _connectPlatformBank,
            onRefresh: _refreshPlatformBank,
          ),
          PagosyaPlansCard(
            plans: _plans,
            busy: _busy,
            error: _plansError,
            onCreate: _openPlanForm,
            onEdit: _openPlanForm,
            onToggle: _togglePlan,
            onRetry: _load,
          ),
          PagosyaPublicationPriceCard(
            price: _eventPublicationPrice,
            busy: _busy,
            onEdit: _editPublicationPrice,
          ),
          PagosyaPlanCard(overview: _overview, error: _overviewError),
          PagosyaWebhookCard(
            url: _webhookUrl,
            enabled: _webhookEnabled,
            busy: _busy,
            error: _webhookError,
            onEdit: _editWebhook,
            onToggle: _toggleWebhook,
          ),
          PagosyaAccountsCard(accounts: _accounts),
          PagosyaEventsCard(events: _events, busy: _busy, onRetry: _retryEvent),
        ];

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: AppResponsiveBody(
              maxWidth: 1100,
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final card in cards)
                    SizedBox(width: cardWidth ?? double.infinity, child: card),
                ],
              ),
            ),
          ),
        );
      },
    );

    return Column(
      children: [
        if (_busy)
          const LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
        Expanded(child: content),
      ],
    );
  }
}

class _PagosyaSkeleton extends StatelessWidget {
  const _PagosyaSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando panel de PagosYa',
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, _) => Container(
          height: 150,
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.divider),
          ),
        ),
      ),
    );
  }
}
