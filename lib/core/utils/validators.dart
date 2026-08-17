/// Validadores reutilizables para formularios de la app.
/// No tienen dependencias de Flutter, solo tipos primitivos Dart.
class AppValidators {
  AppValidators._();

  // ─────────────────── Auth ───────────────────

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu correo';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Correo inválido';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresa tu contraseña';
    if (v.length < 8) return 'Debe tener al menos 8 caracteres';
    return null;
  }

  static String? confirmPassword(String? password, String? confirmation) {
    final c = confirmation ?? '';
    if (c.isEmpty) return 'Confirma tu contraseña';
    if ((password ?? '') != c) return 'Las contraseñas no coinciden';
    return null;
  }

  // ─────────────────── Nombres ───────────────────

  static String? firstName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu nombre';
    if (v.length < 2) return 'Nombre demasiado corto';
    return null;
  }

  static String? lastName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu apellido';
    if (v.length < 2) return 'Apellido demasiado corto';
    return null;
  }

  static String? requiredField(String? value, {String label = 'Este campo'}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return '$label es requerido';
    return null;
  }

  // ─────────────────── Contacto ───────────────────

  static String? phone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null; // Teléfono es opcional
    if (!RegExp(r'^[0-9+\-()\s]{8,20}$').hasMatch(v)) {
      return 'Teléfono inválido';
    }
    return null;
  }

  // ─────────────────── Fechas ───────────────────

  static String? birthDate(DateTime? date) {
    if (date == null) return null;
    final today = DateTime.now();
    if (date.isAfter(today)) return 'La fecha no puede ser futura';
    if (date.isBefore(DateTime(today.year - 120, today.month, today.day))) {
      return 'Fecha de nacimiento inválida';
    }
    return null;
  }

  // ─────────────────── Eventos / Clases ───────────────────

  static String? eventTitle(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa un título';
    if (v.length < 3) return 'Título demasiado corto';
    if (v.length > 100) return 'Título demasiado largo';
    return null;
  }

  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Precio opcional
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Precio inválido';
    if (parsed < 0) return 'El precio no puede ser negativo';
    return null;
  }

  static String? capacity(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Cupo opcional
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Número inválido';
    if (parsed < 1) return 'El cupo mínimo es 1';
    return null;
  }
}

// Alias de compatibilidad con el código antiguo
typedef AuthValidators = AppValidators;
