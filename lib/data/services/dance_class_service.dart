import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class DanceClassException implements Exception {
  const DanceClassException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DanceClassService {
  const DanceClassService();

  // ─── Classes CRUD ────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchOrganizationClasses(
      String organizationId) async {
    try {
      return await supabase
          .from('dance_classes')
          .select('''
            id, title, organization_id, slug,
            description, cover_image_url,
            status, capacity, price, currency,
            start_at, end_at, timezone,
            instructor_id,
            profiles!instructor_id(first_name, last_name)
          ''')
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchClass(String classId) async {
    try {
      return await supabase
          .from('dance_classes')
          .select('''
            id, title, organization_id, slug,
            description, cover_image_url,
            status, capacity, price, currency,
            start_at, end_at, timezone,
            instructor_id,
            profiles!instructor_id(first_name, last_name)
          ''')
          .eq('id', classId)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createClass(Map<String, dynamic> data) async {
    try {
      return await supabase
          .from('dance_classes')
          .insert(data)
          .select()
          .single();
    } on PostgrestException catch (e) {
      throw DanceClassException(_friendlyError(e.message));
    }
  }

  Future<void> updateClass(String id, Map<String, dynamic> data) async {
    try {
      await supabase.from('dance_classes').update(data).eq('id', id);
    } on PostgrestException catch (e) {
      throw DanceClassException(_friendlyError(e.message));
    }
  }

  Future<void> deleteClass(String id) async {
    await supabase.from('dance_classes').delete().eq('id', id);
  }

  // ─── Schedules CRUD ──────────────────────────────

  Future<List<Map<String, dynamic>>> fetchClassSchedules(
      String classId) async {
    try {
      return await supabase
          .from('dance_class_schedules')
          .select('''
            id, dance_class_id, day_of_week,
            start_time, end_time,
            instructor_id, is_active,
            created_at, updated_at,
            profiles!instructor_id(first_name, last_name)
          ''')
          .eq('dance_class_id', classId)
          .order('day_of_week');
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createSchedule(Map<String, dynamic> data) async {
    try {
      return await supabase
          .from('dance_class_schedules')
          .insert(data)
          .select()
          .single();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const DanceClassException('Ya existe un horario para ese día.');
      }
      throw DanceClassException(_friendlyError(e.message));
    }
  }

  Future<void> updateSchedule(String id, Map<String, dynamic> data) async {
    try {
      await supabase
          .from('dance_class_schedules')
          .update(data)
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw DanceClassException(_friendlyError(e.message));
    }
  }

  Future<void> deleteSchedule(String id) async {
    await supabase.from('dance_class_schedules').delete().eq('id', id);
  }

  // ─── Sessions CRUD ───────────────────────────────

  Future<List<Map<String, dynamic>>> fetchClassSessions(
      String classId) async {
    try {
      return await supabase
          .from('dance_class_sessions')
          .select('*')
          .eq('dance_class_id', classId)
          .order('session_date', ascending: false);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUpcomingSessions(
      String classId) async {
    try {
      return await supabase
          .from('dance_class_sessions')
          .select('*')
          .eq('dance_class_id', classId)
          .eq('status', 'scheduled')
          .gte('session_date', DateTime.now().toIso8601String().split('T')[0])
          .order('session_date')
          .limit(10);
    } catch (e) {
      return [];
    }
  }

  Future<void> createSessionsBatch(List<Map<String, dynamic>> sessions) async {
    try {
      await supabase.from('dance_class_sessions').insert(sessions);
    } on PostgrestException catch (e) {
      throw DanceClassException(_friendlyError(e.message));
    }
  }

  Future<void> cancelSession({
    required String sessionId,
    String? reason,
  }) async {
    try {
      await supabase.from('dance_class_sessions').update({
        'status': 'cancelled',
        'cancelled_reason': reason,
      }).eq('id', sessionId);
    } on PostgrestException catch (e) {
      throw DanceClassException(_friendlyError(e.message));
    }
  }

  Future<void> completeSession(String sessionId) async {
    try {
      await supabase.from('dance_class_sessions').update({
        'status': 'completed',
        'is_completed': true,
      }).eq('id', sessionId);
    } on PostgrestException catch (e) {
      throw DanceClassException(_friendlyError(e.message));
    }
  }

  Future<void> updateSessionLocation({
    required String sessionId,
    required Map<String, dynamic> location,
  }) async {
    try {
      await supabase.from('dance_class_sessions').update({
        'location_override': location,
      }).eq('id', sessionId);
    } on PostgrestException catch (e) {
      throw DanceClassException(_friendlyError(e.message));
    }
  }

  Future<void> rescheduleSession({
    required String sessionId,
    required DateTime newStartAt,
    required DateTime newEndAt,
  }) async {
    try {
      await supabase.from('dance_class_sessions').update({
        'start_at': newStartAt.toIso8601String(),
        'end_at': newEndAt.toIso8601String(),
        'status': 'rescheduled',
      }).eq('id', sessionId);
    } on PostgrestException catch (e) {
      throw DanceClassException(_friendlyError(e.message));
    }
  }

  // ─── Sessions generation ─────────────────────────

  Future<void> generateSessions({
    required String classId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final schedules = await fetchClassSchedules(classId);
    if (schedules.isEmpty) return;

    final sessions = <Map<String, dynamic>>[];
    final classData = await fetchClass(classId);
    if (classData == null) return;

    for (final schedule in schedules) {
      if (schedule['is_active'] != true) continue;

      final dayOfWeek = schedule['day_of_week'] as int;
      final startTimeStr = schedule['start_time'] as String;
      final endTimeStr = schedule['end_time'] as String;
      final scheduleId = schedule['id'] as String;

      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');
      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);

      var current = startDate;
      while (!current.isAfter(endDate)) {
        if (current.weekday == dayOfWeek + 1) {
          final sessionStart = DateTime(
            current.year,
            current.month,
            current.day,
            startHour,
            startMinute,
          );
          final sessionEnd = DateTime(
            current.year,
            current.month,
            current.day,
            endHour,
            endMinute,
          );

          sessions.add({
            'dance_class_id': classId,
            'schedule_id': scheduleId,
            'session_date': current.toIso8601String().split('T')[0],
            'start_at': sessionStart.toIso8601String(),
            'end_at': sessionEnd.toIso8601String(),
            'status': 'scheduled',
          });
        }
        current = current.add(const Duration(days: 1));
      }
    }

    if (sessions.isNotEmpty) {
      await createSessionsBatch(sessions);
    }
  }

  // ─── Org stats ───────────────────────────────────

  Future<Map<String, int>> fetchOrgStats(String organizationId) async {
    try {
      final classesResult = await supabase
          .from('dance_classes')
          .select('id, status')
          .eq('organization_id', organizationId);

      final activeClasses = classesResult
          .where((c) => c['status'] == 'published')
          .length;

      final now = DateTime.now();
      final today = now.toIso8601String().split('T')[0];

      final sessionsResult = await supabase
          .from('dance_class_sessions')
          .select('id, status')
          .inFilter(
              'dance_class_id', classesResult.map((c) => c['id'] as String).toList())
          .gte('session_date', today);

      final upcomingSessions = sessionsResult
          .where((s) => s['status'] == 'scheduled')
          .length;

      final membersResult = await supabase
          .from('organization_members')
          .select('id')
          .eq('organization_id', organizationId)
          .eq('is_active', true);

      return {
        'totalClasses': classesResult.length,
        'activeClasses': activeClasses,
        'upcomingSessions': upcomingSessions,
        'totalMembers': membersResult.length,
      };
    } catch (e) {
      return {
        'totalClasses': 0,
        'activeClasses': 0,
        'upcomingSessions': 0,
        'totalMembers': 0,
      };
    }
  }

  // ─── Instructors ─────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchOrgInstructors(
      String organizationId) async {
    try {
      return await supabase
          .from('organization_members')
          .select('''
            id, user_id, role,
            profiles(first_name, last_name, phone_number, profile_image_url)
          ''')
          .eq('organization_id', organizationId)
          .eq('role', 'instructor')
          .eq('is_active', true)
          .order('created_at');
    } catch (e) {
      return [];
    }
  }

  // ─── Helpers ─────────────────────────────────────

  String _friendlyError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('permission denied') || msg.contains('row-level security')) {
      return 'No tienes permiso para realizar esta acción.';
    }
    if (msg.contains('duplicate key') || msg.contains('unique constraint')) {
      return 'Ya existe un registro con esos datos.';
    }
    return 'Error al guardar. Intenta de nuevo.';
  }
}
