import '../../core/config/supabase_config.dart';
import '../models/public_event_data.dart';
import '../models/event_filter_state.dart';
import '../models/paginated_result.dart';
import '../models/geographic_model.dart';
import '../models/event_category_model.dart';
import '../models/dance_category_model.dart';

class PublicEventsService {
  const PublicEventsService();

  /// Resuelve el path de un logo almacenado a una URL pública permanente.
  /// Devuelve [path] tal cual si ya es una URL completa o si es nulo/vacío.
  static String? _publicLogoUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return supabase.storage
        .from('organization-logos')
        .getPublicUrl(path);
  }

  Future<PaginatedResult<PublicEventData>> searchEvents({
    String? searchQuery,
    List<String>? categoryIds,
    List<String>? danceCategoryIds,
    String? departmentId,
    String? provinceId,
    String? municipalityId,
    String? cityId,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? priceMin,
    double? priceMax,
    EventSortBy sortBy = EventSortBy.dateAsc,
    int page = 1,
    int pageSize = 12,
  }) async {
    // Build the base query for data
    dynamic query = supabase
        .from('events')
        .select('''
          id, title, organization_id, category_id,
          description, cover_image_url,
          start_at, end_at, timezone,
          capacity, status, visibility,
          requires_approval, published_at, created_at,
          organizations!inner(id, name, logo_url),
          event_categories(name),
          event_locations(*),
          event_images(image_url),
          event_dance_categories(dance_categories(id, name)),
          ticket_types(id, name, description, price, currency, quantity, sold_quantity, sales_start_at, sales_end_at, is_active)
        ''')
        .eq('status', 'published')
        .eq('visibility', 'public');

    query = _applyFilters(query, searchQuery, categoryIds, danceCategoryIds, departmentId, provinceId, municipalityId, cityId, dateFrom, dateTo, priceMin, priceMax);

    _applySorting(query, sortBy, searchQuery);

    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;
    query = query.range(from, to);

    // Get count separately using RPC or a simpler query
    int totalItems = 0;
    try {
      totalItems = await _getTotalCount(
        searchQuery, categoryIds, danceCategoryIds,
        departmentId, provinceId, municipalityId, cityId,
        dateFrom, dateTo, priceMin, priceMax,
      );
    } catch (_) {
      totalItems = 0;
    }

    final response = await query;
    final data = (response as List).cast<Map<String, dynamic>>();
    final items = data.map((row) => PublicEventData.fromJson(row)).toList();

    return PaginatedResult.fromResponse(
      items: items,
      page: page,
      pageSize: pageSize,
      totalItems: totalItems,
    );
  }

  dynamic _applyFilters(
    dynamic query,
    String? searchQuery,
    List<String>? categoryIds,
    List<String>? danceCategoryIds,
    String? departmentId,
    String? provinceId,
    String? municipalityId,
    String? cityId,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? priceMin,
    double? priceMax,
  ) {
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.or('title.ilike.%${searchQuery.trim()}%,description.ilike.%${searchQuery.trim()}%');
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      query = query.inFilter('category_id', categoryIds);
    }

    if (danceCategoryIds != null && danceCategoryIds.isNotEmpty) {
      query = query.filter('event_dance_categories.dance_category_id', 'in', danceCategoryIds);
    }

    if (cityId != null) {
      query = query.filter('event_locations.city_id', 'eq', cityId);
    } else if (municipalityId != null) {
      query = query.filter('event_locations.municipality_id', 'eq', municipalityId);
    } else if (provinceId != null) {
      query = query.filter('event_locations.province_id', 'eq', provinceId);
    } else if (departmentId != null) {
      query = query.filter('event_locations.department_id', 'eq', departmentId);
    }

    if (dateFrom != null) {
      query = query.gte('start_at', dateFrom.toIso8601String());
    }
    if (dateTo != null) {
      query = query.lte('start_at', dateTo.toIso8601String());
    }

    if (priceMin != null || priceMax != null) {
      if (priceMin != null) {
        query = query.filter('ticket_types.price', 'gte', priceMin.toString());
      }
      if (priceMax != null) {
        query = query.filter('ticket_types.price', 'lte', priceMax.toString());
      }
    }
    return query;
  }

  void _applySorting(dynamic query, EventSortBy sortBy, String? searchQuery) {
    switch (sortBy) {
      case EventSortBy.dateAsc:
        query = query.order('start_at', ascending: true);
        break;
      case EventSortBy.dateDesc:
        query = query.order('start_at', ascending: false);
        break;
      case EventSortBy.priceAsc:
        query = query.order('ticket_types.price', ascending: true);
        break;
      case EventSortBy.priceDesc:
        query = query.order('ticket_types.price', ascending: false);
        break;
      case EventSortBy.relevance:
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          query = query.textSearch('title', searchQuery.trim(), config: 'spanish');
        } else {
          query = query.order('start_at', ascending: true);
        }
        break;
    }
  }

  Future<int> _getTotalCount(
    String? searchQuery,
    List<String>? categoryIds,
    List<String>? danceCategoryIds,
    String? departmentId,
    String? provinceId,
    String? municipalityId,
    String? cityId,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? priceMin,
    double? priceMax,
  ) async {
    try {
      var query = supabase
          .from('events')
          .select('id')
          .eq('status', 'published')
          .eq('visibility', 'public');

      query = _applyFilters(query, searchQuery, categoryIds, danceCategoryIds, departmentId, provinceId, municipalityId, cityId, dateFrom, dateTo, priceMin, priceMax);

      final result = await query;
      return (result as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<PublicEventData?> getEventById(String eventId) async {
    final response = await supabase
        .from('events')
        .select('''
          id, title, organization_id, category_id,
          description, cover_image_url,
          start_at, end_at, timezone,
          capacity, status, visibility,
          requires_approval, published_at, created_at,
          organizations!inner(id, name, logo_url),
          event_categories(name),
          event_locations(*),
          event_images(image_url),
          event_dance_categories(dance_categories(id, name, is_active)),
          ticket_types(id, name, description, price, currency, quantity, sold_quantity, sales_start_at, sales_end_at, is_active)
        ''')
        .eq('id', eventId)
        .eq('status', 'published')
        .eq('visibility', 'public')
        .maybeSingle();

    if (response == null) return null;
    return PublicEventData.fromJson(response);
  }

  Future<List<OrganizationWithEventCount>> getOrganizationsWithEvents({int limit = 10}) async {
    final response = await supabase
        .from('organizations')
        .select('''
          id, name, logo_url, description, city_id,
          events!inner(id, status, visibility)
        ''')
        .eq('is_active', true)
        .eq('events.status', 'published')
        .eq('events.visibility', 'public')
        .limit(limit);

    final data = (response as List).cast<Map<String, dynamic>>();

    final orgMap = <String, OrganizationWithEventCount>{};
    for (final row in data) {
      final orgId = row['id'] as String;
      if (!orgMap.containsKey(orgId)) {
        orgMap[orgId] = OrganizationWithEventCount(
          id: orgId,
          name: row['name'] as String,
          logoUrl: _publicLogoUrl(row['logo_url'] as String?),
          description: row['description'] as String?,
          cityId: row['city_id'] as String?,
          eventCount: 0,
        );
      }
      orgMap[orgId] = orgMap[orgId]!.copyWith(eventCount: orgMap[orgId]!.eventCount + 1);
    }

    return orgMap.values.toList()
      ..sort((a, b) => b.eventCount.compareTo(a.eventCount));
  }

  Future<List<EventCategoryModel>> getEventCategories() async {
    final response = await supabase
        .from('event_categories')
        .select('id, name, is_active')
        .eq('is_active', true)
        .order('name');
    return (response as List).map((e) => EventCategoryModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DanceCategoryModel>> getDanceCategories() async {
    final response = await supabase
        .from('dance_categories')
        .select('id, name, is_active')
        .eq('is_active', true)
        .order('name');
    return (response as List).map((e) => DanceCategoryModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DepartmentModel>> getDepartments() async {
    final response = await supabase
        .from('departments')
        .select('id, name, code')
        .order('name');
    return (response as List).map((e) => DepartmentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ProvinceModel>> getProvinces(String departmentId) async {
    final response = await supabase
        .from('provinces')
        .select('id, department_id, name')
        .eq('department_id', departmentId)
        .order('name');
    return (response as List).map((e) => ProvinceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MunicipalityModel>> getMunicipalities(String provinceId) async {
    final response = await supabase
        .from('municipalities')
        .select('id, province_id, name')
        .eq('province_id', provinceId)
        .order('name');
    return (response as List).map((e) => MunicipalityModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CityModel>> getCities(String municipalityId) async {
    final response = await supabase
        .from('cities')
        .select('id, municipality_id, name')
        .eq('municipality_id', municipalityId)
        .order('name');
    return (response as List).map((e) => CityModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}