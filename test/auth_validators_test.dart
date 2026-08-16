import 'package:flutter_test/flutter_test.dart';
import 'package:academia_events/auth/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('validateEmail devuelve error para correo invalido', () {
      final result = AuthValidators.validateEmail('correo-invalido');
      expect(result, isNotNull);
    });

    test('validateEmail acepta correo valido', () {
      final result = AuthValidators.validateEmail('test@example.com');
      expect(result, isNull);
    });

    test('validatePassword exige minimo 8 caracteres', () {
      final result = AuthValidators.validatePassword('12345');
      expect(result, isNotNull);
    });

    test('validatePasswordConfirmation detecta mismatch', () {
      final result = AuthValidators.validatePasswordConfirmation(
        'Password123',
        'PasswordABC',
      );
      expect(result, isNotNull);
    });

    test('validateName requiere texto minimo', () {
      final result = AuthValidators.validateName('A');
      expect(result, isNotNull);
    });

    test('validateLastName requiere texto minimo', () {
      final result = AuthValidators.validateLastName('B');
      expect(result, isNotNull);
    });

    test('validatePhone permite vacio y valida formato', () {
      final empty = AuthValidators.validatePhone('');
      final invalid = AuthValidators.validatePhone('abc123');
      final valid = AuthValidators.validatePhone('+57 300 123 4567');

      expect(empty, isNull);
      expect(invalid, isNotNull);
      expect(valid, isNull);
    });

    test('validateBirthDate rechaza fecha futura', () {
      final futureDate = DateTime.now().add(const Duration(days: 1));
      final result = AuthValidators.validateBirthDate(futureDate);
      expect(result, isNotNull);
    });
  });
}