import '../models/check_in_result_model.dart';
import '../models/class_pass_model.dart';
import '../models/class_ticket_model.dart';
import '../services/checkin_service.dart';

abstract interface class ICheckInRepository {
  Future<Map<String, dynamic>> previewClassPass(String enrollmentId);

  Future<Map<String, dynamic>> purchaseClassPass(String enrollmentId);

  Future<List<ClassPassModel>> fetchMyClassPasses();

  Future<List<ClassTicketModel>> fetchMyClassTickets();

  Future<CheckInResultModel> registerEventCheckIn({
    required String tokenHash,
    required String eventId,
    String? deviceId,
  });

  Future<CheckInResultModel> registerClassCheckIn({
    required String tokenHash,
    required String sessionId,
    String? deviceId,
  });
}

class CheckInRepository implements ICheckInRepository {
  const CheckInRepository({CheckInService? service})
      : _service = service ?? const CheckInService();

  final CheckInService _service;

  @override
  Future<Map<String, dynamic>> previewClassPass(String enrollmentId) async {
    return _service.previewClassPass(enrollmentId);
  }

  @override
  Future<Map<String, dynamic>> purchaseClassPass(String enrollmentId) async {
    return _service.purchaseClassPass(enrollmentId);
  }

  @override
  Future<List<ClassPassModel>> fetchMyClassPasses() async {
    final rows = await _service.fetchMyClassPasses();
    return rows.map((row) => ClassPassModel.fromJson(row)).toList();
  }

  @override
  Future<List<ClassTicketModel>> fetchMyClassTickets() async {
    final rows = await _service.fetchMyClassTickets();
    return rows.map((row) => ClassTicketModel.fromJson(row)).toList();
  }

  @override
  Future<CheckInResultModel> registerEventCheckIn({
    required String tokenHash,
    required String eventId,
    String? deviceId,
  }) async {
    final raw = await _service.registerEventCheckIn(
      tokenHash: tokenHash,
      eventId: eventId,
      deviceId: deviceId,
    );
    return CheckInResultModel.fromJson(raw);
  }

  @override
  Future<CheckInResultModel> registerClassCheckIn({
    required String tokenHash,
    required String sessionId,
    String? deviceId,
  }) async {
    final raw = await _service.registerClassCheckIn(
      tokenHash: tokenHash,
      sessionId: sessionId,
      deviceId: deviceId,
    );
    return CheckInResultModel.fromJson(raw);
  }
}