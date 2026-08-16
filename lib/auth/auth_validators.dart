class AuthValidators {
  static String? validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'Ingresa tu correo';
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Correo invalido';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Ingresa tu password';
    }
    if (password.length < 8) {
      return 'Debe tener al menos 8 caracteres';
    }
    return null;
  }

  static String? validatePasswordConfirmation(
    String? password,
    String? confirmation,
  ) {
    final confirmationValue = confirmation ?? '';
    if (confirmationValue.isEmpty) {
      return 'Confirma tu password';
    }
    if ((password ?? '') != confirmationValue) {
      return 'Las passwords no coinciden';
    }
    return null;
  }

  static String? validateName(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Ingresa tu nombre';
    }
    if (trimmed.length < 2) {
      return 'Nombre demasiado corto';
    }
    return null;
  }

  static String? validateLastName(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Ingresa tu apellido';
    }
    if (trimmed.length < 2) {
      return 'Apellido demasiado corto';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) {
      return null;
    }

    final phoneRegex = RegExp(r'^[0-9+\-()\s]{8,20}$');
    if (!phoneRegex.hasMatch(phone)) {
      return 'Telefono invalido';
    }

    return null;
  }

  static String? validateBirthDate(DateTime? date) {
    if (date == null) {
      return null;
    }
    final today = DateTime.now();
    final minDate = DateTime(today.year - 120, today.month, today.day);
    if (date.isBefore(minDate)) {
      return 'Fecha de nacimiento invalida';
    }
    if (date.isAfter(today)) {
      return 'La fecha no puede ser futura';
    }
    return null;
  }
}