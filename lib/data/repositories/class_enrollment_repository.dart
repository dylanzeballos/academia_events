import '../models/attendance_model.dart';
import '../models/class_enrollment_model.dart';
import '../models/class_model.dart';
import '../models/dance_class_session_model.dart';
import '../models/organization_with_classes.dart';
import '../services/class_enrollment_service.dart';

abstract interface class IClassEnrollmentRepository {
  Future<String> enrollInClass(String classId);
  Future<void> cancelEnrollment(String enrollmentId);

  Future<List<ClassEnrollmentModel>> fetchMyEnrollments();
  Future<List<ClassEnrollmentModel>> fetchEnrollmentsForClass(String classId);

  Future<List<AttendanceModel>> fetchMyAttendance();

  Future<List<DanceClassSessionModel>> fetchSessionsForClass(String classId);
  Future<List<DanceClassSessionModel>> fetchAllSessionsForClass(String classId);

  Future<List<OrganizationWithClasses>> fetchOrganizationsWithPublishedClasses();
  Future<List<ClassModel>> fetchPublishedClassesForOrg(String orgId);
}

class ClassEnrollmentRepository implements IClassEnrollmentRepository {
  const ClassEnrollmentRepository({ClassEnrollmentService? service})
      : _service = service ?? const ClassEnrollmentService();

  final ClassEnrollmentService _service;

  @override
  Future<List<ClassModel>> fetchPublishedClassesForOrg(String orgId) async {
    final rows = await _service.fetchPublishedClassesForOrg(orgId);
    return rows.map((r) => ClassModel.fromJson(r)).toList();
  }

  @override
  Future<String> enrollInClass(String classId) =>
      _service.enrollInClass(classId);

  @override
  Future<void> cancelEnrollment(String enrollmentId) =>
      _service.cancelEnrollment(enrollmentId);

  @override
  Future<List<ClassEnrollmentModel>> fetchMyEnrollments() async {
    final rows = await _service.fetchMyEnrollments();
    return rows
        .map((r) => ClassEnrollmentModel.fromJson(r))
        .toList();
  }

  @override
  Future<List<ClassEnrollmentModel>> fetchEnrollmentsForClass(
      String classId) async {
    final rows = await _service.fetchEnrollmentsForClass(classId);
    return rows.map((r) => ClassEnrollmentModel.fromJson(r)).toList();
  }

  @override
  Future<List<AttendanceModel>> fetchMyAttendance() async {
    final rows = await _service.fetchMyAttendance();
    return rows.map((r) => AttendanceModel.fromJson(r)).toList();
  }

  @override
  Future<List<DanceClassSessionModel>> fetchSessionsForClass(
      String classId) async {
    final rows = await _service.fetchSessionsForClass(classId);
    return rows.map((r) => DanceClassSessionModel.fromJson(r)).toList();
  }

  @override
  Future<List<DanceClassSessionModel>> fetchAllSessionsForClass(
      String classId) async {
    final rows = await _service.fetchAllSessionsForClass(classId);
    return rows.map((r) => DanceClassSessionModel.fromJson(r)).toList();
  }

  @override
  Future<List<OrganizationWithClasses>>
      fetchOrganizationsWithPublishedClasses() async {
    final rows = await _service.fetchOrganizationsWithPublishedClasses();
    return rows.map((r) => OrganizationWithClasses.fromJson(r)).toList();
  }
}