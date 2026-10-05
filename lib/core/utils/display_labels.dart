/// Traduce valores técnicos del backend para mostrarlos en la interfaz.
/// Los valores almacenados y enviados a Supabase permanecen sin cambios.
abstract final class DisplayLabels {
  static const _statuses = <String, String>{
    'pending_approval': 'Pendiente de aprobación',
    'pending': 'Pendiente',
    'approved': 'Aprobado',
    'rejected': 'Rechazado',
    'suspended': 'Suspendido',
    'active': 'Activa',
    'inactive': 'Inactiva',
    'past_due': 'Pago atrasado',
    'expired': 'Expirada',
    'cancelled': 'Cancelada',
    'canceled': 'Cancelada',
    'processing': 'En proceso',
    'paid': 'Pagado',
    'failed': 'Fallido',
    'refunded': 'Reembolsado',
    'draft': 'Borrador',
    'published': 'Publicado',
    'unpublished': 'No publicado',
    'scheduled': 'Programada',
    'completed': 'Completado',
    'present': 'Presente',
    'late': 'Con retraso',
    'absent': 'Ausente',
    'issued': 'Emitido',
    'used': 'Utilizado',
    'accepted': 'Aceptada',
    'declined': 'Rechazada',
    'open': 'Abierto',
    'private': 'Privado',
    'public': 'Público',
  };

  static const _roles = <String, String>{
    'owner': 'Propietario',
    'admin': 'Administrador',
    'manager': 'Gerente',
    'event_manager': 'Gestor de eventos',
    'eventmanager': 'Gestor de eventos',
    'instructor': 'Instructor',
    'check_in_staff': 'Personal de acceso',
    'checkinstaff': 'Personal de acceso',
    'staff': 'Personal',
    'member': 'Miembro',
    'user': 'Usuario',
    'student': 'Estudiante',
    'academy': 'Organización',
    'supervisor': 'Supervisor',
    'platformadmin': 'Administrador de plataforma',
    'teacher': 'Docente',
    'dancer': 'Bailarín',
    'choreographer': 'Coreógrafo',
  };

  static const _paymentTypes = <String, String>{
    'ticket': 'Entrada',
    'subscription': 'Membresía',
    'event_publication': 'Publicación de evento',
    'class_publication': 'Publicación de clase',
    'other': 'Otro pago',
  };

  static const _intervals = <String, String>{
    'monthly': 'Mensual',
    'month': 'Mensual',
    'yearly': 'Anual',
    'year': 'Anual',
    'one_time': 'Pago único',
  };

  static const _providers = <String, String>{
    'manual_pending': 'Pago pendiente de verificación',
    'manual_verified': 'Verificado manualmente',
    'manual': 'Registro manual',
    'simulated': 'Pago simulado',
  };

  static const _actions = <String, String>{
    'submitted': 'Enviado a revisión',
    'published': 'Publicado',
    'unpublished': 'Despublicado',
    'cancelled': 'Cancelado',
    'membership_requested': 'Solicitud de membresía',
    'membership_activated': 'Membresía activada',
    'membership_rejected': 'Membresía rechazada',
    'organization_activated': 'Organización activada',
    'organization_suspended': 'Organización suspendida',
    'payout_registered': 'Liquidación registrada',
    'payout_processing': 'Liquidación en proceso',
    'payout_paid': 'Liquidación pagada',
    'payout_failed': 'Liquidación fallida',
    'payout_cancelled': 'Liquidación cancelada',
    'event_moderation_pending_approval': 'Evento enviado a revisión',
    'event_moderation_approved': 'Evento aprobado',
    'event_moderation_rejected': 'Evento rechazado',
    'event_moderation_suspended': 'Evento suspendido',
  };

  static String status(Object? value, {String fallback = 'Sin estado'}) =>
      _lookup(_statuses, value, fallback);

  static String role(Object? value, {String fallback = 'Otro rol'}) =>
      _lookup(_roles, value, fallback);

  static String paymentType(Object? value) =>
      _lookup(_paymentTypes, value, 'Otro pago');

  static String interval(Object? value) =>
      _lookup(_intervals, value, 'Frecuencia no especificada');

  static String provider(Object? value) =>
      _lookup(_providers, value, 'Otro proveedor de pago');

  static String action(Object? value) =>
      _lookup(_actions, value, 'Otra acción administrativa');

  static String _lookup(Map<String, String> labels, Object? value, String fallback) {
    final key = value?.toString().trim().toLowerCase().replaceAll('-', '_');
    if (key == null || key.isEmpty) return fallback;
    return labels[key] ?? fallback;
  }
}
