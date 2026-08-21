import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/event_model.dart';
import '../../../providers/events_provider.dart';
import '../../../providers/layout_mode_provider.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/map_view_screen.dart';

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
        title: const Text('Eliminar evento'),
        content: Text('¿Estás seguro de eliminar "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(eventsRepositoryProvider).deleteEvent(event.id);
      ref.invalidate(orgEventsProvider);
      ref.invalidate(allEventsProvider);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Evento eliminado')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final isAcademyMode =
        ref.watch(effectiveLayoutModeProvider) == AppLayoutMode.academy;

    return Scaffold(
      appBar: AppBar(
        title: eventAsync.when(
          data: (event) => Text(event.title),
          loading: () => const Text('Cargando...'),
          error: (_, _) => const Text('Evento'),
        ),
        actions: [
          if (isAcademyMode)
            eventAsync.maybeWhen(
              data: (event) => IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteEvent(context, ref, event),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: eventAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (event) => _EventDetailBody(event: event),
      ),
    );
  }
}
class _EventDetailBody extends ConsumerWidget {
  const _EventDetailBody({required this.event});

  final EventModel event;

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
                      tag: 'detail-cover-${event.id}',
                    ),
            child: Hero(
              tag: 'detail-cover-${event.id}',
              child: event.coverImageUrl != null
                  ? Image.network(
                      event.coverImageUrl!,
                      height: 220,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              height: 220,
                              color: context.cardBg,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                      errorBuilder: (_, _, _) =>
                          _BannerPlaceholder(color: accent),
                    )
                  : _BannerPlaceholder(color: accent),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Categoría ─────────────────────────────────────
                if (event.categoryName != null) ...[
                  Chip(
                    label: Text(event.categoryName!),
                    backgroundColor: accent.withValues(alpha: 0.12),
                    labelStyle: TextStyle(color: accent, fontSize: 12),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Título y organización ─────────────────────────
                Text(
                  event.title,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
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
                      height: 1.5,
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
                          height: 150,
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
                            ),
                            icon: const Icon(Icons.fullscreen, size: 18),
                            label: const Text('Ampliar mapa'),
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

                // ── QR de pago / ingreso ──────────────────────────
                if (event.qrImageUrl != null) ...[
                  Text(
                    'Código QR',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: () => FullscreenImageViewer.show(
                        context,
                        event.qrImageUrl!,
                        tag: 'detail-qr-${event.id}',
                      ),
                      child: Hero(
                        tag: 'detail-qr-${event.id}',
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMedium),
                          ),
                          child: Image.network(
                            event.qrImageUrl!,
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : const SizedBox(
                                        width: 200,
                                        height: 200,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Toca para agrandar · Escanea para pagar o ingresar',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
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
}

// ─────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────
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
          width: 42,
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
