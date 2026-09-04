import 'dart:typed_data';

import '../models/class_model.dart';
import '../models/event_model.dart';
import '../services/events_service.dart';

abstract interface class IEventsRepository {
  Future<List<EventModel>> fetchWeekEvents(DateTime weekReference);
  Future<List<EventModel>> fetchOrganizationEvents(String organizationId);
  Future<EventModel> createEvent(Map<String, dynamic> data);
  Future<void> createFullEvent({
    required Map<String, dynamic> eventData,
    required Map<String, dynamic> locationData,
    List<Map<String, dynamic>>? ticketTypesData,
    Uint8List? bannerBytes,
    Uint8List? qrBytes,
  });
  Future<void> updateEvent(String id, Map<String, dynamic> data);
  Future<void> deleteEvent(String id);

  Future<List<EventModel>> fetchAllEvents();
  Future<EventModel> fetchEventById(String id);
}

class EventsRepository implements IEventsRepository {
  const EventsRepository({this.service = const EventsService()});

  final EventsService service;

  @override
  Future<List<EventModel>> fetchWeekEvents(DateTime weekReference) async {
    final monday = weekReference.subtract(
      Duration(days: weekReference.weekday - 1),
    );
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59));

    final rows = await service.fetchWeekEvents(
      monday.toIso8601String(),
      sunday.toIso8601String(),
    );

    final events = rows.map((row) => EventModel.fromJson(row)).toList();
    return _assignColors(events);
  }

  @override
  Future<List<EventModel>> fetchOrganizationEvents(
    String organizationId,
  ) async {
    final rows = await service.fetchOrganizationEvents(organizationId);
    return rows.map((row) => EventModel.fromJson(row)).toList();
  }

  @override
  Future<EventModel> createEvent(Map<String, dynamic> data) async {
    final row = await service.insertEvent(data);
    return EventModel.fromJson(row);
  }

  @override
  Future<List<EventModel>> fetchAllEvents() async {
    final rows = await service.fetchAllEvents();
    final events = rows.map((row) => EventModel.fromJson(row)).toList();
    return _assignColors(events);
  }

  @override
  Future<EventModel> fetchEventById(String id) async {
    final row = await service.fetchEventById(id);
    return EventModel.fromJson(row);
  }

  @override
  Future<void> createFullEvent({
    required Map<String, dynamic> eventData,
    required Map<String, dynamic> locationData,
    List<Map<String, dynamic>>? ticketTypesData,
    Uint8List? bannerBytes,
    Uint8List? qrBytes,
  }) async {
    // 1. Insertar evento base para generar su id
    final eventRow = await service.insertEvent(eventData);
    final eventId = eventRow['id'] as String;

    // 2. Subir banner a Storage y actualizar cover_image_url
    if (bannerBytes != null) {
      final imageUrl =
          await service.uploadImage('event-banners', '$eventId/banner', bannerBytes);
      await service.updateEvent(eventId, {'cover_image_url': imageUrl});
    }

    // 3. Insertar ubicación
    if ((locationData['location_name'] as String?)?.isNotEmpty == true ||
        (locationData['address_line_1'] as String?)?.isNotEmpty == true ||
        locationData['department_id'] != null) {
      await service.insertLocation({'event_id': eventId, ...locationData});
    }

    // 4. Subir QR a Storage e insertarlo en event_images
    if (qrBytes != null) {
      final qrUrl = await service.uploadImage('event-qrs', '$eventId/qr', qrBytes);
      await service.insertEventImage(eventId, qrUrl);
    }

    // 5. Insertar tipos de entradas (ticket_types) vinculados a este evento
    if (ticketTypesData != null && ticketTypesData.isNotEmpty) {
      final ticketsWithEventId = ticketTypesData.map((t) {
        return {
          ...t,
          'event_id': eventId,
        };
      }).toList();
      await service.insertTicketTypes(ticketsWithEventId);
    }
  }

  @override
  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    await service.updateEvent(id, data);
  }

  @override
  Future<void> deleteEvent(String id) async {
    await service.deleteEvent(id);
  }

  List<EventModel> _assignColors(List<EventModel> events) {
    final result = <EventModel>[];
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final usedColors = result
          .where((e) => e.overlapsWith(event))
          .map((e) => e.colorIndex)
          .toSet();

      var colorIndex = 0;
      while (usedColors.contains(colorIndex)) {
        colorIndex++;
      }
      result.add(event.copyWith(colorIndex: colorIndex));
    }
    return result;
  }
}

