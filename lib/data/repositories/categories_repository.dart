import '../models/dance_category_model.dart';
import '../models/event_category_model.dart';
import '../services/categories_service.dart';

abstract interface class ICategoriesRepository {
  Future<List<EventCategoryModel>> fetchEventCategories();
  Future<List<DanceCategoryModel>> fetchDanceCategories();
}

class CategoriesRepository implements ICategoriesRepository {
  const CategoriesRepository({CategoriesService? service})
      : _service = service ?? const CategoriesService();

  final CategoriesService _service;

  @override
  Future<List<EventCategoryModel>> fetchEventCategories() async {
    final rows = await _service.fetchEventCategories();
    return rows.map((row) => EventCategoryModel.fromJson(row)).toList();
  }

  @override
  Future<List<DanceCategoryModel>> fetchDanceCategories() async {
    final rows = await _service.fetchDanceCategories();
    return rows.map((row) => DanceCategoryModel.fromJson(row)).toList();
  }
}