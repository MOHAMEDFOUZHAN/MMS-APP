import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/text_standardizer.dart';
import '../models/category_location_model.dart';

class WarehouseRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<CategoryLocationModel>> fetchCategoryLocations() async {
    try {
      final response = await _client
          .from('category_locations')
          .select()
          .order('category', ascending: true);

      return (response as List<dynamic>)
          .map((json) => CategoryLocationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> saveCategoryLocation(String category, String location) async {
    try {
      await _client.from('category_locations').upsert({
        'category': TextStandardizer.normalizeBusinessText(category),
        'location': TextStandardizer.normalizeBusinessText(location),
        'last_updated': DateTime.now().toIso8601String(),
      }, onConflict: 'category');
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> deleteCategoryLocation(int id) async {
    try {
      await _client.from('category_locations').delete().eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
