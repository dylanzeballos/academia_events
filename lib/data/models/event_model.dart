class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.organizationId,
    this.organizationName = '',
    this.categoryId,
    this.description,
    this.coverImageUrl,
    required this.startTime,
    required this.endTime,
    this.timezone = 'America/La_Paz',
    this.capacity,
    this.status = 'draft',
    this.visibility = 'public',
    this.requiresApproval = true,
    this.publishedAt,
    this.createdAt,
    this.colorIndex = 0,
  });

  final String id;
  final String title;
  final String organizationId;
  final String organizationName;
  final String? categoryId;
  final String? description;
  final String? coverImageUrl;
  final DateTime startTime;
  final DateTime endTime;
  final String timezone;
  final int? capacity;
  final String status;
  final String visibility;
  final bool requiresApproval;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final int colorIndex;

  Duration get duration => endTime.difference(startTime);

  bool get isFull => capacity != null && capacity! <= 0;

  bool get isPublished => status == 'published';

  bool overlapsWith(EventModel other) =>
      startTime.isBefore(other.endTime) && endTime.isAfter(other.startTime);

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      organizationId: json['organization_id'] as String,
      organizationName: (json['organization_name'] as String?) ?? '',
      categoryId: json['category_id'] as String?,
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      startTime: DateTime.parse(json['start_at'] as String),
      endTime: DateTime.parse(json['end_at'] as String),
      timezone: (json['timezone'] as String?) ?? 'America/La_Paz',
      capacity: json['capacity'] as int?,
      status: (json['status'] as String?) ?? 'draft',
      visibility: (json['visibility'] as String?) ?? 'public',
      requiresApproval: (json['requires_approval'] as bool?) ?? true,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'organization_id': organizationId,
        'category_id': categoryId,
        'description': description,
        'cover_image_url': coverImageUrl,
        'start_at': startTime.toIso8601String(),
        'end_at': endTime.toIso8601String(),
        'timezone': timezone,
        'capacity': capacity,
        'status': status,
        'visibility': visibility,
        'requires_approval': requiresApproval,
      };

  EventModel copyWith({int? colorIndex}) => EventModel(
        id: id,
        title: title,
        organizationId: organizationId,
        organizationName: organizationName,
        categoryId: categoryId,
        description: description,
        coverImageUrl: coverImageUrl,
        startTime: startTime,
        endTime: endTime,
        timezone: timezone,
        capacity: capacity,
        status: status,
        visibility: visibility,
        requiresApproval: requiresApproval,
        publishedAt: publishedAt,
        createdAt: createdAt,
        colorIndex: colorIndex ?? this.colorIndex,
      );
}
