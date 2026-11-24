import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/class_presentation.dart';
import '../../../core/utils/public_urls.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_access.dart';
import '../../../providers/dance_class_provider.dart';

/// Tarjeta de una clase dentro de una grilla semanal.
///
/// [dense] se usa cuando en la misma celda (día + hora) hay más de una clase:
/// se muestra una sola línea (título) y el alto lo fija la celda, para que
/// nunca desborde cuando hay 3 o 4 clases a la misma hora.
///
/// [showOrganization] reemplaza la etiqueta de ritmo por el logo y el nombre de
/// la academia; se usa en "Mis clases", donde el alumno mezcla organizaciones.
class ScheduleClassCard extends StatelessWidget {
  const ScheduleClassCard({
    super.key,
    required this.entry,
    required this.themeColor,
    required this.styleTag,
    required this.onTap,
    this.dense = false,
    this.access,
    this.showOrganization = false,
  });

  final OrgScheduleEntry entry;
  final Color themeColor;
  final String styleTag;
  final VoidCallback onTap;
  final bool dense;

  /// Tipo de acceso del alumno (solo en "Mis clases").
  final ClassAccess? access;

  /// Muestra logo + nombre de la academia (solo en "Mis clases").
  final bool showOrganization;

  @override
  Widget build(BuildContext context) {
    final danceClass = entry.danceClass;
    final schedule = entry.schedule;
    final isDraft = !danceClass.isPublished;
    final start = hhmm(schedule.startTime);
    final end = hhmm(schedule.endTime);
    final instructor =
        schedule.instructorName ?? danceClass.instructorName ?? 'Sin profesor';
    final statusLabel = isDraft ? 'Borrador' : 'Publicada';
    final accessLabel = access != null ? ', acceso ${access!.label}' : '';
    final orgLabel = showOrganization && danceClass.organizationName.isNotEmpty
        ? ', ${danceClass.organizationName}'
        : '';

    final semanticsLabel =
        '${danceClass.title}, $styleTag$orgLabel, $statusLabel$accessLabel. '
        'Abrir detalle de la clase.';
    final tooltip =
        '${danceClass.title}\n$start – $end · $instructor\n'
        '${showOrganization && danceClass.organizationName.isNotEmpty ? '${danceClass.organizationName}\n' : ''}'
        '$statusLabel$accessLabel';

    if (dense) {
      return Semantics(
        button: true,
        label: semanticsLabel,
        child: Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 600),
          child: Material(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: themeColor.withValues(alpha: isDraft ? 0.28 : 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    if (showOrganization)
                      _OrgAvatar(
                        logoUrl: organizationLogoUrl(
                          danceClass.organizationLogoUrl,
                        ),
                        size: 11,
                      )
                    else
                      _GenreDot(color: themeColor, isDraft: isDraft, size: 5),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        danceClass.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isDraft) ...[
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.edit_note_rounded,
                        size: 11,
                        color: AppColors.warning,
                      ),
                    ] else if (access != null) ...[
                      const SizedBox(width: 3),
                      Icon(access!.icon, size: 11, color: access!.color),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: themeColor.withValues(alpha: isDraft ? 0.28 : 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (showOrganization &&
                          danceClass.organizationName.isNotEmpty) ...[
                        _OrgAvatar(
                          logoUrl: organizationLogoUrl(
                            danceClass.organizationLogoUrl,
                          ),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            danceClass.organizationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else ...[
                        _GenreDot(color: themeColor, isDraft: isDraft, size: 6),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            styleTag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        danceClass.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textOnBg,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  if (isDraft)
                    const _DraftTag()
                  else if (access != null)
                    _AccessPill(access: access!)
                  else if (danceClass.price > 0)
                    Text(
                      '${danceClass.price.toInt()} Bs',
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo de la academia, con ícono de local como fallback.
class _OrgAvatar extends StatelessWidget {
  const _OrgAvatar({required this.logoUrl, required this.size});

  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.storefront_rounded,
          size: size * 0.72,
          color: AppColors.primary,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: size,
          height: size,
          color: context.divider.withValues(alpha: 0.25),
        ),
        errorWidget: (_, _, _) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.storefront_rounded,
            size: size * 0.72,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Pastilla con el tipo de acceso del alumno (VIP / Mensual / N sesiones).
class _AccessPill extends StatelessWidget {
  const _AccessPill({required this.access});

  final ClassAccess access;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: access.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(access.icon, size: 10, color: access.color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              access.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreDot extends StatelessWidget {
  const _GenreDot({
    required this.color,
    required this.isDraft,
    required this.size,
  });

  final Color color;
  final bool isDraft;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDraft ? color.withValues(alpha: 0.45) : color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Marca de estado no publicada. No depende solo del color: ícono + texto.
class _DraftTag extends StatelessWidget {
  const _DraftTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.edit_note_rounded,
            size: 10,
            color: AppColors.warning,
          ),
          const SizedBox(width: 2),
          Text(
            'Borrador',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
