import 'package:flutter/material.dart';

import '../../../core/utils/class_presentation.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_access.dart';
import '../../../providers/dance_class_provider.dart';
import 'schedule_class_card.dart';

/// Celda de una grilla semanal: un día × una hora.
///
/// Si hay varias clases a la misma hora se muestran dos filas compactas y un
/// botón "+N más" que abre la lista completa. Así la celda nunca desborda,
/// aunque la academia tenga 4 clases en el mismo horario.
class ScheduleDayColumn extends StatelessWidget {
  const ScheduleDayColumn({
    super.key,
    required this.dayOfWeek,
    required this.hour,
    required this.entries,
    required this.width,
    required this.genreColorMap,
    required this.onOpenClass,
    this.onAddClass,
    this.accessFor,
    this.showOrganization = false,
  });

  final int dayOfWeek;
  final int hour;
  final List<OrgScheduleEntry> entries;
  final double width;
  final Map<String, Color> genreColorMap;
  final void Function(String classId) onOpenClass;
  final VoidCallback? onAddClass;

  /// Tipo de acceso del alumno por clase (solo en "Mis clases").
  final ClassAccess? Function(String classId)? accessFor;

  /// Muestra logo + nombre de la academia en cada tarjeta.
  final bool showOrganization;

  /// Filas compactas visibles antes del botón "+N más".
  static const int _maxVisible = 2;
  static const double _compactHeight = 27;

  int _parseHour(String timeStr) {
    try {
      final clean = timeStr.trim().split(' ')[0].split('+')[0];
      return int.parse(clean.split(':')[0]);
    } catch (_) {
      return 12;
    }
  }

  Color _colorFor(String genre) => genreColorMap[genre] ?? genreColor(genre);

  @override
  Widget build(BuildContext context) {
    final matches = entries
        .where(
          (e) =>
              e.schedule.dayOfWeek == dayOfWeek &&
              _parseHour(e.schedule.startTime) == hour,
        )
        .toList();

    final border = Border(
      right: BorderSide(color: context.divider, width: 0.7),
    );

    if (matches.isEmpty) {
      return SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(border: border),
          child: onAddClass == null
              ? const SizedBox.expand()
              : Semantics(
                  button: true,
                  label:
                      'Agregar clase el ${weekdayName(dayOfWeek)} a las ${hourLabel(hour)}',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onAddClass,
                      child: Center(
                        child: Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: context.textMuted.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      );
    }

    if (matches.length == 1) {
      final entry = matches.first;
      final genre = classGenre(entry.danceClass.title);
      return Container(
        width: width,
        decoration: BoxDecoration(border: border),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: ScheduleClassCard(
          entry: entry,
          themeColor: _colorFor(genre),
          styleTag: genre,
          access: accessFor?.call(entry.danceClass.id),
          showOrganization: showOrganization,
          onTap: () => onOpenClass(entry.danceClass.id),
        ),
      );
    }

    final visible = matches.take(_maxVisible).toList();
    final hidden = matches.length - visible.length;

    return Container(
      width: width,
      decoration: BoxDecoration(border: border),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in visible) ...[
            SizedBox(
              height: _compactHeight,
              child: ScheduleClassCard(
                entry: entry,
                themeColor: _colorFor(classGenre(entry.danceClass.title)),
                styleTag: classGenre(entry.danceClass.title),
                dense: true,
                access: accessFor?.call(entry.danceClass.id),
                showOrganization: showOrganization,
                onTap: () => onOpenClass(entry.danceClass.id),
              ),
            ),
            const SizedBox(height: 3),
          ],
          if (hidden > 0)
            SizedBox(
              height: 24,
              child: Semantics(
                button: true,
                label:
                    'Ver las $hidden clases restantes del ${weekdayName(dayOfWeek)} a las ${hourLabel(hour)}',
                child: Material(
                  color: context.surfaceHeader,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _showAllClasses(context, matches),
                    child: Center(
                      child: Text(
                        '+$hidden más',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAllClasses(
    BuildContext context,
    List<OrgScheduleEntry> matches,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.cardBg,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    '${matches.length} clases el ${weekdayName(dayOfWeek)} a las ${hourLabel(hour)}',
                    style: TextStyle(
                      color: context.textOnBg,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final entry in matches)
                  _SheetClassTile(
                    entry: entry,
                    color: _colorFor(classGenre(entry.danceClass.title)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onOpenClass(entry.danceClass.id);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SheetClassTile extends StatelessWidget {
  const _SheetClassTile({
    required this.entry,
    required this.color,
    required this.onTap,
  });

  final OrgScheduleEntry entry;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final danceClass = entry.danceClass;
    final schedule = entry.schedule;
    final isDraft = !danceClass.isPublished;
    final instructor = schedule.instructorName ?? danceClass.instructorName;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 6,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: Text(
        danceClass.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.textOnBg,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        [
          '${hhmm(schedule.startTime)} – ${hhmm(schedule.endTime)}',
          if (instructor != null && instructor.isNotEmpty) instructor,
          if (isDraft) 'Borrador',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.textMuted, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: context.textMuted),
    );
  }
}
