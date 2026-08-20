import '../models/class_model.dart';
import '../models/dance_class_schedule_model.dart';
import '../models/dance_class_session_model.dart';
import '../services/dance_class_service.dart';

abstract interface class IDanceClassRepository {
  Future<List<ClassModel>> fetchOrganizationClasses(String organizationId);
  Future<ClassModel?> fetchClass(String classId);
  Future<ClassModel> createClass(Map<String, dynamic> data);
  Future<void> updateClass(String id, Map<String, dynamic> data);
  Future<void> deleteClass(String id);

  Future<List<DanceClassScheduleModel>> fetchClassSchedules(String classId);
  Future<DanceClassScheduleModel> createSchedule(Map<String, dynamic> data);
  Future<void> updateSchedule(String id, Map<String, dynamic> data);
  Future<void> deleteSchedule(String id);

  Future<List<DanceClassSessionModel>> fetchClassSessions(String classId);
  Future<List<DanceClassSessionModel>> fetchUpcomingSessions(String classId);
  Future<void> generateSessions({
    required String classId,
    required DateTime startDate,
    required DateTime endDate,
  });
  Future<void> cancelSession({required String sessionId, String? reason});
  Future<void> completeSession(String sessionId);
  Future<void> updateSessionLocation({
    required String sessionId,
    required Map<String, dynamic> location,
  });
  Future<void> rescheduleSession({
    required String sessionId,
    required DateTime newStartAt,
    required DateTime newEndAt,
  });

  Future<Map<String, int>> fetchOrgStats(String organizationId);
  Future<List<Map<String, dynamic>>> fetchOrgInstructors(String organizationId);
}

class DanceClassRepository implements IDanceClassRepository {
  const DanceClassRepository({DanceClassService? service})
      : _service = service ?? const DanceClassService();

  final DanceClassService _service;

  @override
  Future<List<ClassModel>> fetchOrganizationClasses(
      String organizationId) async {
    final rows = await _service.fetchOrganizationClasses(organizationId);
    return rows
        .map((row) => ClassModel.fromJson({...row, 'organization_name': ''}))
        .toList();
  }

  @override
  Future<ClassModel?> fetchClass(String classId) async {
    final raw = await _service.fetchClass(classId);
    return raw != null
        ? ClassModel.fromJson({...raw, 'organization_name': ''})
        : null;
  }

  @override
  Future<ClassModel> createClass(Map<String, dynamic> data) async {
    final raw = await _service.createClass(data);
    return ClassModel.fromJson({...raw, 'organization_name': ''});
  }

  @override
  Future<void> updateClass(String id, Map<String, dynamic> data) =>
      _service.updateClass(id, data);

  @override
  Future<void> deleteClass(String id) => _service.deleteClass(id);

  @override
  Future<List<DanceClassScheduleModel>> fetchClassSchedules(
      String classId) async {
    final rows = await _service.fetchClassSchedules(classId);
    return rows.map((row) => DanceClassScheduleModel.fromJson(row)).toList();
  }

  @override
  Future<DanceClassScheduleModel> createSchedule(
      Map<String, dynamic> data) async {
    final raw = await _service.createSchedule(data);
    return DanceClassScheduleModel.fromJson(raw);
  }

  @override
  Future<void> updateSchedule(String id, Map<String, dynamic> data) =>
      _service.updateSchedule(id, data);

  @override
  Future<void> deleteSchedule(String id) => _service.deleteSchedule(id);

  @override
  Future<List<DanceClassSessionModel>> fetchClassSessions(
      String classId) async {
    final rows = await _service.fetchClassSessions(classId);
    return rows.map((row) => DanceClassSessionModel.fromJson(row)).toList();
  }

  @override
  Future<List<DanceClassSessionModel>> fetchUpcomingSessions(
      String classId) async {
    final rows = await _service.fetchUpcomingSessions(classId);
    return rows.map((row) => DanceClassSessionModel.fromJson(row)).toList();
  }

  @override
  Future<void> generateSessions({
    required String classId,
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      _service.generateSessions(
        classId: classId,
        startDate: startDate,
        endDate: endDate,
      );

  @override
  Future<void> cancelSession({required String sessionId, String? reason}) =>
      _service.cancelSession(sessionId: sessionId, reason: reason);

  @override
  Future<void> completeSession(String sessionId) =>
      _service.completeSession(sessionId);

  @override
  Future<void> updateSessionLocation({
    required String sessionId,
    required Map<String, dynamic> location,
  }) =>
      _service.updateSessionLocation(sessionId: sessionId, location: location);

  @override
  Future<void> rescheduleSession({
    required String sessionId,
    required DateTime newStartAt,
    required DateTime newEndAt,
  }) =>
      _service.rescheduleSession(
        sessionId: sessionId,
        newStartAt: newStartAt,
        newEndAt: newEndAt,
      );

  @override
  Future<Map<String, int>> fetchOrgStats(String organizationId) =>
      _service.fetchOrgStats(organizationId);

  @override
  Future<List<Map<String, dynamic>>> fetchOrgInstructors(
          String organizationId) =>
      _service.fetchOrgInstructors(organizationId);
}
