import 'package:equatable/equatable.dart';

enum EventSortBy {
  dateAsc,
  dateDesc,
  priceAsc,
  priceDesc,
  relevance,
}

class EventFilterState extends Equatable {
  const EventFilterState({
    this.searchQuery = '',
    this.categoryIds = const [],
    this.danceCategoryIds = const [],
    this.departmentId,
    this.provinceId,
    this.municipalityId,
    this.cityId,
    this.dateFrom,
    this.dateTo,
    this.priceMin,
    this.priceMax,
    this.sortBy = EventSortBy.dateAsc,
    this.page = 1,
    this.pageSize = 12,
  });

  final String searchQuery;
  final List<String> categoryIds;
  final List<String> danceCategoryIds;
  final String? departmentId;
  final String? provinceId;
  final String? municipalityId;
  final String? cityId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? priceMin;
  final double? priceMax;
  final EventSortBy sortBy;
  final int page;
  final int pageSize;

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      categoryIds.isNotEmpty ||
      danceCategoryIds.isNotEmpty ||
      departmentId != null ||
      provinceId != null ||
      municipalityId != null ||
      cityId != null ||
      dateFrom != null ||
      dateTo != null ||
      priceMin != null ||
      priceMax != null;

  EventFilterState copyWith({
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
    EventSortBy? sortBy,
    int? page,
    int? pageSize,
    bool clearLocation = false,
    bool clearDate = false,
    bool clearPrice = false,
  }) {
    return EventFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryIds: categoryIds ?? this.categoryIds,
      danceCategoryIds: danceCategoryIds ?? this.danceCategoryIds,
      departmentId: clearLocation ? null : (departmentId ?? this.departmentId),
      provinceId: clearLocation ? null : (provinceId ?? this.provinceId),
      municipalityId: clearLocation ? null : (municipalityId ?? this.municipalityId),
      cityId: clearLocation ? null : (cityId ?? this.cityId),
      dateFrom: clearDate ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDate ? null : (dateTo ?? this.dateTo),
      priceMin: clearPrice ? null : (priceMin ?? this.priceMin),
      priceMax: clearPrice ? null : (priceMax ?? this.priceMax),
      sortBy: sortBy ?? this.sortBy,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  EventFilterState reset() => const EventFilterState();

  EventFilterState nextPage() => copyWith(page: page + 1);

  EventFilterState previousPage() => copyWith(page: page > 1 ? page - 1 : 1);

  EventFilterState firstPage() => copyWith(page: 1);

  @override
  List<Object?> get props => [
        searchQuery,
        categoryIds,
        danceCategoryIds,
        departmentId,
        provinceId,
        municipalityId,
        cityId,
        dateFrom,
        dateTo,
        priceMin,
        priceMax,
        sortBy,
        page,
        pageSize,
      ];
}