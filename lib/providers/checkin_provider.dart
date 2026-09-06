import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/check_in_result_model.dart';
import '../data/models/class_pass_model.dart';
import '../data/models/class_ticket_model.dart';
import '../data/models/dance_class_session_model.dart';
import '../data/repositories/checkin_repository.dart';
import 'class_enrollment_provider.dart';

final checkInRepositoryProvider = Provider<ICheckInRepository>((ref) {
  return const CheckInRepository();
});

/// Pases de clase del usuario autenticado.
final myClassPassesProvider =
    FutureProvider.autoDispose<List<ClassPassModel>>((ref) async {
  final repo = ref.watch(checkInRepositoryProvider);
  return repo.fetchMyClassPasses();
});

/// Tickets de clase (por sesión) del usuario autenticado, con token QR.
final myClassTicketsProvider =
    FutureProvider.autoDispose<List<ClassTicketModel>>((ref) async {
  final repo = ref.watch(checkInRepositoryProvider);
  return repo.fetchMyClassTickets();
});

/// Cotización del pase de clase (sesiones pendientes y precio total).
final classPassQuoteProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, enrollmentId) async {
  final repo = ref.watch(checkInRepositoryProvider);
  return repo.previewClassPass(enrollmentId);
});

/// Compra de un pase de clase (pago simulado). Devuelve el jsonb del RPC.
final purchaseClassPassProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, enrollmentId) async {
  final repo = ref.watch(checkInRepositoryProvider);
  return repo.purchaseClassPass(enrollmentId);
});

/// Sesiones programadas de una clase (para que el staff seleccione la sesión
/// a registrar en el check-in).
final checkinClassSessionsProvider = FutureProvider.autoDispose
    .family<List<DanceClassSessionModel>, String>((ref, classId) async {
  final repo = ref.watch(classEnrollmentRepositoryProvider);
  return repo.fetchSessionsForClass(classId);
});

/// Ejecuta el check-in de un ticket de evento.
final registerEventCheckInProvider = FutureProvider.autoDispose
    .family<CheckInResultModel,
        ({String tokenHash, String eventId, String? deviceId})>(
    (ref, args) async {
  final repo = ref.watch(checkInRepositoryProvider);
  return repo.registerEventCheckIn(
    tokenHash: args.tokenHash,
    eventId: args.eventId,
    deviceId: args.deviceId,
  );
});

/// Ejecuta el check-in de un ticket de sesión de clase.
final registerClassCheckInProvider = FutureProvider.autoDispose
    .family<CheckInResultModel,
        ({String tokenHash, String sessionId, String? deviceId})>(
    (ref, args) async {
  final repo = ref.watch(checkInRepositoryProvider);
  return repo.registerClassCheckIn(
    tokenHash: args.tokenHash,
    sessionId: args.sessionId,
    deviceId: args.deviceId,
  );
});