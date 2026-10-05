import '../models/class_attendance_model.dart';
import '../models/event_attendance_model.dart';
import '../models/vip_attendance_model.dart';
import '../services/attendance_service.dart';

abstract interface class IAttendanceRepository {
  Future<EventAttendanceData> fetchEventAttendance(String eventId);
  Future<ClassAttendanceData> fetchClassAttendance(String classId);
  Future<VipAttendanceData> fetchOrgVipAttendance(
    String organizationId,
    DateTime month,
  );
}

class AttendanceRepository implements IAttendanceRepository {
  const AttendanceRepository({AttendanceService? service})
      : _service = service ?? const AttendanceService();

  final AttendanceService _service;

  @override
  Future<EventAttendanceData> fetchEventAttendance(String eventId) =>
      _service.fetchEventAttendance(eventId);

  @override
  Future<ClassAttendanceData> fetchClassAttendance(String classId) =>
      _service.fetchClassAttendance(classId);

  @override
  Future<VipAttendanceData> fetchOrgVipAttendance(
    String organizationId,
    DateTime month,
  ) =>
      _service.fetchOrgVipAttendance(organizationId, month);
}