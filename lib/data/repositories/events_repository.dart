import '../../core/config/supabase_config.dart';
import '../models/event_model.dart';
import '../models/class_model.dart';

abstract interface class IEventsRepository {
  Future<List<EventModel>> fetchWeekEvents(DateTime weekReference);
  Future<List<EventModel>> fetchOrganizationEvents(String organizationId);
  Future<EventModel> createEvent(Map<String, dynamic> data);
  Future<void> updateEvent(String id, Map<String, dynamic> data);
  Future<void> deleteEvent(String id);
}

class EventsRepository implements IEventsRepository {
  const EventsRepository();

  @override
  Future<List<EventModel>> fetchWeekEvents(DateTime weekReference) async {
    final monday = weekReference.subtract(
      Duration(days: weekReference.weekday - 1),
    );
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59));

    final rows = await supabase
        .from('events')
        .select('''
          id, title, organization_id, category_id,
          description, cover_image_url,
          start_at, end_at, timezone,
          capacity, status, visibility,
          requires_approval, published_at, created_at,
          organizations!inner(name)
        ''')
        .gte('start_at', monday.toIso8601String())
        .lte('start_at', sunday.toIso8601String())
        .eq('status', 'published')
        .order('start_at');

    final events = rows.map((row) {
      final json = Map<String, dynamic>.from(row);
      json['organization_name'] =
          (row['organizations'] as Map?)?['name'] ?? '';
      return EventModel.fromJson(json);
    }).toList();

    return _assignColors(events);
  }

  @override
  Future<List<EventModel>> fetchOrganizationEvents(
      String organizationId) async {
    final rows = await supabase
        .from('events')
        .select(
          'id, title, organization_id, category_id, '
          'description, cover_image_url, '
          'start_at, end_at, timezone, '
          'capacity, status, visibility, '
          'requires_approval, published_at, created_at',
        )
        .eq('organization_id', organizationId)
        .order('start_at');

    return rows
        .map((row) => EventModel.fromJson({...row, 'organization_name': ''}))
        .toList();
  }

  @override
  Future<EventModel> createEvent(Map<String, dynamic> data) async {
    final row = await supabase
        .from('events')
        .insert(data)
        .select()
        .single();
    return EventModel.fromJson({...row, 'organization_name': ''});
  }

  @override
  Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    await supabase.from('events').update(data).eq('id', id);
  }

  @override
  Future<void> deleteEvent(String id) async {
    await supabase.from('events').delete().eq('id', id);
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

abstract interface class IClassesRepository {
  Future<List<ClassModel>> fetchOrganizationClasses(String organizationId);
  Future<ClassModel> createClass(Map<String, dynamic> data);
  Future<void> updateClass(String id, Map<String, dynamic> data);
  Future<void> deleteClass(String id);
  Future<List<EventModel>> fetchWeekClasses(DateTime weekReference);
}

class ClassesRepository implements IClassesRepository {
  const ClassesRepository();

  @override
  Future<List<ClassModel>> fetchOrganizationClasses(
      String organizationId) async {
    final rows = await supabase
        .from('dance_classes')
        .select(
          'id, title, organization_id, '
          'description, cover_image_url, '
          'status, capacity, price, currency, '
          'start_at, end_at, timezone',
        )
        .eq('organization_id', organizationId)
        .order('start_at');

    return rows
        .map((row) =>
            ClassModel.fromJson({...row, 'organization_name': ''}))
        .toList();
  }

  @override
  Future<ClassModel> createClass(Map<String, dynamic> data) async {
    final row = await supabase
        .from('dance_classes')
        .insert(data)
        .select()
        .single();
    return ClassModel.fromJson({...row, 'organization_name': ''});
  }

  @override
  Future<void> updateClass(String id, Map<String, dynamic> data) async {
    await supabase.from('dance_classes').update(data).eq('id', id);
  }

  @override
  Future<void> deleteClass(String id) async {
    await supabase.from('dance_classes').delete().eq('id', id);
  }

  @override
  Future<List<EventModel>> fetchWeekClasses(DateTime weekReference) async {
    final monday = weekReference.subtract(
      Duration(days: weekReference.weekday - 1),
    );
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59));

    final rows = await supabase
        .from('dance_classes')
        .select('''
          id, title, organization_id,
          description, cover_image_url,
          status, capacity, price, currency,
          start_at, end_at, timezone,
          organizations!inner(name)
        ''')
        .gte('start_at', monday.toIso8601String())
        .lte('start_at', sunday.toIso8601String())
        .eq('status', 'published')
        .order('start_at');

    final classes = rows.map((row) {
      final json = Map<String, dynamic>.from(row);
      json['organization_name'] =
          (row['organizations'] as Map?)?['name'] ?? '';
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
