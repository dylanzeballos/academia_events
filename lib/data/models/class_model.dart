import 'event_model.dart';

class ClassModel {
  const ClassModel({
    required this.id,
    required this.title,
    required this.organizationId,
    this.organizationName = '',
    this.description,
    this.coverImageUrl,
    this.status = 'draft',
    this.capacity,
    this.enrolledCount = 0,
    this.price = 0,
    this.currency = 'BOB',
    this.startTime,
    this.endTime,
    this.timezone = 'America/La_Paz',
    this.instructorId,
    this.instructorName,
  });

  final String id;
  final String title;
  final String organizationId;
  final String organizationName;
  final String? description;
  final String? coverImageUrl;
  final String status;
  final int? capacity;
  final int enrolledCount;
  final double price;
  final String currency;
  final DateTime? startTime;
  final DateTime? endTime;
  final String timezone;
  final String? instructorId;
  final String? instructorName;

  bool get isPublished => status == 'published';

  EventModel toEventModel({int colorIndex = 0}) {
    return EventModel(
      id: id,
      title: title,
      organizationId: organizationId,
      organizationName: organizationName,
      description: description,
      coverImageUrl: coverImageUrl,
      startTime: startTime ?? DateTime.now(),
      endTime: endTime ?? DateTime.now().add(const Duration(hours: 1)),
      timezone: timezone,
      capacity: capacity,
      status: status,
      colorIndex: colorIndex,
    );
  }

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    final instructorProfile = json['profiles'] as Map<String, dynamic>?;
    final firstName = instructorProfile?['first_name'] as String? ?? '';
    final lastName = instructorProfile?['last_name'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();

    return ClassModel(
      id: json['id'] as String,
      title: json['title'] as String,
      organizationId: json['organization_id'] as String,
      organizationName: (json['organization_name'] as String?) ?? '',
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      status: (json['status'] as String?) ?? 'draft',
      capacity: json['capacity'] as int?,
      enrolledCount: (json['enrolled_count'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?) ?? 'BOB',
      startTime: json['start_at'] != null
          ? DateTime.tryParse(json['start_at'] as String)
          : null,
      endTime: json['end_at'] != null
          ? DateTime.tryParse(json['end_at'] as String)
          : null,
      timezone: (json['timezone'] as String?) ?? 'America/La_Paz',
      instructorId: json['instructor_id'] as String?,
      instructorName: fullName.isNotEmpty ? fullName : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'organization_id': organizationId,
        'description': description,
        'cover_image_url': coverImageUrl,
        'status': status,
        'capacity': capacity,
        'price': price,
        'currency': currency,
        'start_at': startTime?.toIso8601String(),
        'end_at': endTime?.toIso8601String(),
        'timezone': timezone,
        'instructor_id': instructorId,
      };
}
