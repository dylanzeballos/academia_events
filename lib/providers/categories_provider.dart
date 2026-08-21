import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/dance_category_model.dart';
import '../data/models/event_category_model.dart';
import '../data/repositories/categories_repository.dart';

final categoriesRepositoryProvider = Provider<ICategoriesRepository>((ref) {
  return const CategoriesRepository();
});

final eventCategoriesProvider =
    FutureProvider<List<EventCategoryModel>>((ref) async {
  final repo = ref.watch(categoriesRepositoryProvider);
  return repo.fetchEventCategories();
});

final danceCategoriesProvider =
    FutureProvider<List<DanceCategoryModel>>((ref) async {
  final repo = ref.watch(categoriesRepositoryProvider);
  return repo.fetchDanceCategories();
});