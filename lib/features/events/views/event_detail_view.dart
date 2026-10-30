// lib/features/events/views/event_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/event_model.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/layout_mode_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../widgets/detail/event_detail_header.dart';
import '../widgets/detail/event_location_section.dart';
import '../widgets/detail/event_publish_action_bar.dart';
import '../widgets/detail/event_schedule_card.dart';
import '../widgets/detail/event_ticket_action_bar.dart';
import '../widgets/detail/event_tickets_section.dart';
import 'event_attendance_view.dart';
import 'event_access_points_view.dart';

class EventDetailView extends ConsumerWidget {
  const EventDetailView({super.key, required this.eventId});

  final String eventId;

  Future<void> _deleteEvent(
    BuildContext context,
    WidgetRef ref,
    EventModel event,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text(
          'Eliminar evento',
          style: TextStyle(color: context.textOnBg),
        ),
        content: Text(
          '¿Estás seguro de eliminar "${event.title}"? Esta acción borrará todas sus entradas, ubicaciones y datos asociados.',
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(eventsRepositoryProvider).deleteEvent(event.id);
      ref.invalidate(orgEventsProvider);
      ref.invalidate(allEventsProvider);
      ref.invalidate(weekEventsProvider);

      if (context.mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Evento eliminado correctamente'),
            backgroundColor: context.cardBg,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.error(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final isAcademyMode =
        ref.watch(effectiveLayoutModeProvider) == AppLayoutMode.academy;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: eventAsync.when(
          data: (event) => Text(
            event.title,
            style: TextStyle(
              color: context.textOnBg,
              fontWeight: FontWeight.bold,
            ),
          ),
          loading: () =>
              Text('Cargando...', style: TextStyle(color: context.textMuted)),
          error: (_, _) =>
              Text('Evento', style: TextStyle(color: context.textOnBg)),
        ),
        actions: [
          if (isAcademyMode)
            eventAsync.maybeWhen(
              data: (event) => IconButton(
                tooltip: 'Puntos de acceso',
                icon: Icon(
                  Icons.meeting_room_outlined,
                  color: context.textOnBg,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventAccessPointsView(
                      eventId: event.id,
                      organizationId: event.organizationId,
                      eventTitle: event.title,
                    ),
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          if (isAcademyMode)
            eventAsync.maybeWhen(
              data: (event) => IconButton(
                tooltip: 'Ver asistencia',
                icon: Icon(Icons.assessment_outlined, color: context.textOnBg),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventAttendanceView(
                      eventId: event.id,
                      eventTitle: event.title,
                    ),
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          if (isAcademyMode)
            eventAsync.maybeWhen(
              data: (event) => IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () => _deleteEvent(context, ref, event),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: eventAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorState(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
        ),
        data: (event) =>
            _EventDetailContent(event: event, isAcademyMode: isAcademyMode),
      ),
      bottomNavigationBar: eventAsync.maybeWhen(
        data: (event) {
          if (isAcademyMode) {
            if (event.status == 'draft') {
              return EventPublishActionBar(event: event);
            }
            return null;
          }

          if (event.status == 'published') {
            return EventTicketActionBar(event: event);
          }

          return null;
        },
        orElse: () => null,
      ),
    );
  }
}

class _EventDetailContent extends StatelessWidget {
  const _EventDetailContent({required this.event, required this.isAcademyMode});

  final EventModel event;
  final bool isAcademyMode;

  Future<void> _launchPhone(BuildContext context, String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      final Uri url = Uri.parse('tel:$cleanPhone');
      if (!await launchUrl(url)) {
        if (context.mounted) {
          AppFeedback.warning(context, 'No se pudo abrir la app de llamadas');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.error(context, 'Error al intentar llamar: $e');
      }
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String phone) async {
    try {
      var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');

      // Normalizar número boliviano (8 dígitos) agregando el código de país
      if (digits.length == 8) {
        digits = '591$digits';
      }

      // 1. Intentar con el esquema nativo de la app instalada
      final Uri nativeUri = Uri.parse('whatsapp://send?phone=$digits');
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri);
        return;
      }

      // 2. Respaldo universal por navegador
      final Uri webUri = Uri.parse('https://wa.me/$digits');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        AppFeedback.error(context, 'No se pudo abrir WhatsApp');
      }
    }
  }

  Future<void> _launchPdf(BuildContext context, String rawUrl) async {
    try {
      final cleanUrl = rawUrl.trim();
      if (cleanUrl.isEmpty) {
        if (context.mounted) {
          AppFeedback.warning(context, 'No hay enlace de documento disponible');
        }
        return;
      }

      final Uri directUri = Uri.parse(cleanUrl);

      // 1. Intentar abrir directamente con el visor nativo / navegador
      bool launched = false;
      try {
        launched = await launchUrl(
          directUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        launched = false;
      }

      // 2. Respaldo para Android mediante el visor web de documentos
      if (!launched) {
        final Uri viewerUri = Uri.parse(
          'https://docs.google.com/viewer?url=${Uri.encodeComponent(cleanUrl)}',
        );
        launched = await launchUrl(
          viewerUri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched && context.mounted) {
        AppFeedback.error(
          context,
          'No se pudo abrir el archivo PDF. Verifica tu conexión.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.error(context, 'Error al abrir el documento: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.colorForOrganization(event.organizationId);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAcademyMode) _OrganizerStatusBanner(status: event.status),

          EventDetailHeader(event: event, accentColor: accent),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Horario del Evento
                EventScheduleCard(event: event, accentColor: accent),

                // 2. Capacidad y Asistencia
                if (event.capacity != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.divider),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.groups_outlined, size: 20, color: accent),
                        const SizedBox(width: 10),
                        Text(
                          'Capacidad permitida:',
                          style: TextStyle(color: context.textMuted, fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          '${event.capacity} personas',
                          style: TextStyle(
                            color: context.textOnBg,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 3. Teléfono de Contacto Directo
                if (event.contactPhone != null &&
                    event.contactPhone!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.phone_in_talk_rounded,
                            color: AppColors.success,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contacto / Informes',
                                style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                event.contactPhone!,
                                style: TextStyle(
                                  color: context.textOnBg,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Llamar',
                          icon: const Icon(Icons.call, color: AppColors.primary, size: 20),
                          onPressed: () => _launchPhone(context, event.contactPhone!),
                        ),
                        IconButton(
                          tooltip: 'WhatsApp',
                          icon: const Icon(Icons.chat_outlined, color: AppColors.success, size: 20),
                          onPressed: () => _launchWhatsApp(context, event.contactPhone!),
                        ),
                      ],
                    ),
                  ),
                ],

                // 4. Documento PDF / Reglamento
                if (event.rulesPdfUrl != null &&
                    event.rulesPdfUrl!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _launchPdf(context, event.rulesPdfUrl!),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reglamento y Código de Vestimenta',
                                  style: TextStyle(
                                    color: context.textOnBg,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Toca para ver el documento oficial del evento',
                                  style: TextStyle(color: context.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.open_in_new_rounded, size: 18, color: accent),
                        ],
                      ),
                    ),
                  ),
                ],

                // 5. Descripción del Evento
                if (event.description != null &&
                    event.description!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Descripción',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description!,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],

                // 6. Fases de Precios / Entradas
                const SizedBox(height: 20),
                EventTicketsSection(event: event, accentColor: accent),

                // 7. Ubicación y Mapa
                const SizedBox(height: 20),
                EventLocationSection(event: event, accentColor: accent),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizerStatusBanner extends StatelessWidget {
  const _OrganizerStatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isDraft = status == 'draft';
    final bgColor = isDraft ? AppColors.warning : AppColors.success;

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            isDraft ? Icons.edit_note : Icons.check_circle_outline,
            color: AppColors.onPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isDraft
                  ? 'Borrador: Este evento aún no es visible para el público.'
                  : 'Publicado: Visible y habilitado para compra de entradas.',
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}