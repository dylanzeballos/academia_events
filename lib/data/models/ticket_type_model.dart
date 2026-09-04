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
  bool get isSoldOut => availableQuantity <= 0;

  factory TicketTypeModel.fromJson(Map<String, dynamic> json) => TicketTypeModel(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: (json['price'] as num).toDouble(),
        currency: (json['currency'] as String?)?.trim() ?? 'BOB',
        quantity: json['quantity'] as int,
        soldQuantity: (json['sold_quantity'] as num?)?.toInt() ?? 0,
        salesStartAt: json['sales_start_at'] != null
            ? DateTime.tryParse(json['sales_start_at'] as String)
            : null,
        salesEndAt: json['sales_end_at'] != null
            ? DateTime.tryParse(json['sales_end_at'] as String)
            : null,
        isActive: (json['is_active'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'price': price,
        'currency': currency,
        'quantity': quantity,
        'is_active': isActive,
      };
}