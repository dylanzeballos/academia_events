/// Organización activa que tiene al menos una clase publicada.
///
/// Se usa para el flujo de exploración: carrusel de organizaciones →
/// clases `published` de esa organización → botón "Inscribirme".
class OrganizationWithClasses {
  const OrganizationWithClasses({
    required this.id,
    required this.name,
    this.logoUrl,
    this.description,
    this.cityId,
    this.publishedClassCount = 0,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String? description;
  final String? cityId;
  final int publishedClassCount;

  factory OrganizationWithClasses.fromJson(Map<String, dynamic> json) {
    final classes = json['dance_classes'] as List? ?? const [];
    return OrganizationWithClasses(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      description: json['description'] as String?,
      cityId: json['city_id'] as String?,
      publishedClassCount: classes.length,
    );
  }

  OrganizationWithClasses copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? description,
    String? cityId,
    int? publishedClassCount,
  }) {
    return OrganizationWithClasses(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      description: description ?? this.description,
      cityId: cityId ?? this.cityId,
      publishedClassCount: publishedClassCount ?? this.publishedClassCount,
    );
  }
}