// ─── REPOSITORY DE CLASES ──────────────────────────────────────────

abstract interface class IClassesRepository {
  Future<List<ClassModel>> fetchOrganizationClasses(String organizationId);
  Future<ClassModel> createClass(Map<String, dynamic> data);
  Future<void> updateClass(String id, Map<String, dynamic> data);
  Future<void> deleteClass(String id);
  Future<List<EventModel>> fetchWeekClasses(DateTime weekReference);
}

class ClassesRepository implements IClassesRepository {
  const ClassesRepository({this.service = const EventsService()});

  final EventsService service;

  @override
  Future<List<ClassModel>> fetchOrganizationClasses(
    String organizationId,
  ) async {
    final rows = await service.fetchOrganizationClasses(organizationId);
    return rows
        .map((row) => ClassModel.fromJson({...row, 'organization_name': ''}))
        .toList();
  }

  @override
  Future<ClassModel> createClass(Map<String, dynamic> data) async {
    final row = await service.insertClass(data);
    return ClassModel.fromJson({...row, 'organization_name': ''});
  }

  @override
  Future<void> updateClass(String id, Map<String, dynamic> data) async {
    await service.updateClass(id, data);
  }

  @override
  Future<void> deleteClass(String id) async {
    await service.deleteClass(id);
  }

  @override
  Future<List<EventModel>> fetchWeekClasses(DateTime weekReference) async {
    final monday = weekReference.subtract(
      Duration(days: weekReference.weekday - 1),
    );
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59));

    final rows = await service.fetchWeekSchedules(
      monday.toIso8601String(),
      sunday.toIso8601String(),
    );

    final events = <EventModel>[];
    for (final row in rows) {
      final schedule = Map<String, dynamic>.from(row);
      final classData = (schedule['dance_classes'] as Map?) ?? const {};
      final orgName = (classData['organizations'] as Map?)?['name'] ?? '';

      final startDate = _parseDate(schedule['start_date']);
      final endDate = _parseDate(schedule['end_date']);

      // day_of_week: 0=domingo..6=sábado. weekday: 1=lunes..7=domingo.
      final scheduleWeekday = schedule['day_of_week'] == 0 ? 7 : schedule['day_of_week'];

      var day = monday;
      while (!day.isAfter(sunday)) {
        final matchesRecurrence =
            scheduleWeekday != null && day.weekday == scheduleWeekday;
        final dayDate = DateTime(day.year, day.month, day.day);
        final afterStart = startDate == null || !dayDate.isBefore(startDate);
        final beforeEnd = endDate == null || !dayDate.isAfter(endDate);
        final inRange = afterStart && beforeEnd;

        if (matchesRecurrence && inRange) {
          final startTimeStr = schedule['start_time'] as String;
          final endTimeStr = schedule['end_time'] as String;
          final startDateDay = DateTime(day.year, day.month, day.day);
          events.add(
            EventModel(
              id: 'class-${classData['id']}-${dayDate.toIso8601String().split('T')[0]}',
              title: classData['title'] as String? ?? '',
              organizationId: classData['organization_id'] as String? ?? '',
              organizationName: orgName,
              description: classData['description'] as String?,
              coverImageUrl: classData['cover_image_url'] as String?,
              startTime: DateTime(
                startDateDay.year,
                startDateDay.month,
                startDateDay.day,
                _hourOf(startTimeStr),
                _minuteOf(startTimeStr),
              ),
              endTime: DateTime(
                startDateDay.year,
                startDateDay.month,
                startDateDay.day,
                _hourOf(endTimeStr),
                _minuteOf(endTimeStr),
              ),
              timezone: classData['timezone'] as String? ?? 'America/La_Paz',
              status: 'published',
              visibility: 'public',
            ),
          );
        }
        day = day.add(const Duration(days: 1));
      }
    }

    return _assignColors(events);
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  static int _hourOf(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]);
  }

  static int _minuteOf(String time) {
    final parts = time.split(':');
    return parts.length > 1 ? int.parse(parts[1]) : 0;
  }

  List<EventModel> _assignColors(List<EventModel> events) {
    final result = <EventModel>[];
    for (final event in events) {
      final usedColors = result
          .where((e) => e.overlapsWith(event))
          .map((e) => e.colorIndex)
          .toSet();
      var colorIndex = 0;
      while (usedColors.contains(colorIndex)) {
        colorIndex++;
      }
      result.add(event.copyWith(colorIndex: colorIndex));
    }
    return result;
  }
}