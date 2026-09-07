import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/class_attendance_model.dart';
import '../models/event_attendance_model.dart';

class AttendanceException implements Exception {
  const AttendanceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Servicio de asistencia del organizador: invoca los RPCs de métricas.
/// La validación de pertenencia a la organización la hace el servidor.
class AttendanceService {
  const AttendanceService();

  Future<EventAttendanceData> fetchEventAttendance(String eventId) async {
    try {
      final result = await supabase.rpc('fetch_event_attendance', params: {
        'p_event_id': eventId,
      });
      return EventAttendanceData.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } on PostgrestException catch (e) {
      throw AttendanceException(_friendlyError(e.message));
    }
  }

  Future<ClassAttendanceData> fetchClassAttendance(String classId) async {
    try {
      final result = await supabase.rpc('fetch_class_attendance', params: {
        'p_class_id': classId,
      });
      return ClassAttendanceData.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } on PostgrestException catch (e) {
      throw AttendanceException(_friendlyError(e.message));
    }
  }

  String _friendlyError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('no tienes permiso') ||
        msg.contains('permission') ||
        msg.contains('row-level security')) {
      return 'No tienes permiso para ver esta información.';
    }
    if (msg.contains('no existe')) {
      return 'El registro solicitado no existe.';
    }
    return 'No se pudieron cargar los datos. Intenta de nuevo.';
  }
}