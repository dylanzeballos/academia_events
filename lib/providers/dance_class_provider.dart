import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/class_model.dart';
import '../data/models/dance_class_schedule_model.dart';
import '../data/models/dance_class_session_model.dart';
import '../data/repositories/dance_class_repository.dart';
import 'organization_provider.dart';

final danceClassRepositoryProvider = Provider<IDanceClassRepository>((ref) {
  return const DanceClassRepository();
});

// ─── Classes for selected org ──────────────────────

final orgClassesProvider =
    FutureProvider<List<ClassModel>>((ref) async {
  final orgId = ref.watch(selectedOrganizationIdProvider);
  if (orgId == null) return [];
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchOrganizationClasses(orgId);
});

// ─── Selected class ────────────────────────────────

class SelectedClassIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

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
    return {'totalClasses': 0, 'activeClasses': 0, 'upcomingSessions': 0, 'totalMembers': 0};
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

// ─── Create class state ────────────────────────────

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

  Future<bool> create({
    required String title,
    String? description,
    int? capacity,
    double price = 0,
    String? instructorId,
    DateTime? startAt,
    DateTime? endAt,
    List<Map<String, dynamic>>? schedules,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final orgId = ref.read(selectedOrganizationIdProvider);
      if (orgId == null) {
        state = const CreateClassState(error: 'No hay organización seleccionada.');
        return false;
      }

      final slug = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');

      final repo = ref.read(danceClassRepositoryProvider);
      final danceClass = await repo.createClass({
        'organization_id': orgId,
        'title': title,
        'slug': slug,
        'description': description,
        'capacity': capacity,
        'price': price,
        'instructor_id': instructorId,
        'start_at': startAt?.toIso8601String(),
        'end_at': endAt?.toIso8601String(),
        'status': 'draft',
      });

      // Create schedules if provided
      if (schedules != null && schedules.isNotEmpty) {
        for (final schedule in schedules) {
          schedule['dance_class_id'] = danceClass.id;
          await repo.createSchedule(schedule);
        }
      }

      ref.invalidate(orgClassesProvider);
      state = const CreateClassState();
      return true;
    } catch (e) {
      state = CreateClassState(error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith();
}

final createClassProvider =
    NotifierProvider<CreateClassNotifier, CreateClassState>(() {
  return CreateClassNotifier();
});
