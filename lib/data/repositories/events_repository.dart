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
    Uint8List? rulesPdfBytes,
    String? venueId,
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
    final start = DateTime(
      weekReference.year,
      weekReference.month,
      weekReference.day,
    );
    final end = start.add(const Duration(days: 7));

    final rows = await service.fetchWeekEvents(
      start.toUtc().toIso8601String(),
      end.toUtc().toIso8601String(),
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
    Uint8List? rulesPdfBytes,
    String? venueId,
  }) async {
    final eventRow = await service.insertEvent(eventData);
    final eventId = eventRow['id'] as String;

    if (bannerBytes != null) {
      final imageUrl = await service.uploadImage(
        'event-banners',
        '$eventId/banner',
        bannerBytes,
      );
      await service.updateEvent(eventId, {'cover_image_url': imageUrl});
    }

    if (rulesPdfBytes != null) {
      final pdfUrl = await service.uploadRulesPdf(eventId, rulesPdfBytes);
      await service.updateEvent(eventId, {'rules_pdf_url': pdfUrl});
    }

    if ((locationData['location_name'] as String?)?.isNotEmpty == true ||
        (locationData['address_line_1'] as String?)?.isNotEmpty == true ||
        locationData['department_id'] != null) {
      await service.insertLocation({'event_id': eventId, ...locationData});
    }

    if (qrBytes != null) {
      final qrUrl = await service.uploadImage(
        'event-qrs',
        '$eventId/qr',
        qrBytes,
      );
      await service.insertEventImage(eventId, qrUrl);
    }

    if (venueId != null && venueId.isNotEmpty) {
      final defaultPrice =
          (ticketTypesData?.firstOrNull?['price'] as num?)?.toDouble() ?? 50.0;
      await service.cloneVenueSeats(
        eventId: eventId,
        venueId: venueId,
        defaultPrice: defaultPrice,
      );
    }

    if (ticketTypesData != null && ticketTypesData.isNotEmpty) {
      final ticketsWithEventId = ticketTypesData
          .map((t) => {...t, 'event_id': eventId})
          .toList();
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
    final start = DateTime(
      weekReference.year,
      weekReference.month,
      weekReference.day,
    );
    final endExclusive = start.add(const Duration(days: 7));

    final rows = await service.fetchWeekSchedules(
      start.toIso8601String(),
      endExclusive.toIso8601String(),
    );

    final events = <EventModel>[];
    for (final row in rows) {
      final schedule = Map<String, dynamic>.from(row);
      final classData = (schedule['dance_classes'] as Map?) ?? const {};
      final orgName = (classData['organizations'] as Map?)?['name'] ?? '';

      final startDate = _parseDate(schedule['start_date']);
      final endDate = _parseDate(schedule['end_date']);

      final scheduleWeekday = schedule['day_of_week'] == 0
          ? 7
          : schedule['day_of_week'];

      var day = start;
      while (day.isBefore(endExclusive)) {
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