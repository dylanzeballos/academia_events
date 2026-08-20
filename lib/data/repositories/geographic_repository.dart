import '../models/geographic_model.dart';
import '../services/geographic_service.dart';

abstract interface class IGeographicRepository {
  Future<List<DepartmentModel>> fetchDepartments();
  Future<List<ProvinceModel>> fetchProvinces(String departmentId);
  Future<List<MunicipalityModel>> fetchMunicipalities(String provinceId);
  Future<List<CityModel>> fetchCities(String municipalityId);
  Future<Map<String, String>?> resolveCityChain(String cityId);
}

class GeographicRepository implements IGeographicRepository {
  const GeographicRepository({GeographicService? service})
      : _service = service ?? const GeographicService();

  final GeographicService _service;

  @override
  Future<List<DepartmentModel>> fetchDepartments() async {
    final rows = await _service.fetchDepartments();
    return rows.map(DepartmentModel.fromJson).toList();
  }

  @override
  Future<List<ProvinceModel>> fetchProvinces(String departmentId) async {
    final rows = await _service.fetchProvinces(departmentId);
    return rows.map(ProvinceModel.fromJson).toList();
  }

  @override
  Future<List<MunicipalityModel>> fetchMunicipalities(String provinceId) async {
    final rows = await _service.fetchMunicipalities(provinceId);
    return rows.map(MunicipalityModel.fromJson).toList();
  }

  @override
  Future<List<CityModel>> fetchCities(String municipalityId) async {
    final rows = await _service.fetchCities(municipalityId);
    return rows.map(CityModel.fromJson).toList();
  }

  @override
  Future<Map<String, String>?> resolveCityChain(String cityId) =>
      _service.resolveCityChain(cityId);
}
