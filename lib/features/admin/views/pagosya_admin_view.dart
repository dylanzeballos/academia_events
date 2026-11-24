// lib/features/admin/views/pagosya_admin_view.dart
import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/services/pagosya_service.dart';
import '../../../shared/widgets/app_confirm_dialog.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_responsive_body.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/pagosya_admin_cards.dart';
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

  Map<String, dynamic>? _config;
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _webhook;
  List<Map<String, dynamic>> _accounts = const [];
  List<Map<String, dynamic>> _events = const [];
  String? _overviewError;
  String? _webhookError;

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
      _overview = null;
      _webhook = null;
    });

    try {
      final config = await supabase
          .from('payment_platform_config')
          .select('affiliate_id, external_id, updated_at')
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingIndicator();

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final affiliate = _config?['affiliate_id']?.toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.clamp(0, 1100).toDouble();
        final wide = available >= 900;
        final cardWidth = wide ? (available - 48) / 2 : null;

        final cards = <Widget>[
          PagosyaPlatformCard(
            affiliateId: affiliate,
            busy: _busy,
            onRegister: _registerPlatform,
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
  }
}
