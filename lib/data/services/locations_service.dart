import '../../core/config/supabase_config.dart';

class LocationsService {
  const LocationsService();

  Future<List<Map<String, dynamic>>> fetchDepartments() async {
    final res = await supabase.from('departments').select('id, name').order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchProvinces(String departmentId) async {
    final res = await supabase
        .from('provinces')
        .select('id, name')
        .eq('department_id', departmentId)
        .order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchMunicipalities(String provinceId) async {
    final res = await supabase
        .from('municipalities')
        .select('id, name')
        .eq('province_id', provinceId)
        .order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchCities(String municipalityId) async {
    final res = await supabase
        .from('cities')
        .select('id, name')
        .eq('municipality_id', municipalityId)
        .order('name');
    return List<Map<String, dynamic>>.from(res);
  }
}