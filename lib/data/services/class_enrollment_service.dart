import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class ClassEnrollmentException implements Exception {
  const ClassEnrollmentException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ClassEnrollmentService {
  const ClassEnrollmentService();

  // ─── Inscripción ─────────────────────────────────

  /// Llama al RPC `enroll_in_class`. Devuelve el id de la inscripción creada.
  Future<String> enrollInClass(String classId) async {
    try {
      final id = await supabase.rpc('enroll_in_class', params: {
        'p_class_id': classId,
      });
      return id as String;
    } on PostgrestException catch (e) {
      throw ClassEnrollmentException(_friendlyError(e.message));
    }
  }

  /// Llama al RPC `cancel_enrollment`.
  Future<void> cancelEnrollment(String enrollmentId) async {
    try {
      await supabase.rpc('cancel_enrollment', params: {
        'p_enrollment_id': enrollmentId,
      });
    } on PostgrestException catch (e) {
      throw ClassEnrollmentException(_friendlyError(e.message));
    }
  }

  // ─── Consultas de inscripciones del usuario ──────

  Future<List<Map<String, dynamic>>> fetchMyEnrollments() async {
    try {
      return await supabase
          .from('class_enrollments')
          .select('''
            id, dance_class_id, user_id, status,
            enrolled_at, cancelled_at, created_at, updated_at,
            dance_classes(id, title, cover_image_url, organizations(id, name))
          ''')
          .order('enrolled_at', ascending: false);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchEnrollmentsForClass(
      String classId) async {
    try {
      return await supabase
          .from('class_enrollments')
          .select('''
            id, dance_class_id, user_id, status,
            enrolled_at, cancelled_at, created_at, updated_at,
            profiles(first_name, last_name)
          ''')
          .eq('dance_class_id', classId)
          .order('enrolled_at');
    } catch (e) {
      return [];
    }
  }

  // ─── Asistencia ──────────────────────────────────

  /// Asistencias del usuario autenticado (estudiante).
  Future<List<Map<String, dynamic>>>
      fetchMyAttendance() async {
    try {
      return await supabase
          .from('attendances')
          .select('''
            id, enrollment_id, session_id, status, notes,
            recorded_by, recorded_at, created_at, updated_at,
            dance_class_sessions(
              id, dance_class_id, session_date, start_at, end_at,
              schedule_id, status, location_override, cancelled_reason,
              is_completed, created_at, updated_at
            )
          ''')
          // RLS filtra por el usuario autenticado en "Students view own attendances".
          .order('recorded_at', ascending: false);
    } catch (e) {
      return [];
    }
  }

  // ─── Sesiones para la academia ────────────────────

  /// Sesiones futuras programadas de una clase (para el check-in con QR).
  Future<List<Map<String, dynamic>>> fetchSessionsForClass(
      String classId) async {
    try {
      return await supabase
          .from('dance_class_sessions')
          .select('*')
          .eq('dance_class_id', classId)
          .eq('status', 'scheduled')
          .order('session_date');
    } catch (e) {
      return [];
    }
  }

  /// Todas las sesiones de una clase (para el estudiante ver su progreso).
  Future<List<Map<String, dynamic>>> fetchAllSessionsForClass(
      String classId) async {
    try {
      return await supabase
          .from('dance_class_sessions')
          .select('*')
          .eq('dance_class_id', classId)
          .order('session_date');
    } catch (e) {
      return [];
    }
  }

  // ─── Exploración: clases publicadas de una organización ───

  Future<List<Map<String, dynamic>>> fetchPublishedClassesForOrg(
      String orgId) async {
    try {
      return await supabase
          .from('dance_classes')
          .select('''
            id, title, description, cover_image_url, status, capacity,
            price, currency, timezone, organization_id, instructor_id,
            profiles(first_name, last_name)
          ''')
          .eq('organization_id', orgId)
          .eq('status', 'published')
          .order('title');
    } catch (e) {
      return [];
    }
  }

  // ─── Exploración: organizaciones con clases publicadas ───

  /// Organizaciones activas que tienen al menos una clase publicada.
  Future<List<Map<String, dynamic>>> fetchOrganizationsWithPublishedClasses({
    int limit = 20,
  }) async {
    try {
      final response = await supabase
          .from('organizations')
          .select('''
            id, name, logo_url, description, city_id,
            dance_classes!inner(id, status)
          ''')
          .eq('is_active', true)
          .eq('dance_classes.status', 'published')
          .limit(limit);

      final data = (response as List).cast<Map<String, dynamic>>();
      final seen = <String>{};
      final orgs = <Map<String, dynamic>>[];
      for (final row in data) {
        final orgId = row['id'] as String;
        if (seen.contains(orgId)) continue;
        seen.add(orgId);
        row['logo_url'] = _publicLogoUrl(row['logo_url'] as String?);
        orgs.add(row);
      }
      return orgs;
    } catch (e) {
      return [];
    }
  }

  // ─── Helpers ─────────────────────────────────────

  static String? _publicLogoUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return supabase.storage.from('organization-logos').getPublicUrl(path);
  }

  String _friendlyError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('no existe') || msg.contains('not found')) {
      return 'La clase o inscripción no existe.';
    }
    if (msg.contains('no está publicada') || msg.contains('not published') ||
        msg.contains('está llena') || msg.contains('full')) {
      return message;
    }
    if (msg.contains('ya estás inscrito') || msg.contains('already enrolled')) {
      return 'Ya estás inscrito en esta clase.';
    }
    if (msg.contains('permiso') || msg.contains('permission') ||
        msg.contains('row-level security')) {
      return 'No tienes permiso para realizar esta acción.';
    }
    return 'No se pudo completar la operación. Intenta de nuevo.';
  }
}