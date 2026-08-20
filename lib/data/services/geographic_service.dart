import '../../core/config/supabase_config.dart';

class GeographicService {
  const GeographicService();

  Future<List<Map<String, dynamic>>> fetchDepartments() async {
    try {
      return await supabase
          .from('departments')
          .select('id, name, code')
          .order('name');
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchProvinces(String departmentId) async {
    try {
      return await supabase
          .from('provinces')
          .select('id, department_id, name')
          .eq('department_id', departmentId)
          .order('name');
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMunicipalities(String provinceId) async {
    try {
      return await supabase
          .from('municipalities')
          .select('id, province_id, name')
          .eq('province_id', provinceId)
          .order('name');
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchCities(String municipalityId) async {
    try {
      return await supabase
          .from('cities')
          .select('id, municipality_id, name')
          .eq('municipality_id', municipalityId)
          .order('name');
    } catch (e) {
      return [];
    }
  }

  /// Returns {departmentId, provinceId, municipalityId} for a given cityId.
  Future<Map<String, String>?> resolveCityChain(String cityId) async {
    try {
      final city = await supabase
          .from('cities')
          .select('municipality_id')
          .eq('id', cityId)
          .maybeSingle();
      if (city == null) return null;

      final muni = await supabase
          .from('municipalities')
          .select('province_id')
          .eq('id', city['municipality_id'] as String)
          .maybeSingle();
      if (muni == null) return null;

      final prov = await supabase
          .from('provinces')
          .select('department_id')
          .eq('id', muni['province_id'] as String)
          .maybeSingle();
      if (prov == null) return null;

      return {
        'departmentId': prov['department_id'] as String,
        'provinceId': muni['province_id'] as String,
        'municipalityId': city['municipality_id'] as String,
      };
    } catch (e) {
      return null;
    }
  }
}
