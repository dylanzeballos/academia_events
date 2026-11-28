import 'event_model.dart';

class ClassModel {
  const ClassModel({
    required this.id,
    required this.title,
    required this.organizationId,
    this.organizationName = '',
    this.organizationLogoUrl,
    this.description,
    this.coverImageUrl,
    this.status = 'draft',
    this.capacity,
    this.enrolledCount = 0,
    this.price = 0,
    this.priceMonthly = 0,
    this.danceCategoryId,
    this.danceCategoryName,
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
  final String? organizationLogoUrl;
  final String? description;
  final String? coverImageUrl;
  final String status;
  final int? capacity;
  final int enrolledCount;
  final double price;
  final double priceMonthly;
  final String? danceCategoryId;
  final String? danceCategoryName;
  final String currency;
  final DateTime? startTime;
  final DateTime? endTime;
  final String timezone;
  final String? instructorId;
  final String? instructorName;

  bool get isPublished => status == 'published';
  bool get hasMonthlyPass => priceMonthly > 0;

  /// `price` se mantiene como precio por sesión para no romper la UI previa.
  double get pricePerSession => price;

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
    final organization = json['organizations'] as Map<String, dynamic>?;
    final firstName = instructorProfile?['first_name'] as String? ?? '';
    final lastName = instructorProfile?['last_name'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();

    return ClassModel(
      id: json['id'] as String,
      title: json['title'] as String,
      organizationId: json['organization_id'] as String,
      organizationName:
          (organization?['name'] as String?) ??
          (json['organization_name'] as String?) ??
          '',
      organizationLogoUrl:
          (organization?['logo_url'] as String?) ??
          (json['organization_logo_url'] as String?),
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      status: (json['status'] as String?) ?? 'draft',
      capacity: json['capacity'] as int?,
      enrolledCount: (json['enrolled_count'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      priceMonthly: (json['price_monthly'] as num?)?.toDouble() ?? 0,
      danceCategoryId: json['dance_category_id'] as String?,
      danceCategoryName:
          (json['dance_categories'] as Map<String, dynamic>?)?['name']
              as String?,
      currency: (json['currency'] as String?) ?? 'BOB',
      startTime: json['start_at'] != null
          ? DateTime.tryParse(json['start_at'] as String)?.toLocal()
          : null,
      endTime: json['end_at'] != null
          ? DateTime.tryParse(json['end_at'] as String)?.toLocal()
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
    'price_monthly': priceMonthly,
    'dance_category_id': danceCategoryId,
    'currency': currency,
    'start_at': startTime?.toUtc().toIso8601String(),
    'end_at': endTime?.toUtc().toIso8601String(),
    'timezone': timezone,
    'instructor_id': instructorId,
  };
}
