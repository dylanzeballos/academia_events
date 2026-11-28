/// Sesión de clase disponible para comprar (espejo del RPC
/// `list_class_purchase_sessions`).
class PurchasableSession {
  const PurchasableSession({
    required this.id,
    required this.sessionDate,
    required this.startAt,
    required this.endAt,
    this.capacity,
    this.occupied = 0,
    this.pricePerSession = 0,
    this.currency = 'BOB',
    this.alreadyPurchased = false,
  });

  final String id;
  final DateTime sessionDate;
  final DateTime startAt;
  final DateTime endAt;
  final int? capacity;
  final int occupied;
  final double pricePerSession;
  final String currency;
  final bool alreadyPurchased;

  int? get slotsLeft =>
      capacity == null ? null : (capacity! - occupied).clamp(0, capacity!);
  bool get isFull => capacity != null && occupied >= capacity!;
  bool get isSelectable => !isFull && !alreadyPurchased;

  factory PurchasableSession.fromJson(Map<String, dynamic> json) {
    return PurchasableSession(
      id: json['id'] as String,
      sessionDate: DateTime.parse(json['session_date'] as String),
      startAt: DateTime.parse(json['start_at'] as String).toLocal(),
      endAt: DateTime.parse(json['end_at'] as String).toLocal(),
      capacity: (json['capacity'] as num?)?.toInt(),
      occupied: (json['occupied'] as num?)?.toInt() ?? 0,
      pricePerSession: (json['price_per_session'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?)?.trim() ?? 'BOB',
      alreadyPurchased: json['already_purchased'] as bool? ?? false,
    );
  }
}
