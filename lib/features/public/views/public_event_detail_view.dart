import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/public_event_model.dart';
import '../../../../data/models/public_ticket_type_model.dart';
import '../../../../providers/public_events_provider.dart';
import '../../../../shared/widgets/fullscreen_image_viewer.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../events/widgets/map_view_screen.dart';

class PublicEventDetailView extends ConsumerWidget {
  const PublicEventDetailView({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(publicEventDetailProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        title: eventAsync.when(
          data: (event) => Text(event?.title ?? 'Evento'),
          loading: () => const Text('Cargando...'),
          error: (_, _) => const Text('Evento'),
        ),
      ),
      body: eventAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.paddingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error cargando el evento',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => ref.invalidate(publicEventDetailProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (event) {
          if (event == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Evento no encontrado',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'El evento puede haber sido cancelado o no es público',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return _PublicEventDetailBody(event: event);
        },
      ),
    );
  }
}

class _PublicEventDetailBody extends ConsumerWidget {
  const _PublicEventDetailBody({required this.event});

  final PublicEventModel event;

  Future<void> _openGoogleMaps(BuildContext context, LatLng point) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${point.latitude},${point.longitude}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps')),
      );
    }
  }

  void _openFullMap(BuildContext context) {
    final location = event.location!;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => MapViewScreen(
          center: LatLng(location.latitude!, location.longitude!),
          title: event.title,
          subtitle: [?location.locationName, ?location.addressLine1]
              .join(' · '),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.calendarEventColors;
    final accent = colors[event.colorIndex % colors.length];
    final location = event.location;
    final hasLocation = location?.latitude != null && location?.longitude != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Banner / foto del evento ────────────────────────────
          GestureDetector(
            onTap: event.coverImageUrl == null
                ? null
                : () => FullscreenImageViewer.show(
                      context,
                      event.coverImageUrl!,
                      tag: 'public-detail-cover-${event.id}',
                    ),
            child: Hero(
              tag: 'public-detail-cover-${event.id}',
              child: event.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: event.coverImageUrl!,
                      height: 220,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        height: 220,
                        color: context.cardBg,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (_, _, _) => _BannerPlaceholder(color: accent),
                    )
                  : _BannerPlaceholder(color: accent),
            ),
          ),

          // Image gallery indicator
          if (event.images.length > 1)
            Container(
              height: 60,
              margin: const EdgeInsets.only(top: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: event.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => FullscreenImageViewer.show(
                      context,
                      event.images[index],
                      tag: 'public-detail-gallery-${event.id}-$index',
                    ),
                    child: Hero(
                      tag: 'public-detail-gallery-${event.id}-$index',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                        child: CachedNetworkImage(
                          imageUrl: event.images[index],
                          width: 80,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: context.divider.withValues(alpha: 0.3),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: context.divider.withValues(alpha: 0.3),
                            child: const Icon(Icons.broken_image, size: 24),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Category & Dance Categories ─────────────────────────────────────
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (event.categoryName != null)
                      Chip(
                        label: Text(event.categoryName!),
                        backgroundColor: accent.withValues(alpha: 0.12),
                        labelStyle: TextStyle(color: accent, fontSize: 12),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ...event.danceCategories.map((cat) => Chip(
                          label: Text(cat.name),
                          backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
                          labelStyle: const TextStyle(color: AppColors.secondary, fontSize: 11),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          avatar: const Icon(Icons.music_note, size: 14, color: AppColors.secondary),
                        )),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Título y organización ─────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (event.organizationLogoUrl != null &&
                        event.organizationLogoUrl!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 12),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.divider),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: event.organizationLogoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              color: context.divider.withValues(alpha: 0.3),
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, _, _) => Icon(
                              Icons.business_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (event.organizationName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 15, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        event.organizationName,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // ── Fecha y hora ──────────────────────────────────
                _InfoCard(
                  icon: Icons.calendar_today_outlined,
                  accent: accent,
                  children: [
                    _InfoRow(
                      icon: Icons.play_arrow_rounded,
                      label: 'Inicio',
                      value:
                          '${DateFormatter.fullDate(event.startTime)} · ${DateFormatter.hourMin(event.startTime)}',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.stop_rounded,
                      label: 'Fin',
                      value:
                          '${DateFormatter.fullDate(event.endTime)} · ${DateFormatter.hourMin(event.endTime)}',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.access_time,
                      label: 'Duración',
                      value: _formatDuration(event.duration),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Descripción ───────────────────────────────────
                if (event.description != null &&
                    event.description!.isNotEmpty) ...[
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
                      color: context.textOnBg.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Ubicación con mapa ────────────────────────────
                if (location?.locationName != null ||
                    location?.addressLine1 != null ||
                    hasLocation) ...[
                  Text(
                    'Ubicación',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasLocation)
                    GestureDetector(
                      onTap: () => _openFullMap(context),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMedium),
                        child: SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(
                                    location!.latitude!,
                                    location.longitude!,
                                  ),
                                  initialZoom: 15,
                                  interactionOptions:
                                      const InteractionOptions(flags: 0),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.example.academia_events',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(
                                          location.latitude!,
                                          location.longitude!,
                                        ),
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Botón de ampliar sobre el mapa
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.cardBg.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fullscreen,
                                          size: 16, color: accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Ampliar',
                                        style: TextStyle(
                                          color: context.textOnBg,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (location?.locationName != null ||
                      location?.addressLine1 != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.place_outlined, color: accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              ?location?.locationName,
                              ?location?.addressLine1,
                              ?location?.city?.name,
                              ?location?.municipality?.name,
                              ?location?.department?.name,
                            ].join('\n'),
                            style: TextStyle(
                              color: context.textOnBg.withValues(alpha: 0.8),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (hasLocation) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openFullMap(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: BorderSide(color: accent),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.fullscreen, size: 18),
                            label: const Text('Ver en mapa'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openGoogleMaps(
                              context,
                              LatLng(
                                location!.latitude!,
                                location.longitude!,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Google Maps'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                ],

                // ── Entradas / Ticket Types ──────────────────────────
                if (event.ticketTypes.isNotEmpty) ...[
                  Text(
                    'Entradas',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...event.ticketTypes.map((ticket) => _TicketCard(
                        ticket: ticket,
                        accent: accent,
                      )),
                  const SizedBox(height: 20),
                ],

                // ── Organizador ────────────────────────────────────
                if (event.organizationName.isNotEmpty) ...[
                  const Divider(),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        backgroundImage: event.organizationLogoUrl != null
                            ? CachedNetworkImageProvider(event.organizationLogoUrl!)
                            : null,
                        child: event.organizationLogoUrl == null
                            ? const Icon(Icons.business_outlined, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.organizationName,
                              style: TextStyle(
                                color: context.textOnBg,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Organizador',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/organizations/detail', extra: event.organizationId),
                        child: const Text('Ver perfil'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}min';
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      color: color.withValues(alpha: 0.25),
      child: Center(
        child: Icon(Icons.image_outlined, color: color, size: 48),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.accent,
    required this.children,
  });

  final IconData icon;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(children: children)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.accent,
  });

  final PublicTicketTypeModel ticket;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isAvailable = ticket.isOnSale && !ticket.isSoldOut;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(
          color: isAvailable ? accent.withValues(alpha: 0.5) : context.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.name,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (ticket.description != null &&
                        ticket.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        ticket.description!,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${ticket.price.toStringAsFixed(0)} ${ticket.currency}',
                style: TextStyle(
                  color: isAvailable ? accent : Colors.grey,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (isAvailable) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Disponible: ${ticket.availableQuantity}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else if (ticket.isSoldOut) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Agotado',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'No disponible',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (ticket.salesStartAt != null || ticket.salesEndAt != null)
                Text(
                  _salesPeriodText(ticket),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _salesPeriodText(PublicTicketTypeModel ticket) {
    final parts = <String>[];
    if (ticket.salesStartAt != null) {
      parts.add('Venta desde: ${ticket.salesStartAt!.day}/${ticket.salesStartAt!.month}');
    }
    if (ticket.salesEndAt != null) {
      parts.add('Hasta: ${ticket.salesEndAt!.day}/${ticket.salesEndAt!.month}');
    }
    return parts.join(' · ');
  }
}