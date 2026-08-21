class DanceCategoryModel {
  const DanceCategoryModel({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String name;
  final bool isActive;

  factory DanceCategoryModel.fromJson(Map<String, dynamic> json) {
    return DanceCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['isActive'] as bool
    );
  }
}