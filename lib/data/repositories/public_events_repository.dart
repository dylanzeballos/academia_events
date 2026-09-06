import '../models/public_event_model.dart';
import '../models/public_event_data.dart';
import '../models/event_filter_state.dart';
import '../models/paginated_result.dart';
import '../models/geographic_model.dart';
import '../models/event_category_model.dart';
import '../models/dance_category_model.dart';
import '../services/public_events_service.dart';

abstract interface class IPublicEventsRepository {
  Future<PaginatedResult<PublicEventModel>> searchEvents(
    EventFilterState filter, {
    String? organizationId,
  });
  Future<PublicEventModel?> getEventById(String eventId);
  Future<List<OrganizationWithEventCount>> getOrganizationsWithEvents({int limit = 10});
  Future<List<EventCategoryModel>> getEventCategories();
  Future<List<DanceCategoryModel>> getDanceCategories();
  Future<List<DepartmentModel>> getDepartments();
  Future<List<ProvinceModel>> getProvinces(String departmentId);
  Future<List<MunicipalityModel>> getMunicipalities(String provinceId);
  Future<List<CityModel>> getCities(String municipalityId);
}

class PublicEventsRepository implements IPublicEventsRepository {
  const PublicEventsRepository({PublicEventsService? service}) : _service = service ?? const PublicEventsService();

  final PublicEventsService _service;

  @override
  Future<PaginatedResult<PublicEventModel>> searchEvents(
    EventFilterState filter, {
    String? organizationId,
  }) async {
    final result = await _service.searchEvents(
      searchQuery: filter.searchQuery.isEmpty ? null : filter.searchQuery,
      categoryIds: filter.categoryIds.isEmpty ? null : filter.categoryIds,
      danceCategoryIds: filter.danceCategoryIds.isEmpty ? null : filter.danceCategoryIds,
      organizationId: organizationId,
      departmentId: filter.departmentId,
      provinceId: filter.provinceId,
      municipalityId: filter.municipalityId,
      cityId: filter.cityId,
      dateFrom: filter.dateFrom,
      dateTo: filter.dateTo,
      priceMin: filter.priceMin,
      priceMax: filter.priceMax,
      sortBy: filter.sortBy,
      page: filter.page,
      pageSize: filter.pageSize,
    );

    final models = result.items.map((data) => PublicEventModel(
      id: data.id,
      title: data.title,
      organizationId: data.organizationId,
      organizationName: data.organizationName,
      organizationLogoUrl: data.organizationLogoUrl,
      categoryId: data.categoryId,
      categoryName: data.categoryName,
      description: data.description,
      coverImageUrl: data.coverImageUrl,
      location: data.location,
      startTime: data.startTime,
      endTime: data.endTime,
      timezone: data.timezone,
      capacity: data.capacity,
      status: data.status,
      visibility: data.visibility,
      requiresApproval: data.requiresApproval,
      publishedAt: data.publishedAt,
      createdAt: data.createdAt,
      colorIndex: data.colorIndex,
      minPrice: data.minPrice,
      currency: data.currency,
      danceCategories: data.danceCategories,
      images: data.images,
      ticketTypes: data.ticketTypes,
    )).toList();

    return PaginatedResult<PublicEventModel>(
      items: models,
      currentPage: result.currentPage,
      pageSize: result.pageSize,
      totalItems: result.totalItems,
      totalPages: result.totalPages,
      hasNextPage: result.hasNextPage,
      hasPreviousPage: result.hasPreviousPage,
    );
  }

  @override
  Future<PublicEventModel?> getEventById(String eventId) async {
    final data = await _service.getEventById(eventId);
    if (data == null) return null;

    return PublicEventModel(
      id: data.id,
      title: data.title,
      organizationId: data.organizationId,
      organizationName: data.organizationName,
      organizationLogoUrl: data.organizationLogoUrl,
      categoryId: data.categoryId,
      categoryName: data.categoryName,
      description: data.description,
      coverImageUrl: data.coverImageUrl,
      location: data.location,
      startTime: data.startTime,
      endTime: data.endTime,
      timezone: data.timezone,
      capacity: data.capacity,
      status: data.status,
      visibility: data.visibility,
      requiresApproval: data.requiresApproval,
      publishedAt: data.publishedAt,
      createdAt: data.createdAt,
      colorIndex: data.colorIndex,
      minPrice: data.minPrice,
      currency: data.currency,
      danceCategories: data.danceCategories,
      images: data.images,
      ticketTypes: data.ticketTypes,
    );
  }

  @override
  Future<List<OrganizationWithEventCount>> getOrganizationsWithEvents({int limit = 10}) async {
    return _service.getOrganizationsWithEvents(limit: limit);
  }

  @override
  Future<List<EventCategoryModel>> getEventCategories() async {
    return _service.getEventCategories();
  }

  @override
  Future<List<DanceCategoryModel>> getDanceCategories() async {
    return _service.getDanceCategories();
  }

  @override
  Future<List<DepartmentModel>> getDepartments() async {
    return _service.getDepartments();
  }

  @override
  Future<List<ProvinceModel>> getProvinces(String departmentId) async {
    return _service.getProvinces(departmentId);
  }

  @override
  Future<List<MunicipalityModel>> getMunicipalities(String provinceId) async {
    return _service.getMunicipalities(provinceId);
  }

  @override
  Future<List<CityModel>> getCities(String municipalityId) async {
    return _service.getCities(municipalityId);
  }
}