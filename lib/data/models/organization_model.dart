class OrganizationModel {
  const OrganizationModel({
    required this.id,
    required this.name,
    this.legalName,
    this.description,
    this.logoUrl,
    this.coverImageUrl,
    this.websiteUrl,
    this.email,
    this.phoneNumber,
    this.taxIdentificationNumber,
    this.isActive = true,
    this.isVerified = false,
    this.departmentId,
    this.provinceId,
    this.municipalityId,
    this.locationName,
    this.address,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? legalName;
  final String? description;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? websiteUrl;
  final String? email;
  final String? phoneNumber;
  final String? taxIdentificationNumber;
  final bool isActive;
  final bool isVerified;

  // Ubicación y sede física
  final String? departmentId;
  final String? provinceId;
  final String? municipalityId;
  final String? locationName;
  final String? address;
  final double? latitude;
  final double? longitude;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OrganizationModel.fromJson(Map json) {
    return OrganizationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      legalName: json['legal_name'] as String?,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      websiteUrl: json['website_url'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      taxIdentificationNumber: json['tax_identification_number'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      departmentId: json['department_id'] as String?,
      provinceId: json['province_id'] as String?,
      municipalityId: json['municipality_id'] as String?,
      locationName: json['location_name'] as String?,
      address: json['address'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map toJson() {
    return {
      'id': id,
      'name': name,
      'legal_name': legalName,
      'description': description,
      'logo_url': logoUrl,
      'cover_image_url': coverImageUrl,
      'website_url': websiteUrl,
      'email': email,
      'phone_number': phoneNumber,
      'tax_identification_number': taxIdentificationNumber,
      'is_active': isActive,
      'is_verified': isVerified,
      'department_id': departmentId,
      'province_id': provinceId,
      'municipality_id': municipalityId,
      'location_name': locationName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}