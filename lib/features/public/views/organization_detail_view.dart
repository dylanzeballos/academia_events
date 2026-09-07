import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../../../../data/models/event_model.dart';
import '../../../../data/models/public_event_data.dart';
import '../../../../providers/events_provider.dart';
import '../../../../providers/public_events_provider.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../calendar/widgets/week_day_header.dart';
import '../widgets/event_filters_bar.dart';
import '../widgets/public_event_card.dart';
import '../widgets/public_week_agenda.dart';

/// Página pública con la información de una organización: su próxima semana
/// (calendario), sus próximos eventos y sus clases próximas.
///
/// No requiere autenticación. El acento de color es estable por organización
/// (se computa a partir de su id). Los tabs comparten la semana y el día
/// seleccionados con el calendario público.
class PublicOrganizationDetailView extends ConsumerStatefulWidget {
  const PublicOrganizationDetailView({
    super.key,
    required this.organizationId,
    this.organizationName,
  });

  final String organizationId;
  final String? organizationName;

  @override
  ConsumerState<PublicOrganizationDetailView> createState() =>
      _PublicOrganizationDetailViewState();
}

class _PublicOrganizationDetailViewState
    extends ConsumerState<PublicOrganizationDetailView> {
  @override
  Widget build(BuildContext context) {
    final accent = AppColors.colorForOrganization(widget.organizationId);

    // Los datos completos (logo, cantidad de eventos) vienen de
    // organizationsWithEvents; mientras cargan se usa el nombre recibido por
    // la ruta como fallback.
    final orgsAsync = ref.watch(organizationsWithEventsProvider);
    OrganizationWithEventCount? org;
    for (final o in orgsAsync.value ??
        const <OrganizationWithEventCount>[]) {
      if (o.id == widget.organizationId) {
        org = o;
        break;
      }
    }
    final name = org?.name ?? widget.organizationName ?? 'Organización';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Column(
          children: [
            _OrganizationHeader(
              name: name,
              logoUrl: org?.logoUrl,
              eventCount: org?.eventCount,
              accent: accent,
            ),
            Material(
              color: context.cardBg,
              child: TabBar(
                indicatorColor: accent,
                labelColor: accent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                unselectedLabelColor: Colors.grey,
                dividerColor: context.divider,
                tabs: const [
                  Tab(text: 'Semana'),
                  Tab(text: 'Eventos'),
                  Tab(text: 'Clases'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _OrganizationWeekTab(
                    organizationId: widget.organizationId,
                  ),
                  _OrganizationEventsTab(
                    organizationId: widget.organizationId,
                  ),
                  _OrganizationClassesTab(
                    organizationId: widget.organizationId,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Encabezado con logo, nombre y conteo
// ─────────────────────────────────────────────
class _OrganizationHeader extends StatelessWidget {
  const _OrganizationHeader({
    required this.name,
    required this.logoUrl,
    required this.accent,
    this.eventCount,
  });

  final String name;
  final String? logoUrl;
  final int? eventCount;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final count = eventCount;
    final subtitle = count == null
        ? 'Organización'
        : count == 1
            ? '1 evento publicado'
            : '$count eventos publicados';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: context.divider)),
      ),
      child: Column(
        children: [
          _OrgAvatar(name: name, logoUrl: logoUrl, size: 72, accent: accent),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab Semana: calendario de la org en la semana seleccionada
// ─────────────────────────────────────────────
class _OrganizationWeekTab extends ConsumerWidget {
  const _OrganizationWeekTab({required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedWeek = ref.watch(publicSelectedWeekProvider);
    final selectedDay = ref.watch(publicSelectedDayProvider);
    final eventsAsync = ref.watch(
      organizationWeekEventsProvider(organizationId),
    );
    final weekDays = DateFormatter.weekDays(selectedWeek);

    return Column(
      children: [
        Container(
          color: context.cardBg,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingSmall,
            vertical: AppSizes.paddingSmall,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => ref
                        .read(publicSelectedWeekProvider.notifier)
                        .previousWeek(),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Semana anterior',
                  ),
                  Expanded(
                    child: Text(
                      _weekLabel(weekDays),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const EventFiltersButton(showOrganizationFilter: false),
                  IconButton(
                    onPressed: () => ref
                        .read(publicSelectedWeekProvider.notifier)
                        .nextWeek(),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Semana siguiente',
                  ),
                ],
              ),
              Row(
                  children: weekDays.map((day) {
                    final isSelected =
                        _isSameDay(day, selectedDay);
                    return Expanded(
                      child: WeekDayHeader(
                        day: day,
                        isSelected: isSelected,
                        onTap: () => ref
                            .read(publicSelectedDayProvider.notifier)
                            .setDay(day),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: context.divider),
        Expanded(
          child: eventsAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingLarge),
                child: AppBanner(
                  message: 'Error cargando eventos: $e',
                  type: BannerType.error,
                  onDismiss: () => ref.invalidate(
                    organizationWeekEventsProvider(organizationId),
                  ),
                ),
              ),
            ),
            data: (events) => PublicWeekAgenda(
              weekDays: weekDays,
              events: events,
              selectedDay: selectedDay,
              // El día se selecciona para destacarlo, pero la vista de día
              // detallada no, para no mostrar otras organizaciones.
              onDaySelected: (day) => ref
                  .read(publicSelectedDayProvider.notifier)
                  .setDay(day),
            ),
          ),
        ),
      ],
    );
  }

  String _weekLabel(List<DateTime> weekDays) {
    final first = weekDays.first;
    final last = weekDays.last;
    if (first.month == last.month && first.year == last.year) {
      return DateFormatter.capitalize(DateFormatter.monthYear(first));
    }
    final a = DateFormatter.capitalize(DateFormatter.shortMonth(first));
    final b = DateFormatter.capitalize(DateFormatter.shortMonth(last));
    if (first.year == last.year) {
      return '$a – $b ${first.year}';
    }
    return '$a ${first.year} – $b ${last.year}';
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────
// Tab Eventos: próximos eventos de la organización
// ─────────────────────────────────────────────
class _OrganizationEventsTab extends ConsumerWidget {
  const _OrganizationEventsTab({required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(
      publicOrganizationEventsProvider(organizationId),
    );

    return eventsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          child: AppBanner(
            message: 'Error cargando eventos: $e',
            type: BannerType.error,
            onDismiss: () => ref.invalidate(
              publicOrganizationEventsProvider(organizationId),
            ),
          ),
        ),
      ),
      data: (events) {
        if (events.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Sin eventos próximos',
            subtitle: 'Esta organización no tiene eventos publicados por ahora',
          );
        }
        final isGrid = MediaQuery.of(context).size.width >= 768;
        if (isGrid) {
          return GridView.builder(
            padding: const EdgeInsets.all(AppSizes.paddingMedium),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return PublicEventCard(
                event: event,
                onTap: () => context.push(
                  '${AppRoutes.publicEventDetailBase}/${event.id}',
                ),
              );
            },
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PublicEventCard(
                event: event,
                onTap: () => context.push(
                  '${AppRoutes.publicEventDetailBase}/${event.id}',
                ),
                aspectRatio: 2.2,
                showOrganizationLogo: false,
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Tab Clases: clases próximas de la organización
// ─────────────────────────────────────────────
class _OrganizationClassesTab extends ConsumerWidget {
  const _OrganizationClassesTab({required this.organizationId});

  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(
      organizationUpcomingClassesProvider(organizationId),
    );

    return classesAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          child: AppBanner(
            message: 'Error cargando clases: $e',
            type: BannerType.error,
            onDismiss: () => ref.invalidate(
              organizationUpcomingClassesProvider(organizationId),
            ),
          ),
        ),
      ),
      data: (classes) {
        if (classes.isEmpty) {
          return const _EmptyState(
            icon: Icons.fitness_center_outlined,
            title: 'Sin clases próximas',
            subtitle: 'No hay clases publicadas para los próximos días',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final cls = classes[index];
            return _UpcomingClassTile(cls: cls);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Tile de clase próxima
// ─────────────────────────────────────────────
class _UpcomingClassTile extends StatelessWidget {
  const _UpcomingClassTile({required this.cls});

  final EventModel cls;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.colorForOrganization(cls.organizationId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.divider.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormatter.shortDay(cls.startTime)} '
                  '${DateFormatter.dayMonth(cls.startTime)} · '
                  '${DateFormatter.hourMin(cls.startTime)} – '
                  '${DateFormatter.hourMin(cls.endTime)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Estado vacío
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Avatar redondeado del logo de la organización
// ─────────────────────────────────────────────
class _OrgAvatar extends StatelessWidget {
  const _OrgAvatar({
    required this.name,
    required this.logoUrl,
    required this.size,
    required this.accent,
  });

  final String name;
  final String? logoUrl;
  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    final hasUrl = url != null && url.trim().isNotEmpty;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.15),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: accent,
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.cardBg,
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
      ),
      child: ClipOval(
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: size,
                height: size,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}