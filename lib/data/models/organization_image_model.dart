class OrganizationImageModel {
  const OrganizationImageModel({
    required this.id,
    required this.organizationId,
    required this.imageUrl,
    this.title,
    this.sortOrder = 0,
    this.createdAt,
  });

  final String id;
  final String organizationId;
  final String imageUrl;
  final String? title;
  final int sortOrder;
  final DateTime? createdAt;

  factory OrganizationImageModel.fromJson(Map<String, dynamic> json) {
    return OrganizationImageModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      imageUrl: json['image_url'] as String,
      title: json['title'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
