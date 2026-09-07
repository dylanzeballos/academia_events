import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/attendance_model.dart';
import '../data/models/class_enrollment_model.dart';
import '../data/models/class_model.dart';
import '../data/models/dance_class_session_model.dart';
import '../data/models/organization_with_classes.dart';
import '../data/repositories/class_enrollment_repository.dart';
import 'auth_provider.dart';
import 'dance_class_provider.dart';

final classEnrollmentRepositoryProvider =
    Provider<IClassEnrollmentRepository>((ref) {
  return const ClassEnrollmentRepository();
});

// ─── Mis inscripciones (estudiante) ───────────────

final myEnrollmentsProvider =
    FutureProvider<List<ClassEnrollmentModel>>((ref) async {
  ref.watch(authStateProvider);
  final userId = ref.read(authRepositoryProvider).currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(classEnrollmentRepositoryProvider);
  return repo.fetchMyEnrollments();
});

// ─── Mis clases, agrupadas por clase y por próxima sesión ───

/// Una clase de "Mis Clases": la inscripción (con datos de clase/org) junto a
/// sus sesiones futuras, ordenadas de la más próxima a la más lejana.
class MyClassGroup {
  const MyClassGroup({
    required this.enrollment,
    required this.upcomingSessions,
  });

  final ClassEnrollmentModel enrollment;

  /// Sesiones futuras (ya excluidas las pasadas), más próxima primero.
  final List<DanceClassSessionModel> upcomingSessions;

  DanceClassSessionModel get nextSession => upcomingSessions.first;
}

/// "Mis Clases" para la pestaña del estudiante:
/// - Agrupa por clase (dedupe por si hay inscripciones duplicadas).
/// - Solo muestra clases con sesiones FUTURAS (las pasadas no saturan).
/// - Ordena por la sesión más próxima en primer lugar.
final myClassesWithSessionsProvider = FutureProvider<List<MyClassGroup>>((ref) async {
  ref.watch(authStateProvider);
  final enrollments = await ref.watch(myEnrollmentsProvider.future);
  final now = DateTime.now();

  // Solo inscripciones que importan (omitir rechazadas).
  final relevant =
      enrollments.where((e) => e.status != 'rejected').toList();

  // Agrupar por clase: si hay varias inscripciones, quedarse con la activa.
  final byClass = <String, ClassEnrollmentModel>{};
  for (final enrollment in relevant) {
    final existing = byClass[enrollment.danceClassId];
    if (existing == null || (enrollment.isActive && !existing.isActive)) {
      byClass[enrollment.danceClassId] = enrollment;
    }
  }

  final repo = ref.watch(classEnrollmentRepositoryProvider);
  final groups = <MyClassGroup>[];
  for (final enrollment in byClass.values) {
    final sessions =
        await repo.fetchAllSessionsForClass(enrollment.danceClassId);
    final upcoming = sessions
        .where((s) => s.startAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    // Los pasados no se muestran: si no queda ninguna sesión futura, la
    // clase no aparece en la lista.
    if (upcoming.isEmpty) continue;
    groups.add(MyClassGroup(enrollment: enrollment, upcomingSessions: upcoming));
  }

  groups.sort(
    (a, b) => a.nextSession.startAt.compareTo(b.nextSession.startAt),
  );

  return groups;
});

// ─── Mi asistencia (estudiante) ───────────────────

final myAttendanceProvider = FutureProvider<List<AttendanceModel>>((ref) async {
  ref.watch(authStateProvider);
  final userId = ref.read(authRepositoryProvider).currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(classEnrollmentRepositoryProvider);
  return repo.fetchMyAttendance();
});

// ─── Exploración: organizaciones con clases publicadas ───

final organizationsWithPublishedClassesProvider =
    FutureProvider<List<OrganizationWithClasses>>((ref) async {
  final repo = ref.watch(classEnrollmentRepositoryProvider);
  return repo.fetchOrganizationsWithPublishedClasses();
});

// Organización seleccionada para explorar sus clases.
class SelectedExploreOrgIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authStateProvider);
    return null;
  }

  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedExploreOrgIdProvider =
    NotifierProvider<SelectedExploreOrgIdNotifier, String?>(
  () => SelectedExploreOrgIdNotifier(),
);

// Clase seleccionada para el detalle de inscripción.
class SelectedEnrollClassIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authStateProvider);
    return null;
  }

  void select(String? id) => state = id;
  void clear() => state = null;
}

