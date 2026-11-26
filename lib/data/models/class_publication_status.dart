/// Estado de publicación de una clase para su organización
/// (espejo del RPC `class_publication_status`).
///
/// Publicar una clase está incluido en la suscripción: solo se informa si la
/// membresía mensual está vigente. `alreadyPaid` queda por compatibilidad con
/// pagos de publicación anteriores a ese cambio.
class ClassPublicationStatus {
  const ClassPublicationStatus({
    required this.alreadyPaid,
    required this.monthlyMembership,
    required this.requiresPayment,
  });

  /// Existe un pago de publicación previo (flujo anterior).
  final bool alreadyPaid;

  /// La organización tiene suscripción mensual vigente.
  final bool monthlyMembership;

  /// Las clases nunca requieren pago de publicación.
  final bool requiresPayment;

  factory ClassPublicationStatus.fromJson(Map<String, dynamic> json) {
    return ClassPublicationStatus(
      alreadyPaid: json['already_paid'] as bool? ?? false,
      monthlyMembership: json['monthly_membership'] as bool? ?? false,
      requiresPayment: json['requires_payment'] as bool? ?? false,
    );
  }
}
