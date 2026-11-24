/// Estado de publicación de una clase para su organización
/// (espejo del RPC `class_publication_status`).
class ClassPublicationStatus {
  const ClassPublicationStatus({
    required this.alreadyPaid,
    required this.monthlyMembership,
    this.price,
  });

  /// Ya existe un pago de publicación registrado.
  final bool alreadyPaid;

  /// La organización tiene suscripción mensual vigente.
  final bool monthlyMembership;

  /// Precio de publicación configurado por la plataforma (null = no configurado).
  final double? price;

  bool get hasPrice => price != null && price! > 0;

  factory ClassPublicationStatus.fromJson(Map<String, dynamic> json) {
    return ClassPublicationStatus(
      alreadyPaid: json['already_paid'] as bool? ?? false,
      monthlyMembership: json['monthly_membership'] as bool? ?? false,
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}
