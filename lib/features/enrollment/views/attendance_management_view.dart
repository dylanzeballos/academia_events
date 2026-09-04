import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/class_enrollment_model.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/dance_class_session_model.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';

/// Gestión de asistencia para la academia: elige clase + sesión y registra la
/// asistencia de cada estudiante inscrito. Solo owner/admin/instructor.
class AttendanceManagementView extends ConsumerWidget {
  const AttendanceManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(orgClassesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar asistencia')),
      body: classesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Text(
                'Primero crea una clase.',
                style: TextStyle(color: context.textMuted, fontSize: 14),
              ),
            );
          }
          return _AttendanceEditor(classes: classes);
        },
      ),
    );
  }
}

/// Editor con estado: selección de clase + sesión + lista de estudiantes.
class _AttendanceEditor extends ConsumerStatefulWidget {
  const _AttendanceEditor({required this.classes});

  final List<ClassModel> classes;

  @override
  ConsumerState<_AttendanceEditor> createState() => _AttendanceEditorState();
}

class _AttendanceEditorState extends ConsumerState<_AttendanceEditor> {
  String? _classId;
  String? _sessionId;

  /// Sesiones ya cargadas para la clase seleccionada.
  List<DanceClassSessionModel> _sessions = const [];

  /// Asistencias registradas para la sesión seleccionada.
  List<AttendanceModel> _attendances = const [];

  /// Estado editable por estudiante (enrollmentId -> status).
  final Map<String, String> _draft = {};

