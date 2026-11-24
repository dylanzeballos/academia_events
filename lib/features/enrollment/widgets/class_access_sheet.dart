// lib/features/enrollment/widgets/class_access_sheet.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/public_urls.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_access.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/class_ticket_model.dart';
import '../../../providers/checkin_provider.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../tickets/widgets/class_pass_purchase_sheet.dart';

/// Acceso a una clase desde "Mis clases": muestra el QR de la próxima sesión
/// (o el estado del pase VIP/mensual) sin salir del horario.
class ClassAccessSheet extends ConsumerWidget {
  const ClassAccessSheet({
    super.key,
    required this.danceClass,
    required this.access,
    required this.enrollmentId,
  });

  final ClassModel danceClass;
  final ClassAccess access;
  final String enrollmentId;

  static Future<void> show(
    BuildContext context, {
    required ClassModel danceClass,
    required ClassAccess access,
    required String enrollmentId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.cardBg,
      builder: (_) => ClassAccessSheet(
        danceClass: danceClass,
        access: access,
        enrollmentId: enrollmentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myClassTicketsProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(danceClass: danceClass),
                  const SizedBox(height: 12),
                  _AccessBadge(access: access),
                  const SizedBox(height: 16),
                  ticketsAsync.when(
                    loading: () =>
                        const SizedBox(height: 180, child: LoadingIndicator()),
                    error: (e, _) => AppErrorState(
                      message: friendlyError(e),
                      onRetry: () => ref.invalidate(myClassTicketsProvider),
                    ),
                    data: (tickets) => _EntrySection(
                      tickets: _ticketsForClass(tickets),
                      access: access,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_note_outlined, size: 18),
                      label: const Text('Sesiones y pases'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textOnBg,
                        side: BorderSide(color: context.divider),
                        minimumSize: const Size.fromHeight(
                          AppSizes.buttonHeight,
                        ),
                      ),
                      onPressed: () {
                        final router = GoRouter.of(context);
                        Navigator.pop(context);
                        router.push('${AppRoutes.myClassDetail}/$enrollmentId');
                      },
                    ),
                  ),
                  if (access.kind == ClassAccessKind.none) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add_card, size: 18),
                        label: const Text('Comprar pase'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          minimumSize: const Size.fromHeight(
                            AppSizes.buttonHeight,
                          ),
                        ),
                        onPressed: () => _openPurchase(context, ref),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tickets futuros de esta clase, el más próximo primero.
  List<ClassTicketModel> _ticketsForClass(List<ClassTicketModel> tickets) {
    final now = DateTime.now();
    final list =
        tickets
            .where(
              (t) =>
                  t.classId == danceClass.id &&
                  !t.sessionStartAt.isBefore(
                    now.subtract(const Duration(hours: 6)),
                  ),
            )
            .toList()
          ..sort((a, b) => a.sessionStartAt.compareTo(b.sessionStartAt));
    return list;
  }

  Future<void> _openPurchase(BuildContext context, WidgetRef ref) async {
    final enrollments = await ref.read(myEnrollmentsProvider.future);
    final enrollment = enrollments
        .where((e) => e.id == enrollmentId)
        .firstOrNull;
    if (enrollment == null || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLarge),
        ),
      ),
      builder: (_) => ClassPassPurchaseSheet(enrollment: enrollment),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.danceClass});

  final ClassModel danceClass;

  @override
  Widget build(BuildContext context) {
    final logoUrl = organizationLogoUrl(danceClass.organizationLogoUrl);
    final orgName = danceClass.organizationName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (orgName.isNotEmpty) ...[
          Row(
            children: [
              if (logoUrl != null)
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: logoUrl,
                    width: 18,
                    height: 18,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const Icon(
                      Icons.storefront_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.storefront_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  orgName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Text(
          danceClass.title,
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _AccessBadge extends StatelessWidget {
  const _AccessBadge({required this.access});

  final ClassAccess access;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: access.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(access.icon, size: 14, color: access.color),
          const SizedBox(width: 6),
          Text(
            switch (access.kind) {
              ClassAccessKind.vip => 'Pase VIP: entrás a todas las clases',
              ClassAccessKind.monthly => 'Pase mensual activo',
              ClassAccessKind.sessions => 'Pase de ${access.label}',
              ClassAccessKind.none => 'Sin pase activo',
            },
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntrySection extends StatelessWidget {
  const _EntrySection({required this.tickets, required this.access});

  final List<ClassTicketModel> tickets;
  final ClassAccess access;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return _InfoMessage(
        icon: Icons.qr_code_2,
        title: access.kind == ClassAccessKind.none
            ? 'No tenés acceso a esta clase'
            : 'Todavía no hay QR para esta clase',
        message: access.kind == ClassAccessKind.none
            ? 'Comprá un pase de sesiones o el pase mensual para generar tu entrada.'
            : 'El QR de cada sesión se genera al comprar el pase y se habilita el día de la clase.',
      );
    }

    final next = tickets.first;
    final upcoming = tickets.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TicketQrCard(ticket: next),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Próximas entradas',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final ticket in upcoming.take(3))
            _UpcomingTicketRow(ticket: ticket),
        ],
      ],
    );
  }
}

class _TicketQrCard extends StatelessWidget {
  const _TicketQrCard({required this.ticket});

  final ClassTicketModel ticket;

  @override
  Widget build(BuildContext context) {
    final start = ticket.sessionStartAt.toLocal();
    final end = ticket.sessionEndAt.toLocal();
    final hasQr = ticket.canShowQr;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceHeader,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider),
      ),
      child: Column(
        children: [
          Text(
            '${DateFormatter.capitalize(DateFormatter.shortDay(start))} '
            '${DateFormatter.dayMonth(start)} · '
            '${DateFormatter.timeRange(start, end)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (hasQr)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: ticket.qrToken!,
                size: 190,
                backgroundColor: Colors.white,
              ),
            )
          else
            Container(
              height: 150,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.divider,
                  style: BorderStyle.solid,
                ),
              ),
              child: Text(
                _statusMessage(ticket),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            hasQr
                ? 'Mostrá este código al personal de la academia.'
                : 'El código se habilita el día de la sesión.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _statusMessage(ClassTicketModel ticket) {
    if (ticket.isUsed) return 'Esta entrada ya se usó.';
    if (ticket.isCancelled) return 'Esta entrada fue cancelada.';
    if (ticket.isExpired) return 'Esta entrada expiró.';
    return 'El QR todavía no está activo.';
  }
}

class _UpcomingTicketRow extends StatelessWidget {
  const _UpcomingTicketRow({required this.ticket});

  final ClassTicketModel ticket;

  @override
  Widget build(BuildContext context) {
    final start = ticket.sessionStartAt.toLocal();
    final end = ticket.sessionEndAt.toLocal();
    final color = ticket.isUsed
        ? context.textMuted
        : ticket.isExpired || ticket.isCancelled
        ? AppColors.error
        : AppColors.success;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.confirmation_number_outlined, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${DateFormatter.capitalize(DateFormatter.shortDay(start))} '
              '${DateFormatter.dayMonth(start)} · '
              '${DateFormatter.timeRange(start, end)}',
              style: TextStyle(color: context.textOnBg, fontSize: 12.5),
            ),
          ),
          Text(
            ticket.statusDisplayName,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceHeader,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: context.textMuted),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
