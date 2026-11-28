// lib/features/tickets/widgets/class_pass_purchase_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_enrollment_model.dart';
import '../../../data/models/pagosya_checkout_model.dart';
import '../../../data/models/purchasable_session_model.dart';
import '../../../data/models/vip_plan_model.dart';
import '../../../data/services/pagosya_service.dart';
import '../../../data/services/ticket_service.dart';
import '../../../providers/checkin_provider.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../providers/class_purchase_provider.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../tickets/views/pagosya_checkout_screen.dart';

enum _PurchaseMode { sessions, monthly, vip }

class ClassPassPurchaseSheet extends ConsumerStatefulWidget {
  const ClassPassPurchaseSheet({super.key, required this.enrollment});

  final ClassEnrollmentModel enrollment;

  @override
  ConsumerState<ClassPassPurchaseSheet> createState() =>
      _ClassPassPurchaseSheetState();
}

class _ClassPassPurchaseSheetState
    extends ConsumerState<ClassPassPurchaseSheet> {
  _PurchaseMode _mode = _PurchaseMode.sessions;
  final Set<String> _selectedSessions = {};
  bool _busy = false;
  String? _error;

  /// Oferta de pase mensual (null si la clase no la ofrece).
  Map<String, dynamic>? _monthlyOffer;
  String? _monthlyReason;
  bool _loadingMonthly = true;

  /// `null` mientras se cargan las sesiones; `false` si no hay ninguna.
  bool? _hasSessions;

  @override
  void initState() {
    super.initState();
    _loadMonthlyOffer();
  }

  Future<void> _loadMonthlyOffer() async {
    if (!_loadingMonthly) {
      setState(() => _loadingMonthly = true);
    }
    try {
      final data = await ref
          .read(classPurchaseRepositoryProvider)
          .quoteMonthly(widget.enrollment.id);
      if (!mounted) return;
      final offered = data['success'] == true;
      setState(() {
        _monthlyOffer = offered ? data : null;
        _monthlyReason = offered ? null : (data['reason'] as String?);
        _loadingMonthly = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _monthlyOffer = null;
        _monthlyReason = friendlyError(e);
        _loadingMonthly = false;
      });
    }
  }

  String _money(num amount, String currency) {
    final symbol = currency.trim().toUpperCase() == 'BOB' ? 'Bs. ' : '';
    final value = amount.toStringAsFixed(2);
    return symbol.isNotEmpty ? '$symbol$value' : '$value $currency';
  }

  Future<void> _pay(_PurchaseMode mode) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      Future<PagosyaCheckout> requestCheckout() {
        switch (mode) {
          case _PurchaseMode.sessions:
            return const PagosyaService().createCheckout(
              kind: 'class_pass',
              referenceId: widget.enrollment.id,
              sessionIds: _selectedSessions.toList(),
            );
          case _PurchaseMode.monthly:
            return const PagosyaService().createCheckout(
              kind: 'class_monthly',
              referenceId: widget.enrollment.id,
            );
          case _PurchaseMode.vip:
            final orgId = widget.enrollment.organizationId;
            if (orgId == null) {
              throw const TicketException(
                'No se pudo identificar la organización.',
              );
            }
            return const PagosyaService().createCheckout(
              kind: 'vip_membership',
              referenceId: orgId,
            );
        }
      }

      if (mode == _PurchaseMode.sessions && _selectedSessions.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'Selecciona al menos una sesión.';
        });
        return;
      }

      final data = await requestCheckout();

      if (!mounted) return;

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PagosyaCheckoutScreen(checkout: data),
        ),
      );

      if (paid == true) {
        ref.invalidate(myClassPassesProvider);
        ref.invalidate(myClassTicketsProvider);
        ref.invalidate(classPassQuoteProvider(widget.enrollment.id));
        ref.invalidate(myVipMembershipsProvider);
        ref.invalidate(myEnrollmentsProvider);
        ref.invalidate(myClassesOverviewProvider);
        if (mounted) Navigator.of(context).pop(true);
      }
    } on TicketException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgId = widget.enrollment.organizationId;
    final vipPlan = orgId == null
        ? null
        : ref.watch(vipPlanProvider(orgId)).value;

    final hasMonthly = _monthlyOffer != null;
    final hasVip = vipPlan != null;
    final hasSessions = _hasSessions ?? true;

    // Solo las opciones que la academia realmente ofrece.
    final modes = <_PurchaseMode>[
      if (hasSessions) _PurchaseMode.sessions,
      if (hasMonthly) _PurchaseMode.monthly,
      if (hasVip) _PurchaseMode.vip,
    ];

    // Si la opción elegida ya no está disponible, cae en otra.
    final mode = modes.contains(_mode)
        ? _mode
        : (modes.isEmpty ? _PurchaseMode.sessions : modes.first);

    final hasOfferForMode = switch (mode) {
      _PurchaseMode.sessions => hasSessions,
      _PurchaseMode.monthly => hasMonthly,
      _PurchaseMode.vip => hasVip,
    };
    final canPress =
        hasOfferForMode &&
        !_busy &&
        (mode != _PurchaseMode.sessions || _selectedSessions.isNotEmpty);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Comprar acceso',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.enrollment.classTitle ?? 'Clase',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (modes.length > 1) ...[
                SegmentedButton<_PurchaseMode>(
                  segments: [
                    if (hasSessions)
                      const ButtonSegment(
                        value: _PurchaseMode.sessions,
                        label: Text('Sesiones'),
                        icon: Icon(Icons.event_available, size: 18),
                      ),
                    if (hasMonthly)
                      const ButtonSegment(
                        value: _PurchaseMode.monthly,
                        label: Text('Mensual'),
                        icon: Icon(Icons.calendar_month, size: 18),
                      ),
                    if (hasVip)
                      const ButtonSegment(
                        value: _PurchaseMode.vip,
                        label: Text('VIP'),
                        icon: Icon(Icons.stars_rounded, size: 18),
                      ),
                  ],
                  selected: {mode},
                  onSelectionChanged: _busy
                      ? null
                      : (value) => setState(() {
                          _mode = value.first;
                          _error = null;
                        }),
                ),
                const SizedBox(height: 18),
              ],
              if (!hasOfferForMode)
                _NoOfferMessage(reason: _monthlyReason)
              else ...[
                if (mode == _PurchaseMode.sessions)
                  _SessionsSelector(
                    enrollment: widget.enrollment,
                    selected: _selectedSessions,
                    money: _money,
                    onAvailability: (has) {
                      if (_hasSessions == has) return;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _hasSessions = has);
                      });
                    },
                    onToggle: (id) => setState(() {
                      if (!_selectedSessions.add(id)) {
                        _selectedSessions.remove(id);
                      }
                    }),
                  )
                else if (mode == _PurchaseMode.monthly)
                  _MonthlyCard(
                    offer: _monthlyOffer,
                    loading: _loadingMonthly,
                    reason: _monthlyReason,
                    money: _money,
                    onRetry: _loadMonthlyOffer,
                  )
                else
                  _VipCard(organizationId: orgId, money: _money),
                const SizedBox(height: 18),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.radiusMedium,
                      ),
                    ),
                  ),
                  onPressed: canPress ? () => _pay(mode) : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.qr_code_2),
                  label: Text(
                    _busy ? 'Generando cobro...' : 'Pagar con QR',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'El acceso se activa automáticamente al confirmarse el pago.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Se muestra cuando la academia no ofrece ninguna forma de compra.
class _NoOfferMessage extends StatelessWidget {
  const _NoOfferMessage({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceHeader,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: context.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.block_rounded, size: 28, color: context.textMuted),
          const SizedBox(height: 8),
          Text(
            'Esta clase no tiene acceso disponible para comprar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (reason != null && reason!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              reason!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionsSelector extends ConsumerStatefulWidget {
  const _SessionsSelector({
    required this.enrollment,
    required this.selected,
    required this.money,
    required this.onToggle,
    this.onAvailability,
  });

  final ClassEnrollmentModel enrollment;
  final Set<String> selected;
  final String Function(num, String) money;
  final ValueChanged<String> onToggle;

  /// Avisa si la clase tiene o no sesiones comprables.
  final ValueChanged<bool>? onAvailability;

  @override
  ConsumerState<_SessionsSelector> createState() => _SessionsSelectorState();
}

class _SessionsSelectorState extends ConsumerState<_SessionsSelector> {
  /// Una clase recurrente puede tener 150+ sesiones al año: se piden de a
  /// bloques a la base y, además, se muestran de a 3 en pantalla.
  static const int _pageSize = 12;
  static const int _visibleStep = 3;

  final List<PurchasableSession> _sessions = [];
  int _visibleCount = _visibleStep;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;

  /// Filtro por defecto: próximas 4 semanas (nadie compra a 10 meses).
  bool _onlyNextWeeks = true;

  @override
  void initState() {
    super.initState();
    _loadPage(reset: true);
  }

  Future<void> _loadPage({required bool reset}) async {
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _visibleCount = _visibleStep;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final repo = ref.read(classPurchaseRepositoryProvider);
      final page = await repo.fetchPurchasableSessions(
        widget.enrollment.danceClassId,
        limit: _pageSize + 1,
        offset: reset ? 0 : _sessions.length,
        weeks: _onlyNextWeeks ? 4 : null,
      );
      if (!mounted) return;

      final hasMore = page.length > _pageSize;
      final slice = hasMore ? page.take(_pageSize).toList() : page;

      setState(() {
        if (reset) _sessions.clear();
        _sessions.addAll(slice);
        _hasMore = hasMore;
        _loading = false;
        _loadingMore = false;
      });
      widget.onAvailability?.call(_sessions.isNotEmpty || _hasMore);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = friendlyError(e);
      });
    }
  }

  void _setFilter(bool onlyNextWeeks) {
    if (_onlyNextWeeks == onlyNextWeeks) return;
    setState(() => _onlyNextWeeks = onlyNextWeeks);
    _loadPage(reset: true);
  }

  /// Cuántas se van a revelar en el próximo "Ver más" (3, o menos si quedan
  /// pocas descargadas).
  int get _nextReveal {
    final hidden = _sessions.length - _visibleCount;
    return hidden < _visibleStep ? hidden : _visibleStep;
  }

  /// Muestra 3 más. Si ya están descargadas, es instantáneo; si no, pide otra
  /// página a la base antes de revelar.
  Future<void> _showMore() async {
    if (_visibleCount < _sessions.length) {
      final next = _visibleCount + _visibleStep;
      setState(
        () => _visibleCount = next > _sessions.length ? _sessions.length : next,
      );
      return;
    }

    if (!_hasMore || _loadingMore) return;
    await _loadPage(reset: false);
    if (!mounted) return;
    final next = _visibleCount + _visibleStep;
    setState(
      () => _visibleCount = next > _sessions.length ? _sessions.length : next,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
            onPressed: () => _loadPage(reset: true),
          ),
        ],
      );
    }

    final total = _sessions
        .where((s) => widget.selected.contains(s.id))
        .fold<double>(0, (sum, s) => sum + s.pricePerSession);
    final currency = _sessions.isNotEmpty ? _sessions.first.currency : 'BOB';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Próximas 4 semanas')),
            ButtonSegment(value: false, label: Text('Todas')),
          ],
          selected: {_onlyNextWeeks},
          showSelectedIcon: false,
          onSelectionChanged: (value) => _setFilter(value.first),
        ),
        const SizedBox(height: 10),
        // Resumen arriba: queda visible aunque la lista sea larga.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.selected.isEmpty
                    ? 'Elegí tus sesiones'
                    : '${widget.selected.length} sesión(es)',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.selected.isNotEmpty)
                Text(
                  widget.money(total, currency),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _onlyNextWeeks
                  ? 'No hay sesiones en las próximas 4 semanas. Probá con "Todas".'
                  : 'No hay sesiones programadas para comprar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          )
        else ...[
          for (final session in _sessions.take(_visibleCount))
            _SessionChoice(
              session: session,
              checked: widget.selected.contains(session.id),
              money: widget.money,
              onChanged: session.isSelectable
                  ? () => widget.onToggle(session.id)
                  : null,
            ),
          const SizedBox(height: 4),
          if (_visibleCount < _sessions.length || _hasMore)
            OutlinedButton.icon(
              icon: _loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded, size: 18),
              label: Text(
                _sessions.length > _visibleCount
                    ? 'Ver $_nextReveal más'
                    : 'Ver más sesiones',
              ),
              onPressed: _loadingMore ? null : _showMore,
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'No hay más sesiones disponibles.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted, fontSize: 11.5),
              ),
            ),
        ],
      ],
    );
  }
}

