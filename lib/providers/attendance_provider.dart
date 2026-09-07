import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/class_attendance_model.dart';
import '../data/models/event_attendance_model.dart';
import '../data/repositories/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<IAttendanceRepository>((ref) {
  return const AttendanceRepository();
});

/// Métricas y lista de asistentes de un evento (solo para staff de la org).
final eventAttendanceProvider =
    FutureProvider.family<EventAttendanceData, String>((ref, eventId) {
  return ref.read(attendanceRepositoryProvider).fetchEventAttendance(eventId);
});

/// Métricas por sesión y roster de una clase (solo para staff de la org).
final classAttendanceProvider =
    FutureProvider.family<ClassAttendanceData, String>((ref, classId) {
  return ref.read(attendanceRepositoryProvider).fetchClassAttendance(classId);
});