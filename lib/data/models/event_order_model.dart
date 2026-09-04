class EventOrderModel {
  const EventOrderModel({
    required this.orderId,
    required this.orderNumber,
    required this.totalAmount,
    required this.currency,
  });

  final String orderId;
  final String orderNumber;
  final double totalAmount;
  final String currency;

  factory EventOrderModel.fromJson(Map<String, dynamic> json) => EventOrderModel(
        orderId: json['order_id'] as String,
        orderNumber: json['order_number'] as String,
        totalAmount: (json['total_amount'] as num).toDouble(),
        currency: json['currency'] as String,
      );
}