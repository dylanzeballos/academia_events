import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/class_model.dart';
import '../data/models/dance_class_schedule_model.dart';
import '../data/models/dance_class_session_model.dart';
import '../data/repositories/dance_class_repository.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

final danceClassRepositoryProvider = Provider<IDanceClassRepository>((ref) {
  return const DanceClassRepository();
});

// ─── Classes for selected org ──────────────────────

final orgClassesProvider = FutureProvider<List<ClassModel>>((ref) async {
  final orgId = ref.watch(selectedOrganizationIdProvider);
  if (orgId == null) return [];
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchOrganizationClasses(orgId);
});

// ─── Selected class ────────────────────────────────

class SelectedClassIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authStateProvider);
    return null;
  }

  void select(String id) => state = id;
  void clear() => state = null;
}

final selectedClassIdProvider =
    NotifierProvider<SelectedClassIdNotifier, String?>(
  () => SelectedClassIdNotifier(),
);

final selectedClassProvider = FutureProvider<ClassModel?>((ref) {
  final classId = ref.watch(selectedClassIdProvider);
  if (classId == null) return Future.value(null);
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchClass(classId);
});

// ─── Schedules for selected class ──────────────────

final classSchedulesProvider =
    FutureProvider<List<DanceClassScheduleModel>>((ref) {
  final classId = ref.watch(selectedClassIdProvider);
  if (classId == null) return Future.value([]);
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchClassSchedules(classId);
});

// ─── Sessions for selected class ───────────────────

final classSessionsProvider =
    FutureProvider<List<DanceClassSessionModel>>((ref) {
  final classId = ref.watch(selectedClassIdProvider);
  if (classId == null) return Future.value([]);
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchClassSessions(classId);
});

final upcomingSessionsProvider =
    FutureProvider<List<DanceClassSessionModel>>((ref) {
  final classId = ref.watch(selectedClassIdProvider);
  if (classId == null) return Future.value([]);
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchUpcomingSessions(classId);
});

// ─── Org stats ─────────────────────────────────────

final orgStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final orgId = ref.watch(selectedOrganizationIdProvider);
  if (orgId == null) {
    return {
      'totalClasses': 0,
      'activeClasses': 0,
      'upcomingSessions': 0,
      'totalMembers': 0,
    };
  }
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchOrgStats(orgId);
});

// ─── Org instructors ───────────────────────────────

final orgInstructorsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final orgId = ref.watch(selectedOrganizationIdProvider);
  if (orgId == null) return [];
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchOrgInstructors(orgId);
});

// ─── Horario Semanal Multi-Días (Recurrencia) ───────

class OrgScheduleEntry {
  const OrgScheduleEntry({
    required this.schedule,
    required this.danceClass,
  });

  final DanceClassScheduleModel schedule;
  final ClassModel danceClass;
}

final orgWeeklyScheduleEntriesProvider =
    FutureProvider<List<OrgScheduleEntry>>((ref) async {
  final orgId = ref.watch(selectedOrganizationIdProvider);
  if (orgId == null) return [];

  final classes = await ref.watch(orgClassesProvider.future);
  if (classes.isEmpty) return [];

  final repo = ref.watch(danceClassRepositoryProvider);
  final entries = <OrgScheduleEntry>[];

  // Cargar cada horario con la misma consulta simple usada por el detalle de clase.
  // Evita que un join anidado con profiles deje toda la grilla vacía si falla.
  for (final danceClass in classes) {
    final schedules = await repo.fetchClassSchedules(danceClass.id);
    for (final schedule in schedules) {
      if (schedule.isActive) {
        entries.add(
          OrgScheduleEntry(schedule: schedule, danceClass: danceClass),
        );
      }
    }
  }

  debugPrint('🔍 [SCHEDULES] Registros encontrados: ${entries.length}');
  return entries;
});

// ─── Create class state & notifier ─────────────────

class CreateClassState {
  const CreateClassState({this.isLoading = false, this.error});
  final bool isLoading;
  final String? error;

  CreateClassState copyWith({bool? isLoading, String? error}) {
    return CreateClassState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CreateClassNotifier extends Notifier<CreateClassState> {
  @override
  CreateClassState build() => const CreateClassState();

  Future<bool> createWithDays({
    required String title,
    String? description,
    int? capacity,
    double price = 0,
    String? instructorId,
    required String startTime,
    required String endTime,
    required Set<int> selectedDays,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orgId = ref.read(selectedOrganizationIdProvider);
      if (orgId == null) {
        state = const CreateClassState(error: 'No hay academia seleccionada.');
        return false;
      }

      final slug =
          '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
      final repo = ref.read(danceClassRepositoryProvider);

      // Inserción en tabla: dance_classes
      final danceClass = await repo.createClass({
        'organization_id': orgId,
        'title': title,
        'slug': slug,
        'description':
            description?.trim().isEmpty == true ? null : description?.trim(),
        'capacity': capacity,
        'price': price,
        'currency': 'BOB',
        'instructor_id': instructorId,
        'status': 'published',
      });

      // Inserción en tabla: dance_class_schedules
      for (final day in selectedDays) {
        await repo.createSchedule({
          'dance_class_id': danceClass.id,
          'day_of_week': day,
          'start_time': startTime,
          'end_time': endTime,
          'instructor_id': instructorId,
          'is_active': true,
        });
      }

      ref.invalidate(orgClassesProvider);
      ref.invalidate(orgWeeklyScheduleEntriesProvider);
      state = const CreateClassState();
      return true;
    } catch (e) {
      debugPrint('❌ Error creando clase con horarios: $e');
      state = CreateClassState(error: e.toString());
      return false;
    }
  }
}

final createClassProvider =
    NotifierProvider<CreateClassNotifier, CreateClassState>(() {
  return CreateClassNotifier();
});