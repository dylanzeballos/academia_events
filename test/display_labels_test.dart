import 'package:flutter_test/flutter_test.dart';
import 'package:academia_events/core/utils/display_labels.dart';

void main() {
  group('DisplayLabels', () {
    test('traduce estados de negocio que llegan de Supabase', () {
      expect(DisplayLabels.status('pending_approval'), 'Pendiente de aprobación');
      expect(DisplayLabels.status('past_due'), 'Pago atrasado');
      expect(DisplayLabels.status('paid'), 'Pagado');
    });

    test('traduce roles, tipos de pago y frecuencias', () {
      expect(DisplayLabels.role('check_in_staff'), 'Personal de acceso');
      expect(DisplayLabels.paymentType('event_publication'), 'Publicación de evento');
      expect(DisplayLabels.interval('yearly'), 'Anual');
    });

    test('no expone valores desconocidos de base de datos en inglés', () {
      expect(DisplayLabels.status('some_new_state'), 'Sin estado');
      expect(DisplayLabels.role('some_new_role'), 'Otro rol');
    });
  });
}
