import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/class_model.dart';
import '../data/models/class_publication_status.dart';
import '../data/models/dance_class_schedule_model.dart';
import '../data/models/dance_class_session_model.dart';
import '../data/repositories/dance_class_repository.dart';
import '../data/services/pagosya_service.dart';
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

final classSchedulesProvider = FutureProvider<List<DanceClassScheduleModel>>((
  ref,
) {
  final classId = ref.watch(selectedClassIdProvider);
  if (classId == null) return Future.value([]);
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchClassSchedules(classId);
});

/// Estado de publicación de una clase (pago, precio y membresía mensual).
final classPublicationStatusProvider = FutureProvider.autoDispose
    .family<ClassPublicationStatus, String>((ref, classId) {
      return const PagosyaService().classPublicationStatus(classId);
    });

// ─── Próxima sesión de la organización (panel) ───────
/// Una sola sesión próxima, para la vista previa del dashboard.
final nextOrgSessionProvider = FutureProvider.autoDispose<NextClassSession?>((
  ref,
) async {
  final orgId = ref.watch(selectedOrganizationIdProvider);
  if (orgId == null) return null;
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchNextOrgSession(orgId);
});

// ─── Sesiones de la clase seleccionada (paginadas) ──

typedef ClassSessionsQuery = ({
  String classId,
  int limit,
  bool upcomingOnly,
  bool pastOnly,
});

/// Página de sesiones: una clase con horario recurrente puede tener cientos de
/// sesiones al año, así que se cargan de a bloques con "Ver más".
final classSessionsPageProvider = FutureProvider.autoDispose
    .family<SessionPage, ClassSessionsQuery>((ref, query) {
      final repo = ref.watch(danceClassRepositoryProvider);
      return repo.fetchClassSessionsPage(
        query.classId,
        limit: query.limit,
        upcomingOnly: query.upcomingOnly,
        pastOnly: query.pastOnly,
      );
    });

final upcomingSessionsProvider = FutureProvider<List<DanceClassSessionModel>>((
  ref,
) {
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

final orgInstructorsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final orgId = ref.watch(selectedOrganizationIdProvider);
  if (orgId == null) return [];
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchOrgInstructors(orgId);
});

// ─── Horario Semanal Multi-Días (Recurrencia) ───────

class OrgScheduleEntry {
  const OrgScheduleEntry({required this.schedule, required this.danceClass});

  final DanceClassScheduleModel schedule;
  final ClassModel danceClass;
}

final orgWeeklyScheduleEntriesProvider = FutureProvider<List<OrgScheduleEntry>>((
  ref,
) async {
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
    double priceMonthly = 0,
    String? danceCategoryId,
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
        'description': description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        'capacity': capacity,
        'price': price,
        'price_monthly': priceMonthly,
        'dance_category_id': danceCategoryId,
        'currency': 'BOB',
        'instructor_id': instructorId,
        'status': 'draft',
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
