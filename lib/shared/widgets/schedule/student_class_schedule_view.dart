import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/class_presentation.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_access.dart';
import '../../../providers/dance_class_provider.dart';

enum StudentScheduleMode { agenda, week }

class StudentClassScheduleControls extends StatelessWidget {
  const StudentClassScheduleControls({
    super.key,
    required this.selectedDay,
    required this.mode,
    required this.onDaySelected,
    required this.onModeChanged,
    required this.onWeekChanged,
  });

  final DateTime selectedDay;
  final StudentScheduleMode mode;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<StudentScheduleMode> onModeChanged;
  final ValueChanged<int> onWeekChanged;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final days = DateFormatter.weekDays(selectedDay);
    final first = days.first;
    final last = days.last;
    final range = first.month == last.month
        ? '${first.day}–${last.day} ${DateFormatter.shortMonth(last)}'
        : '${first.day} ${DateFormatter.shortMonth(first)} – '
              '${last.day} ${DateFormatter.shortMonth(last)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Semana anterior',
                onPressed: () => onWeekChanged(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: context.textOnBg,
              ),
              Expanded(
                child: Text(
                  range,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Semana siguiente',
                onPressed: () => onWeekChanged(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: context.textOnBg,
              ),
              TextButton(
                onPressed: () => onDaySelected(DateTime.now()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Hoy'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                for (final day in days)
                  Expanded(
                    child: _ScheduleDayChip(
                      day: day,
                      selected: _sameDay(day, selectedDay),
                      today: _sameDay(day, DateTime.now()),
                      onTap: () => onDaySelected(day),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: context.surfaceHeader,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.divider),
            ),
            child: Row(
              children: [
                _ScheduleModeButton(
                  mode: StudentScheduleMode.agenda,
                  selectedMode: mode,
                  icon: Icons.view_agenda_outlined,
                  label: 'Agenda',
                  onTap: onModeChanged,
                ),
                _ScheduleModeButton(
                  mode: StudentScheduleMode.week,
                  selectedMode: mode,
                  icon: Icons.calendar_view_week_outlined,
                  label: 'Semana',
                  onTap: onModeChanged,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleDayChip extends StatelessWidget {
  const _ScheduleDayChip({
    required this.day,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${DateFormatter.shortDay(day)} ${day.day}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 52,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : today
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : today
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : context.divider,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormatter.shortDay(day).substring(0, 2),
                  style: TextStyle(
                    color: selected ? AppColors.onPrimary : context.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: selected
                        ? AppColors.onPrimary
                        : today
                        ? AppColors.primary
                        : context.textOnBg,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleModeButton extends StatelessWidget {
  const _ScheduleModeButton({
    required this.mode,
    required this.selectedMode,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final StudentScheduleMode mode;
  final StudentScheduleMode selectedMode;
  final IconData icon;
  final String label;
  final ValueChanged<StudentScheduleMode> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = mode == selectedMode;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(mode),
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected ? context.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.primary : context.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? context.textOnBg : context.textMuted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentClassAgenda extends StatelessWidget {
  const StudentClassAgenda({
    super.key,
    required this.day,
    required this.entries,
    required this.onOpenClass,
    this.accessFor,
    this.showOrganization = false,
    this.emptyMessage = 'No hay clases este día.',
  });

  final DateTime day;
  final List<OrgScheduleEntry> entries;
  final ValueChanged<String> onOpenClass;
  final ClassAccess? Function(String classId)? accessFor;
  final bool showOrganization;
  final String emptyMessage;

  int _weekday(DateTime date) => date.weekday % 7;

  int _minutes(String value) {
    final parts = value.trim().split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1].split(' ').first) ?? 0;
    return hour * 60 + minute;
  }

  @override
  Widget build(BuildContext context) {
    final todaysEntries =
        entries
            .where((entry) => entry.schedule.dayOfWeek == _weekday(day))
            .toList()
          ..sort(
            (a, b) =>
                _minutes(a.schedule.startTime)
                    .compareTo(_minutes(b.schedule.startTime)),
          );

    if (todaysEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: todaysEntries.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _StudentAgendaHeader(day: day, count: todaysEntries.length);
        }
        final entry = todaysEntries[index - 1];
        final classId = entry.danceClass.id;
        final access = accessFor?.call(classId);
        return _StudentClassAgendaRow(
          entry: entry,
          access: access,
          showOrganization: showOrganization,
          onTap: () => onOpenClass(classId),
        );
      },
    );
  }
}

class _StudentAgendaHeader extends StatelessWidget {
  const _StudentAgendaHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormatter.capitalize(
      DateFormat('EEEE d MMMM', 'es').format(day),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dayLabel,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            count == 1 ? '1 clase' : '$count clases',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentClassAgendaRow extends StatelessWidget {
  const _StudentClassAgendaRow({
    required this.entry,
    required this.onTap,
    required this.showOrganization,
    this.access,
  });

  final OrgScheduleEntry entry;
  final ClassAccess? access;
  final bool showOrganization;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final danceClass = entry.danceClass;
    final schedule = entry.schedule;
    final color = genreColor(classGenre(danceClass.title));
    final location =
        schedule.locationOverride?['location_name']?.toString() ??
        schedule.locationOverride?['address_line_1']?.toString();
    final price = danceClass.price;
    final imageUrl = danceClass.coverImageUrl;

    return Semantics(
      button: true,
      label: [
        danceClass.title,
        '${schedule.startTime} a ${schedule.endTime}',
        if (danceClass.organizationName.isNotEmpty) danceClass.organizationName,
        if (access != null) access!.label,
      ].join(', '),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          child: SizedBox(
            height: 144,
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  height: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              _ClassImageFallback(accent: color),
                        )
                      else
                        _ClassImageFallback(accent: color),
                      if (access != null)
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: _AgendaMetaPill(
                            label: access!.label,
                            color: access!.color,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          danceClass.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textOnBg,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        if (showOrganization &&
                            danceClass.organizationName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            danceClass.organizationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const Spacer(),
                        _ClassAgendaInfoRow(
                          icon: Icons.schedule_rounded,
                          text:
                              '${schedule.dayName} · ${hhmm(schedule.startTime)}–${hhmm(schedule.endTime)}',
                        ),
                        if (location != null && location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _ClassAgendaInfoRow(
                            icon: Icons.place_outlined,
                            text: location,
                          ),
                        ],
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                price <= 0
                                    ? 'Gratis'
                                    : 'Bs ${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: color,
                            ),
                          ],
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
    );
  }
}

class _ClassAgendaInfoRow extends StatelessWidget {
  const _ClassAgendaInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: context.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textOnBg.withValues(alpha: 0.72),
              fontSize: 10.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassImageFallback extends StatelessWidget {
  const _ClassImageFallback({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: accent.withValues(alpha: 0.22),
      child: Center(
        child: Icon(Icons.music_note_rounded, size: 38, color: accent),
      ),
    );
  }
}

class _AgendaMetaPill extends StatelessWidget {
  const _AgendaMetaPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