class _SessionChoice extends StatelessWidget {
  const _SessionChoice({
    required this.session,
    required this.checked,
    required this.money,
    required this.onChanged,
  });

  final PurchasableSession session;
  final bool checked;
  final String Function(num, String) money;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE d MMM', 'es').format(session.sessionDate);
    final start = DateFormat('HH:mm').format(session.startAt);
    final end = DateFormat('HH:mm').format(session.endAt);

    return CheckboxListTile(
      value: checked,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primary,
      title: Text(
        '$date · $start-$end',
        style: TextStyle(color: context.textOnBg, fontSize: 14),
      ),
      subtitle: Text(
        session.alreadyPurchased
            ? 'Ya comprada'
            : session.isFull
            ? 'Sesión llena'
            : session.slotsLeft == null
            ? 'Cupos disponibles'
            : '${session.slotsLeft} cupos disponibles',
        style: TextStyle(
          color: session.alreadyPurchased
              ? AppColors.success
              : session.isFull
              ? AppColors.error
              : context.textMuted,
          fontSize: 12,
        ),
      ),
      secondary: Text(
        money(session.pricePerSession, session.currency),
        style: TextStyle(
          color: context.textOnBg,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MonthlyCard extends StatelessWidget {
  const _MonthlyCard({
    required this.offer,
    required this.loading,
    required this.reason,
    required this.money,
    required this.onRetry,
  });

  final Map<String, dynamic>? offer;
  final bool loading;
  final String? reason;
  final String Function(num, String) money;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final data = offer;
    if (data == null) {
      return Column(
        children: [
          Text(
            reason?.trim().isNotEmpty == true
                ? reason!
                : 'Esta clase no ofrece pase mensual.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      );
    }

    final price = (data['price'] as num?) ?? 0;
    final sessions = (data['session_count'] as num?)?.toInt() ?? 0;
    final currency = (data['currency'] as String?) ?? 'BOB';
    final start = data['period_start'] != null
        ? DateTime.tryParse(data['period_start'] as String)?.toLocal()
        : null;
    final end = data['period_end'] != null
        ? DateTime.tryParse(data['period_end'] as String)?.toLocal()
        : null;

    return _OfferCard(
      icon: Icons.calendar_month,
      title: 'Pase mensual de la clase',
      subtitle: 'Acceso a todas las sesiones de esta clase durante el período.',
      rows: [
        if (start != null && end != null)
          'Vigencia: ${DateFormat('d MMM yyyy', 'es').format(start)} '
              'al ${DateFormat('d MMM yyyy', 'es').format(end)}',
        '$sessions sesiones programadas en el período',
        'Precio mensual: ${money(price, currency)}',
      ],
    );
  }
}

class _VipCard extends ConsumerWidget {
  const _VipCard({required this.organizationId, required this.money});

  final String? organizationId;
  final String Function(num, String) money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (organizationId == null) {
      return Text(
        'No se pudo identificar la organización.',
        style: TextStyle(color: context.textMuted, fontSize: 13),
      );
    }
    final planAsync = ref.watch(vipPlanProvider(organizationId!));
    return planAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, _) => Text(
        'No se pudo cargar el pase VIP.',
        style: TextStyle(color: context.textMuted, fontSize: 13),
      ),
      data: (plan) {
        if (plan == null) {
          return Text(
            'Esta organización todavía no ofrece pase VIP.',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          );
        }
        return _VipOffer(plan: plan, money: money);
      },
    );
  }
}

class _VipOffer extends StatelessWidget {
  const _VipOffer({required this.plan, required this.money});

  final VipPlanModel plan;
  final String Function(num, String) money;

  @override
  Widget build(BuildContext context) {
    final names = plan.classes.map((c) => c.title).take(6).join(', ');
    return _OfferCard(
      icon: Icons.stars_rounded,
      title: plan.name,
      subtitle:
          plan.description ??
          (plan.includesAllClasses
              ? 'Acceso a todas las clases publicadas de la academia.'
              : 'Acceso a las clases de los ritmos seleccionados.'),
      rows: [
        if (plan.periodStart != null && plan.periodEnd != null)
          'Vigencia: ${DateFormat('d MMM yyyy', 'es').format(plan.periodStart!)} '
              'al ${DateFormat('d MMM yyyy', 'es').format(plan.periodEnd!)}',
        '${plan.classCount} clases incluidas',
        if (names.isNotEmpty) names,
        'Precio mensual: ${money(plan.priceMonthly, plan.currency)}',
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      row,
                      style: TextStyle(color: context.textMuted, fontSize: 12),
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
