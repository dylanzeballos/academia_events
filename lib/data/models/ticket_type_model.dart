class TicketTypeModel {
  const TicketTypeModel({
    required this.id,
    required this.eventId,
    required this.name,
    this.description,
    required this.price,
    this.currency = 'BOB',
    required this.quantity,
    this.soldQuantity = 0,
    this.salesStartAt,
    this.salesEndAt,
    this.isActive = true,
  });

  final String id;
  final String eventId;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final int quantity;
  final int soldQuantity;
  final DateTime? salesStartAt;
  final DateTime? salesEndAt;
  final bool isActive;

  int get availableQuantity => quantity - soldQuantity;
  int get available => availableQuantity;
  bool get isSoldOut => availableQuantity <= 0;
  bool get hasStock => available > 0 && !isSoldOut;

  factory TicketTypeModel.fromJson(Map<String, dynamic> json) =>
      TicketTypeModel(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: (json['price'] as num).toDouble(),
        currency: (json['currency'] as String?)?.trim() ?? 'BOB',
        quantity: json['quantity'] as int,
        soldQuantity: (json['sold_quantity'] as num?)?.toInt() ?? 0,
        salesStartAt: json['sales_start_at'] != null
            ? DateTime.tryParse(json['sales_start_at'] as String)?.toLocal()
            : null,
        salesEndAt: json['sales_end_at'] != null
            ? DateTime.tryParse(json['sales_end_at'] as String)?.toLocal()
            : null,
        isActive: (json['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'name': name,
        'description': description,
        'price': price,
        'currency': currency,
        'quantity': quantity,
        'is_active': isActive,
        if (salesStartAt != null) 'sales_start_at': salesStartAt!.toUtc().toIso8601String(),
        if (salesEndAt != null) 'sales_end_at': salesEndAt!.toUtc().toIso8601String(),
      };

  /// Verifica si el ticket se encuentra disponible para compra en este momento exacto
  bool get isCurrentlyAvailable {
    final now = DateTime.now();
    if (salesStartAt != null && now.isBefore(salesStartAt!)) return false;
    if (salesEndAt != null && now.isAfter(salesEndAt!)) return false;
    return hasStock && isActive;
  }

  /// Verifica si la fecha límite de venta ya pasó
  bool get isExpired {
    if (salesEndAt == null) return false;
    return DateTime.now().isAfter(salesEndAt!);
  }

  /// Verifica si aún no se ha abierto la etapa de venta
  bool get isUpcoming {
    if (salesStartAt == null) return false;
    return DateTime.now().isBefore(salesStartAt!);
  }
}