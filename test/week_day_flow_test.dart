import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:academia_events/data/models/class_model.dart';
import 'package:academia_events/data/models/event_model.dart';
import 'package:academia_events/data/repositories/events_repository.dart';
import 'package:academia_events/features/calendar/week_calendar_view.dart';
import 'package:academia_events/providers/events_provider.dart';

class _FakeEventsRepo implements IEventsRepository {
  _FakeEventsRepo(this.events);

  final List<EventModel> events;

  @override
  Future<List<EventModel>> fetchWeekEvents(DateTime weekReference) async =>
      events;

  @override
  Future<List<EventModel>> fetchOrganizationEvents(
    String organizationId,
  ) async =>
      events;

  @override
  Future<EventModel> createEvent(Map<String, dynamic> data) =>
      throw UnimplementedError();

  @override
  Future<void> createFullEvent({
    required Map<String, dynamic> eventData,
    required Map<String, dynamic> locationData,
    List<Map<String, dynamic>>? ticketTypesData,
    Uint8List? bannerBytes,
    Uint8List? qrBytes,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> updateEvent(String id, Map<String, dynamic> data) =>
      throw UnimplementedError();

  @override
  Future<void> deleteEvent(String id) => throw UnimplementedError();

  @override
  Future<List<EventModel>> fetchAllEvents() async => events;

  @override
  Future<EventModel> fetchEventById(String id) =>
      throw UnimplementedError();
}

class _FakeClassesRepo implements IClassesRepository {
  _FakeClassesRepo(this.classes);

  final List<EventModel> classes;

  @override
  Future<List<EventModel>> fetchWeekClasses(DateTime weekReference) async =>
      classes;

  @override
  Future<List<ClassModel>> fetchOrganizationClasses(
    String organizationId,
  ) =>
      throw UnimplementedError();

  @override
  Future<ClassModel> createClass(Map<String, dynamic> data) =>
      throw UnimplementedError();

  @override
  Future<void> updateClass(String id, Map<String, dynamic> data) =>
      throw UnimplementedError();

  @override
  Future<void> deleteClass(String id) => throw UnimplementedError();
}

EventModel _event({
  required String id,
  required String title,
  required DateTime start,
  required DateTime end,
}) =>
    EventModel(
      id: id,
      title: title,
      organizationId: 'org-1',
      organizationName: 'Org',
      startTime: start,
      endTime: end,
      status: 'published',
    );

void main() {
  setUpAll(() {
    Intl.defaultLocale = 'es';
    return initializeDateFormatting('es');
  });

  testWidgets(
    'al tocar un chip de día distinto a hoy se abre la vista de día con '
    'SOLO los eventos de ese día (las clases no se muestran en el calendario)',
    (tester) async {
      final monday = DateTime(2025, 1, 6);
      final events = [
        _event(
          id: 'e1',
          title: 'Evento Lunes',
          start: DateTime(2025, 1, 6, 19, 0),
          end: DateTime(2025, 1, 6, 20, 30),
        ),
        _event(
          id: 'e-wed',
          title: 'Evento Miércoles',
          start: DateTime(2025, 1, 8, 19, 0),
          end: DateTime(2025, 1, 8, 20, 30),
        ),
        _event(
          id: 'e2',
          title: 'Evento Viernes',
          start: DateTime(2025, 1, 10, 10, 0),
          end: DateTime(2025, 1, 10, 11, 0),
        ),
      ];
      // La clase no debe aparecer en el calendario: aunque el repo de clases
      // la devuelva, el Horario solo muestra eventos.
      final classes = [
        _event(
          id: 'class-wed',
          title: 'Clase Miércoles',
          start: DateTime(2025, 1, 8, 19, 0),
          end: DateTime(2025, 1, 8, 20, 30),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          eventsRepositoryProvider
              .overrideWithValue(_FakeEventsRepo(events)),
          classesRepositoryProvider
              .overrideWithValue(_FakeClassesRepo(classes)),
        ],
      );
      addTearDown(container.dispose);

      container.read(selectedWeekProvider.notifier).setWeek(monday);
      container.read(selectedDayProvider.notifier).setDay(monday);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WeekCalendarView()),
        ),
      );
      await tester.pumpAndSettle();

      // La vista de semana muestra todos los días de la ventana.
      expect(find.text('Evento Lunes'), findsOneWidget);
      expect(find.text('Evento Miércoles'), findsOneWidget);
      expect(find.text('Evento Viernes'), findsOneWidget);
      // Las clases no se muestran en el calendario.
      expect(find.text('Clase Miércoles'), findsNothing);

      // Tocar el chip del miércoles (día 8).
      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();

      // La vista de día muestra SOLO el miércoles: ni el lunes (6) ni el
      // viernes (10) aparecen aunque estén en la ventana de datos.
      expect(find.text('Evento Miércoles'), findsOneWidget);
      expect(find.text('Evento Lunes'), findsNothing);
      expect(find.text('Evento Viernes'), findsNothing);
      expect(find.text('Clase Miércoles'), findsNothing);
      expect(find.text('1 evento'), findsOneWidget);

      // La tarjeta del miércoles (19:00) debe quedar DENTRO de la pantalla.
      // El timeline es completo (0-24 h) pero la vista se desplaza
      // automáticamente al primer evento del día para que el evento de la
      // noche (19:00) no quede fuera de pantalla.
      final tileRect = tester.getRect(find.text('Evento Miércoles'));
      expect(tileRect.height, greaterThan(0));
      expect(tileRect.top, greaterThanOrEqualTo(0));
      expect(tileRect.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
      // El timeline arranca en 00:00 (horas completas del costado).
      expect(find.text('00:00'), findsOneWidget);

      // Navegar al día siguiente (jueves 9, sin eventos).
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('Evento Miércoles'), findsNothing);
      expect(find.text('Evento Viernes'), findsNothing);
      expect(find.text('Sin eventos'), findsOneWidget);

      // Volver al miércoles con la flecha de día anterior.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('Evento Miércoles'), findsOneWidget);

      // Volver a la semana (la semana quedó anclada al día 8: ventana 8..14,
      // de modo que el evento del viernes sigue visible en el grid semanal).
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Evento Miércoles'), findsOneWidget);
      expect(find.text('Evento Viernes'), findsOneWidget);
      expect(find.text('Evento Lunes'), findsNothing);

      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();

      // Día 10: solo el evento del viernes.
      expect(find.text('Evento Viernes'), findsOneWidget);
      expect(find.text('Evento Miércoles'), findsNothing);
      expect(find.text('Evento Lunes'), findsNothing);
      expect(find.text('Clase Miércoles'), findsNothing);
    },
  );
}