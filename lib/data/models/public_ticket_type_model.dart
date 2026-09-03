class PublicTicketTypeModel {
  const PublicTicketTypeModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    required this.quantity,
    required this.soldQuantity,
    this.salesStartAt,
    this.salesEndAt,
    this.isActive = true,
  });

  final String id;
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
  bool get isOnSale {
    final now = DateTime.now();
    if (salesStartAt != null && salesStartAt!.isAfter(now)) return false;
    if (salesEndAt != null && salesEndAt!.isBefore(now)) return false;
    return isActive && !isSoldOut;
  }

  factory PublicTicketTypeModel.fromJson(Map<String, dynamic> json) {
    return PublicTicketTypeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'BOB',
      quantity: (json['quantity'] as num).toInt(),
      soldQuantity: (json['sold_quantity'] as num?)?.toInt() ?? 0,
      salesStartAt: json['sales_start_at'] != null
          ? DateTime.tryParse(json['sales_start_at'] as String)
          : null,
      salesEndAt: json['sales_end_at'] != null
          ? DateTime.tryParse(json['sales_end_at'] as String)
          : null,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}