final selectedEnrollClassIdProvider =
    NotifierProvider<SelectedEnrollClassIdNotifier, String?>(
  () => SelectedEnrollClassIdNotifier(),
);

// La clase publicada seleccionada para el detalle de inscripción.
final selectedEnrollClassProvider = FutureProvider<ClassModel?>((ref) {
  final classId = ref.watch(selectedEnrollClassIdProvider);
  if (classId == null) return Future.value(null);
  final repo = ref.watch(danceClassRepositoryProvider);
  return repo.fetchClass(classId);
});

// Clases publicadas de la organización seleccionada para explorar.
final exploreOrgPublishedClassesProvider =
    FutureProvider<List<ClassModel>>((ref) {
  final orgId = ref.watch(selectedExploreOrgIdProvider);
  if (orgId == null) return Future.value(const []);
  final repo = ref.watch(classEnrollmentRepositoryProvider);
  return repo.fetchPublishedClassesForOrg(orgId);
});

/// ¿El usuario ya está inscrito (activo) en una clase concreta?
bool alreadyEnrolled(
    List<ClassEnrollmentModel> enrollments, String classId) {
  return enrollments.any((e) =>
      e.danceClassId == classId && (e.status == 'active' || e.status == 'approved' || e.status == 'pending'));
}

// Inscripción del usuario seleccionada para el detalle (Mis Clases).
class SelectedEnrolledClassIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authStateProvider);
    return null;
  }

  void select(String id) => state = id;
  void clear() => state = null;
}

final selectedEnrolledClassIdProvider =
    NotifierProvider<SelectedEnrolledClassIdNotifier, String?>(
  () => SelectedEnrolledClassIdNotifier(),
);

/// La inscripción seleccionada (con datos de clase/organización anidados).
final selectedMyEnrollmentProvider =
    FutureProvider<ClassEnrollmentModel?>((ref) async {
  final enrollmentId = ref.watch(selectedEnrolledClassIdProvider);
  if (enrollmentId == null) return null;
  final list = await ref.watch(myEnrollmentsProvider.future);
  return list.where((e) => e.id == enrollmentId).firstOrNull;
});

/// Sesiones de la clase de la inscripción seleccionada (via inheritance id).
final enrolledClassSessionsProvider = FutureProvider.autoDispose<List<DanceClassSessionModel>>((ref) async {
  final enrollment = await ref.watch(selectedMyEnrollmentProvider.future);
  if (enrollment == null) return [];
  final repo = ref.watch(classEnrollmentRepositoryProvider);
  return repo.fetchAllSessionsForClass(enrollment.danceClassId);
});

/// Mi asistencia para la clase de la inscripción seleccionada.
final enrolledClassAttendanceProvider = FutureProvider.autoDispose<List<AttendanceModel>>((ref) async {
  final enrollment = await ref.watch(selectedMyEnrollmentProvider.future);
  if (enrollment == null) return [];
  final all = await ref.watch(myAttendanceProvider.future);
  return all
      .where((a) => a.enrollmentId == enrollment.id)
      .toList();
});

// ─── Acciones (inscribir / cancelar) ──────────────

class EnrollmentActionState {
  const EnrollmentActionState({this.isLoading = false, this.error});

  final bool isLoading;
  final String? error;

  EnrollmentActionState copyWith({bool? isLoading, String? error}) {
    return EnrollmentActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EnrollmentActionNotifier extends Notifier<EnrollmentActionState> {
  @override
  EnrollmentActionState build() => const EnrollmentActionState();

  Future<bool> enroll(String classId) async {
    state = const EnrollmentActionState(isLoading: true);
    try {
      final repo = ref.read(classEnrollmentRepositoryProvider);
      await repo.enrollInClass(classId);
      ref.invalidate(myEnrollmentsProvider);
      state = const EnrollmentActionState();
      return true;
    } catch (e) {
      state = EnrollmentActionState(error: e.toString());
      return false;
    }
  }

  Future<bool> cancel(String enrollmentId) async {
    state = const EnrollmentActionState(isLoading: true);
    try {
      final repo = ref.read(classEnrollmentRepositoryProvider);
      await repo.cancelEnrollment(enrollmentId);
      ref.invalidate(myEnrollmentsProvider);
      state = const EnrollmentActionState();
      return true;
    } catch (e) {
      state = EnrollmentActionState(error: e.toString());
      return false;
    }
  }

  void clearError() => state = const EnrollmentActionState();
}

final enrollmentActionProvider =
    NotifierProvider<EnrollmentActionNotifier, EnrollmentActionState>(() {
  return EnrollmentActionNotifier();
});