import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/text_standardizer.dart';
import '../models/material_model.dart';

class MaterialsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<MaterialModel>> fetchMaterials({
    String? search,
    String? category,
    String? status, // 'all', 'reorder', 'expiring', 'out_of_stock'
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      var query = _client.from('materials').select();

      if (category != null && category.isNotEmpty && category != 'All') {
        query = query.eq('category', category);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = TextStandardizer.collapseSpaces(search);
        query = query.or('material_code.ilike.%$term%,description.ilike.%$term%');
      }

      if (status == 'reorder') {
        query = query.filter('quantity', 'lte', 'reorder_level').gt('quantity', 0);
      } else if (status == 'out_of_stock') {
        query = query.filter('quantity', 'lte', 0);
      } else if (status == 'expiring') {
        final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0];
        query = query.not('expiry_date', 'is', null).lte('expiry_date', thirtyDaysFromNow);
      }

      final response = await query.order('material_code', ascending: true).range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((json) => MaterialModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<MaterialModel>> fetchMaterialLots(String materialCode) async {
    try {
      final response = await _client
          .from('materials')
          .select()
          .eq('material_code', materialCode)
          .order('id', ascending: true);

      return (response as List<dynamic>)
          .map((json) => MaterialModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Live search by material_code OR description — used in Invoice/Transfer/Dispatch dropdowns.
  Future<List<MaterialModel>> searchMaterials(String query, {int limit = 25}) async {
    try {
      if (query.trim().isEmpty) {
        final response = await _client
            .from('materials')
            .select()
            .order('material_code', ascending: true)
            .limit(limit);
        return (response as List<dynamic>)
            .map((json) => MaterialModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      final term = TextStandardizer.collapseSpaces(query);
      final response = await _client
          .from('materials')
          .select()
          .or('material_code.ilike.%$term%,description.ilike.%$term%')
          .order('material_code', ascending: true)
          .limit(limit);
      return (response as List<dynamic>)
          .map((json) => MaterialModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Fetch a single material master record by code — used for auto-fill on selection.
  Future<MaterialModel?> getMaterialByCode(String code) async {
    try {
      final response = await _client
          .from('materials')
          .select()
          .eq('material_code', code.trim())
          .limit(1);
      final list = response as List<dynamic>;
      if (list.isEmpty) return null;
      return MaterialModel.fromJson(list.first as Map<String, dynamic>);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<String>> fetchCategories() async {
    try {
      final response = await _client
          .from('materials')
          .select('category')
          .not('category', 'is', null);

      final set = <String>{};
      for (final row in response as List<dynamic>) {
        final cat = row['category']?.toString().trim();
        if (cat != null && cat.isNotEmpty) set.add(cat);
      }
      final list = set.toList()..sort();
      return list;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> registerNewMaterial({
    required String code,
    required String description,
    required String category,
    required String unit,
    required double reorderLevel,
    String? hsnSac,
    String? grade,
  }) async {
    try {
      final cleanCode = TextStandardizer.normalizeCode(code);
      final cleanDesc = TextStandardizer.normalizeBusinessText(description);
      final cleanCategory = TextStandardizer.normalizeBusinessText(category);
      final cleanUnit = TextStandardizer.normalizeBusinessText(unit);
      final cleanHsn = TextStandardizer.normalizeBusinessText(hsnSac);
      final cleanGrade = TextStandardizer.normalizeBusinessText(grade);

      // Check duplicate — DB UNIQUE constraint will also reject, but give friendly error first
      final existing = await _client
          .from('materials')
          .select('id')
          .eq('material_code', cleanCode)
          .limit(1);

      if ((existing as List).isNotEmpty) {
        throw AppException('Material code $cleanCode already exists in inventory.');
      }

      await _client.from('materials').insert({
        'material_code': cleanCode,
        'description': cleanDesc,
        'category': cleanCategory,
        'unit': cleanUnit,
        'reorder_level': reorderLevel,
        'quantity': 0.0,
        'opening_stock': 0.0,
        'unit_price': 0.0,
        'hsn_sac': cleanHsn,
        'grade': cleanGrade,
        'last_updated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<bool> updateMaterialUnit(String materialCode, String newUnit) async {
    try {
      final response = await _client.rpc('update_material_unit', params: {
        'p_code': TextStandardizer.normalizeCode(materialCode),
        'p_new_unit': TextStandardizer.normalizeBusinessText(newUnit),
      });
      return response == true;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updateReorderLevel(String materialCode, double newLevel) async {
    try {
      await _client.from('materials').update({
        'reorder_level': newLevel,
        'last_updated': DateTime.now().toIso8601String(),
      }).eq('material_code', materialCode);
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
