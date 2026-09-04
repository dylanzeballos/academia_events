import 'event_location_model.dart';
import 'dance_category_model.dart';
import 'public_ticket_type_model.dart';

class PublicEventModel {
  const PublicEventModel({
    required this.id,
    required this.title,
    required this.organizationId,
    this.organizationName = '',
    this.organizationLogoUrl,
    this.categoryId,
    this.categoryName,
    this.description,
    this.coverImageUrl,
    this.qrImageUrl,
    this.location,
    required this.startTime,
    required this.endTime,
    this.timezone = 'America/La_Paz',
    this.capacity,
    this.status = 'published',
    this.visibility = 'public',
    this.requiresApproval = true,
    this.publishedAt,
    this.createdAt,
    this.colorIndex = 0,
    this.minPrice,
    this.currency = 'BOB',
    this.danceCategories = const [],
    this.images = const [],
    this.ticketTypes = const [],
  });

  final String id;
  final String title;
  final String organizationId;
  final String organizationName;
  final String? organizationLogoUrl;
  final String? categoryId;
  final String? categoryName;
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
  final double? minPrice;
  final String currency;
  final List<DanceCategoryModel> danceCategories;
  final List<String> images;
  final List<PublicTicketTypeModel> ticketTypes;

  Duration get duration => endTime.difference(startTime);

  bool get isFull => capacity != null && capacity! <= 0;

  bool get isPublished => status == 'published';

  bool overlapsWith(PublicEventModel other) =>
      startTime.isBefore(other.endTime) && endTime.isAfter(other.startTime);

  PublicEventModel copyWith({
    String? id,
    String? title,
    String? organizationId,
    String? organizationName,
    String? organizationLogoUrl,
    String? categoryId,
    String? categoryName,
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
    double? minPrice,
    String? currency,
    List<DanceCategoryModel>? danceCategories,
    List<String>? images,
    List<PublicTicketTypeModel>? ticketTypes,
  }) {
    return PublicEventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      organizationLogoUrl: organizationLogoUrl ?? this.organizationLogoUrl,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
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
      minPrice: minPrice ?? this.minPrice,
      currency: currency ?? this.currency,
      danceCategories: danceCategories ?? this.danceCategories,
      images: images ?? this.images,
      ticketTypes: ticketTypes ?? this.ticketTypes,
    );
  }

  factory PublicEventModel.fromJson(Map<String, dynamic> json) {
    final categoryData = json['event_categories'] as Map<String, dynamic>?;

    EventLocationModel? parsedLocation;
    if (json['event_locations'] != null) {
      if (json['event_locations'] is List && (json['event_locations'] as List).isNotEmpty) {
        parsedLocation = EventLocationModel.fromJson(
            (json['event_locations'] as List).first as Map<String, dynamic>);
      } else if (json['event_locations'] is Map<String, dynamic>) {
        parsedLocation = EventLocationModel.fromJson(json['event_locations'] as Map<String, dynamic>);
      }
    }

    final orgData = json['organizations'] as Map<String, dynamic>?;
    final orgName = orgData?['name'] as String? ?? '';
    final orgLogo = orgData?['logo_url'] as String?;

    final imagesData = json['event_images'] as List?;
    final images = imagesData?.map((e) => e['image_url'] as String).whereType<String>().toList() ?? [];

    final danceCategoriesData = json['event_dance_categories'] as List?;
    final danceCategories = danceCategoriesData?.map((e) {
      final cat = e['dance_categories'] as Map<String, dynamic>?;
      return cat != null ? DanceCategoryModel.fromJson(cat) : null;
    }).whereType<DanceCategoryModel>().toList() ?? [];

    final ticketTypesData = json['ticket_types'] as List?;
    final ticketTypes = ticketTypesData?.map((e) => PublicTicketTypeModel.fromJson(e as Map<String, dynamic>)).toList() ?? [];

    double? minPrice;
    if (ticketTypes.isNotEmpty) {
      final activeTickets = ticketTypes.where((t) => t.isOnSale).toList();
      if (activeTickets.isNotEmpty) {
        minPrice = activeTickets.map((t) => t.price).reduce((a, b) => a < b ? a : b);
      }
    }

    return PublicEventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      organizationId: json['organization_id'] as String,
      organizationName: orgName,
      organizationLogoUrl: orgLogo,
      categoryId: json['category_id'] as String?,
      categoryName: categoryData?['name'] as String? ?? (json['category_name'] as String?),
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      qrImageUrl: json['qr_image_url'] as String?,
      location: parsedLocation,
      startTime: DateTime.parse(json['start_at'] as String),
      endTime: DateTime.parse(json['end_at'] as String),
      timezone: (json['timezone'] as String?) ?? 'America/La_Paz',
      capacity: (json['capacity'] as num?)?.toInt(),
      status: (json['status'] as String?) ?? 'published',
      visibility: (json['visibility'] as String?) ?? 'public',
      requiresApproval: (json['requires_approval'] as bool?) ?? true,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      colorIndex: json['color_index'] as int? ?? 0,
      minPrice: minPrice,
      currency: (json['currency'] as String?) ?? 'BOB',
      danceCategories: danceCategories,
      images: images,
      ticketTypes: ticketTypes,
    );
  }
}