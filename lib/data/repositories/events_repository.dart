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
    Uint8List? bannerBytes,
    Uint8List? qrBytes,
  });
  Future<void> updateEvent(String id, Map<String, dynamic> data);
  Future<void> deleteEvent(String id);
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

    final events = rows.map((row) {
      final json = Map<String, dynamic>.from(row);
      json['organization_name'] = (row['organizations'] as Map?)?['name'] ?? '';
      return EventModel.fromJson(json);
    }).toList();

    return _assignColors(events);
  }

  @override
  Future<List<EventModel>> fetchOrganizationEvents(
    String organizationId,
  ) async {
    final rows = await service.fetchOrganizationEvents(organizationId);

    return rows
        .map((row) => EventModel.fromJson({...row, 'organization_name': ''}))
        .toList();
  }

  @override
  Future<EventModel> createEvent(Map<String, dynamic> data) async {
    final row = await service.insertEvent(data);
    return EventModel.fromJson({...row, 'organization_name': ''});
  }

  @override
  Future<void> createFullEvent({
    required Map<String, dynamic> eventData,
    required Map<String, dynamic> locationData,
    Uint8List? bannerBytes,
    Uint8List? qrBytes,
  }) async {
    // 1. Subir afiche
    if (bannerBytes != null) {
      final imageUrl = await service.uploadImage('event-banners', bannerBytes);
      eventData['cover_image_url'] = imageUrl;
    }

    // 2. Insertar evento
    final eventRow = await service.insertEvent(eventData);
    final eventId = eventRow['id'] as String;

    // 3. Insertar ubicación
    if ((locationData['location_name'] as String?)?.isNotEmpty == true ||
        (locationData['address_line_1'] as String?)?.isNotEmpty == true ||
        locationData['department_id'] != null) {
      await service.insertLocation({
        'event_id': eventId,
        ...locationData, 
      });
    }

    // 4. Subir QR e insertar
    if (qrBytes != null) {
      final qrUrl = await service.uploadImage('event-qrs', qrBytes);
      await service.insertEventImage(eventId, qrUrl);
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

// ─── REPOSITORY DE CLASES (Refactorizado con EventsService) ───────

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

    final rows = await service.fetchWeekClasses(
      monday.toIso8601String(),
      sunday.toIso8601String(),
    );

    final classes = rows.map((row) {
      final json = Map<String, dynamic>.from(row);
      json['organization_name'] = (row['organizations'] as Map?)?['name'] ?? '';
      return ClassModel.fromJson(json);
    }).toList();

    final events = classes.map((c) => c.toEventModel()).toList();
    return _assignColors(events);
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
