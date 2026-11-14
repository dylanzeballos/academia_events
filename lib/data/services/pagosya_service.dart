import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/event_purchase_result_model.dart';
import '../models/pagosya_checkout_model.dart';
import 'ticket_service.dart';

/// Cliente de las Edge Functions de PagosYa.
///
/// La app nunca usa la clave `spk_`: solo envía el JWT del usuario y la
/// función `pagosya-api` habla con PagosYa desde el backend.
class PagosyaService {
  const PagosyaService();

  /// [kind]: `ticket` | `class_pass` | `membership`.
  /// [referenceId]: id de la orden, inscripción o suscripción.
  Future<PagosyaCheckout> createCheckout({
    required String kind,
    required String referenceId,
    List<String>? seatIds,
  }) async {
    final data = await _invoke({
      'action': 'create_checkout',
      'kind': kind,
      'reference_id': referenceId,
      if (seatIds != null && seatIds.isNotEmpty) 'seat_ids': seatIds,
    });
    return PagosyaCheckout.fromJson(data);
  }

  /// Genera un QR de publicación de evento o clase (solo admin de plataforma).
  Future<PagosyaCheckout> createPublicationCheckout({
    required String kind,
    required String referenceId,
    required double amount,
  }) async {
    final data = await _invoke({
      'action': 'create_checkout',
      'kind': kind,
      'reference_id': referenceId,
      'amount': amount,
    });
    return PagosyaCheckout.fromJson(data);
  }

  /// Consulta el estado del pago. Usa [intentId] para pases/membresías o
  /// [orderId] para tickets.
  Future<PagosyaCheckoutStatus> refreshCheckout({
    String? orderId,
    String? intentId,
  }) async {
    final data = await _invoke({
      'action': 'refresh_checkout',
      if (intentId != null) 'intent_id': intentId,
      if (orderId != null) 'reference_id': orderId,
    });
    return PagosyaCheckoutStatus.fromJson(data);
  }

  Future<EventPurchaseResult> fetchOrderTickets(String orderId) async {
    try {
      final result = await supabase.rpc(
        'get_order_tickets',
        params: {'p_order_id': orderId},
      );
      return EventPurchaseResult.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } on PostgrestException catch (e) {
      throw TicketException(e.message);
    }
  }

  Future<Map<String, dynamic>> bankSession(String organizationId) async {
    return _invoke({
      'action': 'create_bank_session',
      'organization_id': organizationId,
    });
  }

  Future<Map<String, dynamic>> merchantSummary(String organizationId) async {
    return _invoke({
      'action': 'merchant_summary',
      'organization_id': organizationId,
    });
  }

  Future<Map<String, dynamic>> merchantCreate(String organizationId) async {
    return _invoke({
      'action': 'merchant_create',
      'organization_id': organizationId,
    });
  }

  Future<Map<String, dynamic>> commissionSession(String organizationId) async {
    return _invoke({
      'action': 'create_commission_session',
      'organization_id': organizationId,
    });
  }

  Future<Map<String, dynamic>> overview({int offset = 0}) async {
    return _invoke({'action': 'overview', 'offset': offset});
  }

  Future<Map<String, dynamic>> webhookGet() async {
    return _invoke({'action': 'webhook_get'});
  }

  Future<Map<String, dynamic>> webhookSet({
    required String url,
    required bool enabled,
    bool rotate = false,
  }) async {
    return _invoke({
      'action': 'webhook_set',
      'url': url,
      'enabled': enabled,
      'rotate': rotate,
    });
  }

  Future<Map<String, dynamic>> webhookRetry(String eventId) async {
    return _invoke({'action': 'webhook_retry', 'event_id': eventId});
  }

  Future<Map<String, dynamic>> registerPlatformMerchant() async {
    return _invoke({'action': 'platform_merchant_create'});
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await supabase.functions.invoke(
        'pagosya-api',
        body: body,
      );
      final data = response.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final error = map['error'];
        if (error is String) {
          // mensajes de negocio (p. ej. "Ya tienes un pase activo") viajan tal cual
          throw TicketException(
            error.contains(' ') ? error : _translate(error),
          );
        }
        return map;
      }
      throw const TicketException('Respuesta inválida de PagosYa');
    } on FunctionException catch (e) {
      throw TicketException(_translate(_errorCode(e)));
    } on TicketException {
      rethrow;
    } catch (e) {
      throw TicketException('No se pudo conectar con PagosYa: $e');
    }
  }

  String _errorCode(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final error = details['error'];
      if (error is String) return error;
    }
    return 'PAGOSYA_ERROR_${e.status}';
  }

  String _translate(String code) {
    switch (code) {
      case 'ORGANIZATION_NOT_ONBOARDED':
        return 'La organización todavía no tiene su cuenta de cobros configurada.';
      case 'BANK_INTEGRATION_REQUIRED':
        return 'El banco del comercio aún no está conectado.';
      case 'ORDER_ALREADY_PAID':
        return 'Esta orden ya fue pagada.';
      case 'ORDER_NOT_PENDING':
        return 'La orden no está pendiente de pago.';
      case 'ORDER_NOT_FOUND':
        return 'No se encontró la orden.';
      case 'CHECKOUT_NOT_CREATED':
        return 'Todavía no se generó el cobro para esta operación.';
      case 'CLASS_PASS_NOT_AVAILABLE':
        return 'El pase de clase no está disponible.';
      case 'SUBSCRIPTION_NOT_FOUND':
        return 'No se encontró la membresía.';
      case 'SUBSCRIPTION_NOT_PAYABLE':
        return 'La membresía no está pendiente de pago.';
      case 'PLATFORM_MERCHANT_NOT_CONFIGURED':
        return 'La cuenta de cobros de la plataforma no está configurada.';
      case 'INTENT_NOT_FOUND':
        return 'No se encontró el cobro.';
      case 'AMOUNT_REQUIRED':
        return 'Ingresa un monto válido para la publicación.';
      case 'PUBLICATION_TARGET_NOT_FOUND':
        return 'No se encontró el evento o la clase.';
      case 'PUBLICATION_ALREADY_PAID':
        return 'La publicación ya fue pagada.';
      case 'WEBHOOK_URL_REQUIRED':
        return 'Ingresa la URL pública del webhook.';
      case 'INVALID_WEBHOOK_URL':
        return 'La URL debe ser HTTPS, pública y sin parámetros.';
      case 'EVENT_ID_REQUIRED':
        return 'Falta el identificador del evento.';
      case 'UNAUTHENTICATED':
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
      case 'PAGOSYA_NOT_CONFIGURED':
        return 'La pasarela de pagos no está configurada.';
      default:
        return 'No se pudo procesar el pago ($code).';
    }
  }
}
