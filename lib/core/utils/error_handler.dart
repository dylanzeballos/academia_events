/// Convierte errores de Supabase/Postgres en mensajes amigables para el usuario.
String friendlyError(Object error) {
  final msg = error.toString().toLowerCase();

  // Errores de RLS / permisos
  if (msg.contains('permission denied') || msg.contains('row-level security')) {
    return 'No tienes permiso para realizar esta acción.';
  }
  if (msg.contains('violates row-level security')) {
    return 'No tienes acceso a este recurso.';
  }

  // Errores de constraint / duplicados
  if (msg.contains('duplicate key') || msg.contains('unique constraint')) {
    if (msg.contains('organizations_name_key')) {
      return 'Ya existe una organización con ese nombre.';
    }
    if (msg.contains('organization_members_organization_id_user_id')) {
      return 'Este usuario ya es miembro de la organización.';
    }
    return 'Ya existe un registro con esos datos.';
  }

  // Foreign key
  if (msg.contains('foreign key') || msg.contains('violates foreign key')) {
    return 'Referencia no válida. Verifica los datos ingresados.';
  }

  // Not found
  if (msg.contains('not found') || msg.contains('no rows')) {
    return 'No se encontró el recurso solicitado.';
  }

  // Auth errors
  if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (msg.contains('email not confirmed')) {
    return 'Tu correo aún no está verificado.';
  }
  if (msg.contains('user not found')) {
    return 'Usuario no encontrado.';
  }
  if (msg.contains('password')) {
    if (msg.contains('short')) return 'La contraseña debe tener al menos 8 caracteres.';
    return 'Error con la contraseña.';
  }

  // Network / timeout
  if (msg.contains('timeout') || msg.contains('timed out')) {
    return 'La conexión tardó demasiado. Intenta de nuevo.';
  }
  if (msg.contains('socket') || msg.contains('network')) {
    return 'Error de conexión. Verifica tu internet.';
  }

  // Work mem / internal
  if (msg.contains('work_mem') || msg.contains('out of memory')) {
    return 'Error interno. Intenta de nuevo más tarde.';
  }

  // Generic fallback
  if (msg.contains('error')) {
    // Try to extract a readable part
    final match = RegExp(r'error:\s*(.+)', caseSensitive: false)
        .firstMatch(error.toString());
    if (match != null) {
      final detail = match.group(1)!.trim();
      if (detail.length < 100) return detail;
    }
  }

  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}
