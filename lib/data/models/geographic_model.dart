class DepartmentModel {
  const DepartmentModel({
    required this.id,
    required this.name,
    this.code,
  });

  final String id;
  final String name;
  final String? code;

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
    );
  }

  @override
  String toString() => name;
}

class ProvinceModel {
  const ProvinceModel({
    required this.id,
    required this.departmentId,
    required this.name,
  });

  final String id;
  final String departmentId;
  final String name;

  factory ProvinceModel.fromJson(Map<String, dynamic> json) {
    return ProvinceModel(
      id: json['id'] as String,
      departmentId: json['department_id'] as String,
      name: json['name'] as String,
    );
  }

  @override
  String toString() => name;
}

class MunicipalityModel {
  const MunicipalityModel({
    required this.id,
    required this.provinceId,
    required this.name,
  });

  final String id;
  final String provinceId;
  final String name;

  factory MunicipalityModel.fromJson(Map<String, dynamic> json) {
    return MunicipalityModel(
      id: json['id'] as String,
      provinceId: json['province_id'] as String,
      name: json['name'] as String,
    );
  }

  @override
  String toString() => name;
}

class CityModel {
  const CityModel({
    required this.id,
    required this.municipalityId,
    required this.name,
  });

  final String id;
  final String municipalityId;
  final String name;

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: json['id'] as String,
      municipalityId: json['municipality_id'] as String,
      name: json['name'] as String,
    );
  }

  @override
  String toString() => name;
}
