import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/attendance_model.dart';
import '../data/models/class_access.dart';
import '../data/models/class_enrollment_model.dart';
import '../data/models/class_pass_model.dart';
import '../data/models/vip_plan_model.dart';
import '../data/models/class_model.dart';
import '../data/models/organization_with_classes.dart';
import '../data/repositories/class_enrollment_repository.dart';
import 'auth_provider.dart';
import 'checkin_provider.dart';
import 'class_purchase_provider.dart';
import 'dance_class_provider.dart';

final classEnrollmentRepositoryProvider = Provider<IClassEnrollmentRepository>((
  ref,
) {
  return const ClassEnrollmentRepository();
});

// ─── Mis inscripciones (estudiante) ───────────────

final myEnrollmentsProvider = FutureProvider<List<ClassEnrollmentModel>>((
  ref,
) async {
  ref.watch(authStateProvider);
  final userId = ref.read(authRepositoryProvider).currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(classEnrollmentRepositoryProvider);
  return repo.fetchMyEnrollments();
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

// ── Mis clases: horario semanal + tipo de acceso ──────

/// Todo lo que necesita "Mis clases": las franjas del horario de las clases que
/// el alumno ya pagó, su tipo de acceso, el id de inscripción y las clases
/// anotadas que todavía no tienen pase o sesiones (fuera del horario).
class MyClassesOverview {
  const MyClassesOverview({
    required this.entries,
    required this.accessByClass,
    required this.enrollmentByClass,
    required this.pending,
  });

  final List<OrgScheduleEntry> entries;
  final Map<String, ClassAccess> accessByClass;
  final Map<String, String> enrollmentByClass;

  /// Clases con inscripción activa pero sin pase o sin sesiones: no se
  /// muestran en el horario hasta que el alumno compre su acceso.
  final List<PendingMyClass> pending;

  bool get isEmpty => entries.isEmpty && pending.isEmpty;
}

/// Clase anotada que todavía no puede ocupar un lugar en el horario.
class PendingMyClass {
  const PendingMyClass({
    required this.enrollment,
    required this.danceClass,
    required this.access,
    required this.hasSessions,
  });

  final ClassEnrollmentModel enrollment;
  final ClassModel danceClass;
  final ClassAccess access;
  final bool hasSessions;

  /// Se puede comprar un pase mientras la clase tenga sesiones programadas.
  bool get canBuy => hasSessions;

  String get reason {
    if (!hasSessions && access.kind == ClassAccessKind.none) {
      return 'Sin sesiones programadas ni pase activo.';
    }
    if (!hasSessions) {
      return 'La clase no tiene sesiones próximas programadas.';
    }
    return 'Comprá un pase para que aparezca en tu horario.';
  }
}

final myClassesOverviewProvider = FutureProvider<MyClassesOverview>((
  ref,
) async {
  final enrollments = await ref.watch(myEnrollmentsProvider.future);

  // Solo inscripciones vigentes; una por clase (si hay duplicadas, la activa).
  final byClass = <String, ClassEnrollmentModel>{};
  for (final enrollment in enrollments) {
    if (!enrollment.isActive) continue;
    final existing = byClass[enrollment.danceClassId];
    if (existing == null) byClass[enrollment.danceClassId] = enrollment;
  }

  if (byClass.isEmpty) {
    return const MyClassesOverview(
      entries: [],
      accessByClass: {},
      enrollmentByClass: {},
      pending: [],
    );
  }

  final passes = <ClassPassModel>[];
  try {
    passes.addAll(await ref.watch(myClassPassesProvider.future));
  } catch (_) {
    // Sin pases: las clases se muestran como "Sin pase".
  }

  final vipMemberships = <VipMembershipModel>[];
  try {
    vipMemberships.addAll(await ref.watch(myVipMembershipsProvider.future));
  } catch (_) {
    // Sin membresías VIP: no se marca ninguna clase como VIP.
  }

  final vipOrganizations = vipMemberships
      .where((v) => v.isActive)
      .map((v) => v.organizationId)
      .toSet();

  final scheduleRepo = ref.watch(danceClassRepositoryProvider);
  final entries = <OrgScheduleEntry>[];
  final accessByClass = <String, ClassAccess>{};
  final enrollmentByClass = <String, String>{};
  final pending = <PendingMyClass>[];

  for (final enrollment in byClass.values) {
    final classId = enrollment.danceClassId;

    final access = ClassAccess.resolve(
      classId: classId,
      organizationId: enrollment.organizationId,
      passes: passes,
      vipOrganizationIds: vipOrganizations,
    );

    final schedules = await scheduleRepo.fetchClassSchedules(classId);
    final activeSchedules = schedules.where((s) => s.isActive).toList();
    final hasSessions = activeSchedules.isEmpty
        ? false
        : (await scheduleRepo.fetchUpcomingSessions(classId)).isNotEmpty;

    final danceClass = ClassModel(
      id: classId,
      title: enrollment.classTitle ?? 'Clase',
      organizationId: enrollment.organizationId ?? '',
      organizationName: enrollment.organizationName ?? '',
      instructorName: enrollment.instructorName,
      coverImageUrl: enrollment.classCoverImageUrl,
      organizationLogoUrl: enrollment.organizationLogoUrl,
      status: 'published',
    );

    // Sin pase o sin sesiones próximas no entra al horario semanal: queda
    // pendiente de pago o de que la academia programe sesiones.
    if (access.kind == ClassAccessKind.none || !hasSessions) {
      pending.add(
        PendingMyClass(
          enrollment: enrollment,
          danceClass: danceClass,
          access: access,
          hasSessions: hasSessions,
        ),
      );
      continue;
    }

    enrollmentByClass[classId] = enrollment.id;
    accessByClass[classId] = access;

    for (final schedule in activeSchedules) {
      entries.add(OrgScheduleEntry(schedule: schedule, danceClass: danceClass));
    }
  }

  pending.sort((a, b) => a.danceClass.title.compareTo(b.danceClass.title));

  return MyClassesOverview(
    entries: entries,
    accessByClass: accessByClass,
    enrollmentByClass: enrollmentByClass,
    pending: pending,
  );
});

/// ¿El usuario ya está inscrito (activo) en una clase concreta?
bool alreadyEnrolled(List<ClassEnrollmentModel> enrollments, String classId) {
  return enrollments.any(
    (e) =>
        e.danceClassId == classId &&
        (e.status == 'active' ||
            e.status == 'approved' ||
            e.status == 'pending'),
  );
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
final selectedMyEnrollmentProvider = FutureProvider<ClassEnrollmentModel?>((
  ref,
) async {
  final enrollmentId = ref.watch(selectedEnrolledClassIdProvider);
  if (enrollmentId == null) return null;
  final list = await ref.watch(myEnrollmentsProvider.future);
  return list.where((e) => e.id == enrollmentId).firstOrNull;
});

/// Sesiones de la clase de la inscripción seleccionada (via inheritance id).

/// Mi asistencia para la clase de la inscripción seleccionada.
final enrolledClassAttendanceProvider =
    FutureProvider.autoDispose<List<AttendanceModel>>((ref) async {
      final enrollment = await ref.watch(selectedMyEnrollmentProvider.future);
      if (enrollment == null) return [];
      final all = await ref.watch(myAttendanceProvider.future);
      return all.where((a) => a.enrollmentId == enrollment.id).toList();
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
