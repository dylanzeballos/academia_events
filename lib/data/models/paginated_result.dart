class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
  });

  final List<T> items;
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  factory PaginatedResult.empty({int pageSize = 12}) {
    return PaginatedResult<T>(
      items: [],
      currentPage: 1,
      pageSize: pageSize,
      totalItems: 0,
      totalPages: 0,
      hasNextPage: false,
      hasPreviousPage: false,
    );
  }

  factory PaginatedResult.fromResponse({
    required List<T> items,
    required int page,
    required int pageSize,
    required int totalItems,
  }) {
    final totalPages = (totalItems / pageSize).ceil();
    return PaginatedResult<T>(
      items: items,
      currentPage: page,
      pageSize: pageSize,
      totalItems: totalItems,
      totalPages: totalPages,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1,
    );
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  bool get isFirstPage => currentPage == 1;
  bool get isLastPage => currentPage == totalPages;
}