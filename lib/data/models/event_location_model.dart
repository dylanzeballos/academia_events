import 'geographic_model.dart';

class EventLocationModel {
  const EventLocationModel({
    this.id,
    this.eventId,
    this.departmentId,
    this.provinceId,
    this.municipalityId,
    this.cityId,
    this.locationName,
    this.addressLine1,
    this.addressLine2,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.department,
    this.province,
    this.municipality,
    this.city,
  });

  final String? id;
  final String? eventId;
  final String? departmentId;
  final String? provinceId;
  final String? municipalityId;
  final String? cityId;
  final String? locationName;
  final String? addressLine1;
  final String? addressLine2;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final DepartmentModel? department;
  final ProvinceModel? province;
  final MunicipalityModel? municipality;
  final CityModel? city;

  factory EventLocationModel.fromJson(Map<String, dynamic> json) {
    DepartmentModel? department;
    if (json['departments'] != null) {
      department = DepartmentModel.fromJson(json['departments'] as Map<String, dynamic>);
    }

    ProvinceModel? province;
    if (json['provinces'] != null) {
      province = ProvinceModel.fromJson(json['provinces'] as Map<String, dynamic>);
    }

    MunicipalityModel? municipality;
    if (json['municipalities'] != null) {
      municipality = MunicipalityModel.fromJson(json['municipalities'] as Map<String, dynamic>);
    }

    CityModel? city;
    if (json['cities'] != null) {
      city = CityModel.fromJson(json['cities'] as Map<String, dynamic>);
    }

    return EventLocationModel(
      id: json['id'] as String?,
      eventId: json['event_id'] as String?,
      departmentId: json['department_id'] as String?,
      provinceId: json['province_id'] as String?,
      municipalityId: json['municipality_id'] as String?,
      cityId: json['city_id'] as String?,
      locationName: json['location_name'] as String?,
      addressLine1: json['address_line_1'] as String?,
      addressLine2: json['address_line_2'] as String?,
      postalCode: json['postal_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      department: department,
      province: province,
      municipality: municipality,
      city: city,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (eventId != null) 'event_id': eventId,
        'department_id': departmentId,
        'province_id': provinceId,
        'municipality_id': municipalityId,
        'city_id': cityId,
        'location_name': locationName,
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'postal_code': postalCode,
        'latitude': latitude,
        'longitude': longitude,
      };
}