  bool _loadingSessions = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _classId = widget.classes.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
  }

  Future<void> _loadSessions() async {
    final classId = _classId;
    if (classId == null) return;
    setState(() {
      _loadingSessions = true;
      _sessionId = null;
      _attendances = const [];
      _draft.clear();
    });
    try {
      final repo = ref.read(classEnrollmentRepositoryProvider);
      final sessions = await repo.fetchSessionsForClass(classId);
      setState(() {
        _sessions = sessions;
        _loadingSessions = false;
        if (sessions.isNotEmpty) {
          _selectSession(sessions.first.id);
        }
      });
    } catch (e) {
      setState(() {
        _loadingSessions = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectSession(String sessionId) async {
    setState(() {
      _sessionId = sessionId;
      _loadingSessions = true;
      _draft.clear();
    });
    try {
      final attendances =
          await ref.read(classEnrollmentRepositoryProvider).fetchAttendanceForSession(sessionId);
      setState(() {
        _attendances = attendances;
        for (final a in attendances) {
          _draft[a.enrollmentId] = a.status;
        }
        _loadingSessions = false;
      });
    } catch (e) {
      setState(() {
        _loadingSessions = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveAll(List<ClassEnrollmentModel> students) async {
    final sessionId = _sessionId;
    if (sessionId == null || _saving) return;
    setState(() => _saving = true);

    var ok = true;
    String? firstError;
    for (final s in students) {
      final status = _draft[s.id] ?? 'present';
      try {
        await ref.read(classEnrollmentRepositoryProvider).recordAttendance(
              enrollmentId: s.id,
              sessionId: sessionId,
              status: status,
            );
      } catch (e) {
        ok = false;
        firstError ??= e.toString();
      }
    }

    if (mounted) {
      setState(() {
        _saving = false;
        _error = ok ? null : firstError;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
                ok ? 'Asistencia guardada.' : 'Ocurrió un error al guardar.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Label('Clase'),
        InputDecorator(
          decoration: _fieldDecoration(),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _classId,
              isExpanded: true,
              isDense: true,
              dropdownColor: context.cardBg,
              items: [
                for (final c in widget.classes)
                  DropdownMenuItem(value: c.id, child: Text(c.title)),
              ],
              onChanged: (v) {
                setState(() => _classId = v);
                _loadSessions();
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Label('Sesión'),
        if (_loadingSessions)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Esta clase no tiene sesiones programadas.',
                    style: TextStyle(color: context.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          InputDecorator(
            decoration: _fieldDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sessionId,
                isExpanded: true,
                isDense: true,
                dropdownColor: context.cardBg,
                items: [
                  for (final s in _sessions)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(
                          '${_date(s.sessionDate)} ${_time(s.startAt)} - ${_time(s.endAt)}'),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) _selectSession(v);
                },
              ),
            ),
          ),
        const SizedBox(height: 24),
        if (_sessionId != null)
          _StudentsCard(
            classId: _classId!,
            attendances: _attendances,
            draft: _draft,
            onDraftChanged: (enrollmentId, status) {
              setState(() => _draft[enrollmentId] = status);
            },
            saving: _saving,
            onSave: _saveAll,
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],
      ],
    );
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: context.inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        borderSide: BorderSide(color: context.divider),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: context.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Lista de estudiantes inscritos (activos/approved) con selector de estado.
class _StudentsCard extends ConsumerWidget {
  const _StudentsCard({
    required this.classId,
    required this.attendances,
    required this.draft,
    required this.onDraftChanged,
    required this.saving,
    required this.onSave,
  });

  final String classId;
  final List<AttendanceModel> attendances;
  final Map<String, String> draft;
  final void Function(String enrollmentId, String status) onDraftChanged;
  final bool saving;
  final void Function(List<ClassEnrollmentModel> students) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref
        .read(classEnrollmentRepositoryProvider)
        .fetchEnrollmentsForClass(classId);

    return FutureBuilder<List<ClassEnrollmentModel>>(
      future: future,
      initialData: const [],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data!.isEmpty) {
          return const LoadingIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}',
              style: const TextStyle(color: AppColors.error));
        }
        final active =
            (snapshot.data ?? const <ClassEnrollmentModel>[])
                .where((e) =>
                    e.status == 'active' ||
                    e.status == 'approved' ||
                    e.status == 'pending')
                .toList();
        if (active.isEmpty) {
          return Center(
            child: Text(
              'No hay estudiantes inscritos.',
              style: TextStyle(color: context.textMuted, fontSize: 14),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label('Estudiantes (${active.length})'),
            const SizedBox(height: 8),
            Card(
              color: context.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                side: BorderSide(color: context.divider),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < active.length; i++) ...[
                    _StudentRow(
                      enrollment: active[i],
                      status: draft[active[i].id] ?? 'present',
                      onChanged: (s) => onDraftChanged(active[i].id, s),
                    ),
                    if (i < active.length - 1)
                      Divider(height: 1, color: context.divider),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: saving ? null : () => onSave(active),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar asistencia'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.enrollment,
    required this.status,
    required this.onChanged,
  });

  final ClassEnrollmentModel enrollment;
  final String status;
  final ValueChanged<String> onChanged;

  static const _statuses = ['present', 'late', 'absent'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              _initial(),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              enrollment.instructorName ?? 'Estudiante',
              style: TextStyle(color: context.textOnBg, fontSize: 14),
            ),
          ),
          ActionChip(
            label: Text(_label(status)),
            avatar: Icon(_icon(status), size: 16, color: _color(status)),
            backgroundColor: _color(status).withValues(alpha: 0.12),
            side: BorderSide(color: _color(status).withValues(alpha: 0.4)),
            onPressed: () => onChanged(_next(status)),
          ),
        ],
      ),
    );
  }

  String _initial() {
    final name = enrollment.instructorName ?? '';
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _label(String s) => switch (s) {
        'present' => 'Presente',
        'late' => 'Tarde',
        'absent' => 'Ausente',
        _ => s,
      };

  IconData _icon(String s) => switch (s) {
        'present' => Icons.check_circle,
        'late' => Icons.schedule,
        'absent' => Icons.cancel,
        _ => Icons.circle,
      };

  Color _color(String s) => switch (s) {
        'present' => AppColors.success,
        'late' => AppColors.warning,
        'absent' => AppColors.error,
        _ => Colors.grey,
      };

  String _next(String s) {
    final i = _statuses.indexOf(s);
    return _statuses[(i + 1) % _statuses.length];
  }
}

String _date(DateTime d) {
  final l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

String _time(DateTime d) {
  final l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}';
}