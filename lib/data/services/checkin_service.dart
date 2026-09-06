import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class CheckInException implements Exception {
  const CheckInException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Servicio para el flujo de tickets de clase y check-in con QR.
///
/// REGLA CRÍTICA: toda la validación la hace el servidor (RPCs). Este
/// servicio solo invoca las funciones y devuelve su resultado tal cual.
class CheckInService {
  const CheckInService();

  // ─── Pase de clase (estudiante) ──────────────────

  /// Cotización del pase (sesiones pendientes, precio unitario y total)
  /// sin crear nada.
  Future<Map<String, dynamic>> previewClassPass(String enrollmentId) async {
    try {
      final result = await supabase.rpc('preview_class_pass', params: {
        'p_enrollment_id': enrollmentId,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw CheckInException(_friendlyError(e.message));
    }
  }

  /// Compra (pago simulado) de un pase de clase para una inscripción.
  Future<Map<String, dynamic>> purchaseClassPass(String enrollmentId) async {
    try {
      final result = await supabase.rpc('purchase_class_pass', params: {
        'p_enrollment_id': enrollmentId,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw CheckInException(_friendlyError(e.message));
    }
  }

  /// Pases del usuario autenticado.
  Future<List<Map<String, dynamic>>> fetchMyClassPasses() async {
    try {
      final result = await supabase.rpc('fetch_my_class_passes');
      final list = (result as List).cast<Map<String, dynamic>>();
      return list;
    } on PostgrestException catch (e) {
      throw CheckInException(e.message);
    }
  }

  /// Tickets diarios del usuario autenticado con su token QR.
  Future<List<Map<String, dynamic>>> fetchMyClassTickets() async {
    try {
      final result = await supabase.rpc('fetch_my_class_tickets');
      final list = (result as List).cast<Map<String, dynamic>>();
      return list;
    } on PostgrestException catch (e) {
      throw CheckInException(e.message);
    }
  }

  // ─── Check-in (staff) ─────────────────────────────

  /// Registra el check-in de un ticket de evento.
  Future<Map<String, dynamic>> registerEventCheckIn({
    required String tokenHash,
    required String eventId,
    String? deviceId,
  }) async {
    try {
      final result = await supabase.rpc('register_event_check_in', params: {
        'p_token_hash': tokenHash,
        'p_event_id': eventId,
        'p_device_id': deviceId,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw CheckInException(_friendlyError(e.message));
    }
  }

  /// Registra la asistencia de una sesión de clase mediante su ticket QR.
  Future<Map<String, dynamic>> registerClassCheckIn({
    required String tokenHash,
    required String sessionId,
    String? deviceId,
  }) async {
    try {
      final result = await supabase.rpc('register_class_check_in', params: {
        'p_token_hash': tokenHash,
        'p_session_id': sessionId,
        'p_device_id': deviceId,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw CheckInException(_friendlyError(e.message));
    }
  }

  // ─── Helpers ─────────────────────────────────────

  String _friendlyError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('permiso') || msg.contains('permission') ||
        msg.contains('row-level security') || msg.contains('authorization')) {
      return 'No tienes autorización para realizar esta acción.';
    }
    return 'No se pudo completar la operación. Intenta de nuevo.';
  }
}