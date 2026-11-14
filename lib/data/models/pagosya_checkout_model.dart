/// Datos del checkout generado por PagosYa.
class PagosyaCheckout {
  const PagosyaCheckout({
    required this.orderId,
    required this.orderNumber,
    required this.checkoutId,
    required this.totalAmount,
    required this.currency,
    this.kind = 'ticket',
    this.referenceId,
    this.intentId,
    this.checkoutUrl,
    this.qrDataUrl,
  });

  /// `ticket` | `class_pass` | `membership`
  final String kind;
  final String orderId;
  final String orderNumber;
  final String checkoutId;
  final String? referenceId;
  final String? intentId;
  final double totalAmount;
  final String currency;
  final String? checkoutUrl;
  final String? qrDataUrl;

  bool get hasQr => (qrDataUrl ?? '').isNotEmpty;
  bool get hasUrl => (checkoutUrl ?? '').isNotEmpty;
  bool get isTicket => kind == 'ticket';

  factory PagosyaCheckout.fromJson(Map<String, dynamic> json) {
    final reference =
        json['reference_id'] as String? ?? json['order_id'] as String?;
    return PagosyaCheckout(
      kind: json['kind'] as String? ?? 'ticket',
      orderId: json['order_id'] as String? ?? reference ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      checkoutId: json['checkout_id'] as String? ?? '',
      referenceId: reference,
      intentId: json['intent_id'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'BOB',
      checkoutUrl: json['checkout_url'] as String?,
      qrDataUrl: json['qr_data_url'] as String?,
    );
  }
}

/// Estado de pago de un checkout (polling).
class PagosyaCheckoutStatus {
  const PagosyaCheckoutStatus({
    required this.orderId,
    required this.status,
    required this.paid,
    this.providerStatus,
  });

  final String orderId;
  final String status;
  final bool paid;
  final String? providerStatus;

  factory PagosyaCheckoutStatus.fromJson(Map<String, dynamic> json) {
    return PagosyaCheckoutStatus(
      orderId:
          json['order_id'] as String? ?? json['intent_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      paid: json['paid'] == true,
      providerStatus: json['provider_status'] as String?,
    );
  }
}
