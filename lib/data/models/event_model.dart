import 'event_location_model.dart';
import 'ticket_type_model.dart';

class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.organizationId,
    this.organizationName = '',
    this.organizationLogoUrl,
    this.categoryId,
    this.categoryName,
    this.danceCategoryIds = const [],
    this.description,
    this.coverImageUrl,
    this.qrImageUrl,
    this.location,
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
    this.ticketTypes = const [],
  });

  final String id;
  final String title;
  final String organizationId;
  final String organizationName;
  final String? organizationLogoUrl;
  final String? categoryId;
  final String? categoryName;
  final List<String> danceCategoryIds;
  final String? description;
  final String? coverImageUrl;
  final String? qrImageUrl;
  final EventLocationModel? location;
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
  final List<TicketTypeModel> ticketTypes;

  Duration get duration => endTime.difference(startTime);

  bool get isFull => capacity != null && capacity! <= 0;

  bool get isPublished => status == 'published';

  double? get startingPrice {
    if (ticketTypes.isEmpty) return null;
    final prices = ticketTypes.map((t) => t.price).toList()..sort();
    return prices.first;
  }

  bool overlapsWith(EventModel other) =>
      startTime.isBefore(other.endTime) && endTime.isAfter(other.startTime);

  EventModel copyWith({
    String? id,
    String? title,
    String? organizationId,
    String? organizationName,
    String? organizationLogoUrl,
    String? categoryId,
    String? categoryName,
    List<String>? danceCategoryIds,
    String? description,
    String? coverImageUrl,
    String? qrImageUrl,
    EventLocationModel? location,
    DateTime? startTime,
    DateTime? endTime,
    String? timezone,
    int? capacity,
    String? status,
    String? visibility,
    bool? requiresApproval,
    DateTime? publishedAt,
    DateTime? createdAt,
    int? colorIndex,
    List<TicketTypeModel>? ticketTypes,
  }) =>
      EventModel(
        id: id ?? this.id,
        title: title ?? this.title,
        organizationId: organizationId ?? this.organizationId,
        organizationName: organizationName ?? this.organizationName,
        organizationLogoUrl: organizationLogoUrl ?? this.organizationLogoUrl,
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
        danceCategoryIds: danceCategoryIds ?? this.danceCategoryIds,
        description: description ?? this.description,
        coverImageUrl: coverImageUrl ?? this.coverImageUrl,
        qrImageUrl: qrImageUrl ?? this.qrImageUrl,
        location: location ?? this.location,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        timezone: timezone ?? this.timezone,
        capacity: capacity ?? this.capacity,
        status: status ?? this.status,
        visibility: visibility ?? this.visibility,
        requiresApproval: requiresApproval ?? this.requiresApproval,
        publishedAt: publishedAt ?? this.publishedAt,
        createdAt: createdAt ?? this.createdAt,
        colorIndex: colorIndex ?? this.colorIndex,
        ticketTypes: ticketTypes ?? this.ticketTypes,
      );

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // 1. Manejo de Categoría
    final categoryData = json['event_categories'] as Map<String, dynamic>?;

    // 2. Manejo de Organización (nombre y logo)
    final orgData = json['organizations'] as Map<String, dynamic>?;
    final parsedOrgName = orgData?['name'] as String? ?? (json['organization_name'] as String?) ?? '';
    final parsedOrgLogo = orgData?['logo_url'] as String? ?? (json['organization_logo_url'] as String?);

    // 3. Manejo de Ubicación vinculada
    EventLocationModel? parsedLocation;
    if (json['event_locations'] != null) {
      if (json['event_locations'] is List && (json['event_locations'] as List).isNotEmpty) {
        parsedLocation = EventLocationModel.fromJson(
          (json['event_locations'] as List).first as Map<String, dynamic>,
        );
      } else if (json['event_locations'] is Map<String, dynamic>) {
        parsedLocation = EventLocationModel.fromJson(json['event_locations'] as Map<String, dynamic>);
      }
    }

    // 4. Manejo de Imágenes vinculadas / QR
    final imagesData = json['event_images'] as List?;
    String? qrUrl;
    if (imagesData != null && imagesData.isNotEmpty) {
      final firstImage = imagesData.first as Map<String, dynamic>?;
      qrUrl = firstImage?['image_url'] as String?;
    }

    // 5. Manejo de Tipos de Tickets
    final rawTickets = json['ticket_types'] as List?;
    final parsedTickets = rawTickets != null
        ? rawTickets
            .map((t) => TicketTypeModel.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList()
        : <TicketTypeModel>[];

    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      organizationId: json['organization_id'] as String,
      organizationName: parsedOrgName,
      organizationLogoUrl: parsedOrgLogo,
      categoryId: json['category_id'] as String?,
      categoryName: categoryData?['name'] as String? ?? (json['category_name'] as String?),
      danceCategoryIds: (json['event_dance_categories'] as List?)
              ?.map((c) =>
                  (c as Map)['dance_category_id'] as String? ??
                  '')
              .where((id) => id.isNotEmpty)
              .toList() ??
          const [],
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      qrImageUrl: qrUrl ?? (json['qr_image_url'] as String?),
      location: parsedLocation,
      startTime: DateTime.parse(json['start_at'] as String),
      endTime: DateTime.parse(json['end_at'] as String),
      timezone: (json['timezone'] as String?) ?? 'America/La_Paz',
      capacity: (json['capacity'] as num?)?.toInt(),
      status: (json['status'] as String?) ?? 'draft',
      visibility: (json['visibility'] as String?) ?? 'public',
      requiresApproval: (json['requires_approval'] as bool?) ?? true,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      ticketTypes: parsedTickets,
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
        if (location != null) 'event_locations': location!.toJson(),
      };
}