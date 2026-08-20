class OrganizationModel {
  const OrganizationModel({
    required this.id,
    required this.name,
    this.legalName,
    this.description,
    this.logoUrl,
    this.cityId,
    this.cityName,
    this.websiteUrl,
    this.email,
    this.phoneNumber,
    this.taxIdentificationNumber,
    this.isActive = true,
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? legalName;
  final String? description;
  final String? logoUrl;
  final String? cityId;
  final String? cityName;
  final String? websiteUrl;
  final String? email;
  final String? phoneNumber;
  final String? taxIdentificationNumber;
  final bool isActive;
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      legalName: json['legal_name'] as String?,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      cityId: json['city_id'] as String?,
      cityName: (json['cities'] as Map<String, dynamic>?)?['name'] as String?,
      websiteUrl: json['website_url'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      taxIdentificationNumber: json['tax_identification_number'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      isVerified: (json['is_verified'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (legalName != null) 'legal_name': legalName,
        if (description != null) 'description': description,
        if (logoUrl != null) 'logo_url': logoUrl,
        if (cityId != null) 'city_id': cityId,
        if (websiteUrl != null) 'website_url': websiteUrl,
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (taxIdentificationNumber != null)
          'tax_identification_number': taxIdentificationNumber,
        'is_active': isActive,
      };

  OrganizationModel copyWith({
    String? name,
    String? legalName,
    String? description,
    String? logoUrl,
    String? cityId,
    String? websiteUrl,
    String? email,
    String? phoneNumber,
    String? taxIdentificationNumber,
    bool? isActive,
  }) {
    return OrganizationModel(
      id: id,
      name: name ?? this.name,
      legalName: legalName ?? this.legalName,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      cityId: cityId ?? this.cityId,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      taxIdentificationNumber:
          taxIdentificationNumber ?? this.taxIdentificationNumber,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
