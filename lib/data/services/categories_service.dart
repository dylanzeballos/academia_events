import 'package:flutter/foundation.dart';
import '../../core/config/supabase_config.dart';

class CategoriesService {
  const CategoriesService();

  Future<List<Map<String, dynamic>>> fetchEventCategories() async {
    try {
      final response = await supabase
          .from('event_categories')
          .select('id, name') 
          .eq('is_active', true)
          .order('name', ascending: true);

      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error en fetchEventCategories: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchDanceCategories() async {
    try {
      final response = await supabase
          .from('dance_categories')
          .select('id, name')
          .eq('is_active', true)
          .order('name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error en fetchDanceCategories: $e');
      return [];
    }
  }
}