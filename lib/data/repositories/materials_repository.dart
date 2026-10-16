import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/utils/text_standardizer.dart';
import '../models/material_lot_model.dart';
import '../models/material_model.dart';

class MaterialsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<MaterialModel>> fetchLiveMaterialsSummary({
    String? search,
    String? category,
    String? grade,
    String? status, // 'all', 'reorder', 'expiring', 'out_of_stock'
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 1000,
    int offset = 0,
    int? expiryDays,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_search': (search != null && search.trim().isNotEmpty) ? search.trim() : null,
        'p_category': (category != null && category.isNotEmpty && category != 'All') ? category : null,
        'p_grade': (grade != null && grade.isNotEmpty && grade != 'All') ? grade : null,
        'p_status': status ?? 'all',
        'p_from_date': fromDate != null ? QuantityFormatter.toIsoDate(fromDate) : null,
        'p_to_date': toDate != null ? QuantityFormatter.toIsoDate(toDate) : null,
        'p_limit': limit,
        'p_offset': offset,
        if (expiryDays != null) 'p_expiry_days': expiryDays,
      };

      final response = await _client.rpc('get_live_materials_summary', params: params);

      return (response as List<dynamic>)
          .map((json) => MaterialModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<MaterialModel>> fetchMaterials({
    String? search,
    String? category,
    String? status, // 'all', 'reorder', 'expiring', 'out_of_stock'
    int limit = 1000,
    int offset = 0,
    int invoiceMaterialExpiryAlertDays = 30,
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
        try {
          return await fetchLiveMaterialsSummary(
            search: search,
            category: category,
            status: 'reorder',
            limit: limit,
            offset: offset,
            expiryDays: invoiceMaterialExpiryAlertDays,
          );
        } catch (_) {
          var query = _client.from('materials').select();
          if (category != null && category.isNotEmpty && category != 'All') {
            query = query.eq('category', category);
          }
          if (search != null && search.trim().isNotEmpty) {
            final term = TextStandardizer.collapseSpaces(search);
            query = query.or('material_code.ilike.%$term%,description.ilike.%$term%');
          }
          final res = await query.gt('quantity', 0).order('material_code', ascending: true);
          final all = (res as List<dynamic>)
              .map((json) => MaterialModel.fromJson(json as Map<String, dynamic>))
              .where((m) => m.reorderLevel > 0 && m.quantity <= m.reorderLevel && m.quantity > 0)
              .toList();
          return all.skip(offset).take(limit).toList();
        }
      } else if (status == 'out_of_stock') {
        try {
          return await fetchLiveMaterialsSummary(
            search: search,
            category: category,
            status: 'out_of_stock',
            limit: limit,
            offset: offset,
          );
        } catch (_) {
          var query = _client.from('materials').select();
          if (category != null && category.isNotEmpty && category != 'All') {
            query = query.eq('category', category);
          }
          if (search != null && search.trim().isNotEmpty) {
            final term = TextStandardizer.collapseSpaces(search);
            query = query.or('material_code.ilike.%$term%,description.ilike.%$term%');
          }
          final res = await query.filter('quantity', 'lte', 0).order('material_code', ascending: true).range(offset, offset + limit - 1);
          return (res as List<dynamic>)
              .map((json) => MaterialModel.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      } else if (status == 'expiring') {
        try {
          return await fetchLiveMaterialsSummary(
            search: search,
            category: category,
            status: 'expiring',
            limit: limit,
            offset: offset,
            expiryDays: invoiceMaterialExpiryAlertDays,
          );
        } catch (_) {
          final alertDaysFromNow = DateTime.now().add(Duration(days: invoiceMaterialExpiryAlertDays)).toIso8601String().split('T')[0];
          final todayStr = DateTime.now().toIso8601String().split('T')[0];
          query = query
              .not('expiry_date', 'is', null)
              .gte('expiry_date', todayStr)
              .lte('expiry_date', alertDaysFromNow);
        }
      }

      final response = await query.order('material_code', ascending: true).range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((json) => MaterialModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<MaterialLotModel>> fetchMaterialLots(String materialCode) async {
    try {
      final response = await _client
          .from('material_lots')
          .select()
          .eq('material_code', materialCode)
          .order('lot_date', ascending: false);

      return (response as List<dynamic>)
          .map((json) => MaterialLotModel.fromJson(json as Map<String, dynamic>))
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
      final clean = code.trim();
      if (clean.isEmpty) return null;
      final response = await _client
          .from('materials')
          .select()
          .ilike('material_code', clean)
          .limit(1);
      final list = response as List<dynamic>;
      if (list.isEmpty) return null;
      return MaterialModel.fromJson(list.first as Map<String, dynamic>);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Fetch a single material master record by exact description (case-insensitive).
  Future<MaterialModel?> getMaterialByExactDescription(String description) async {
    try {
      final clean = description.trim();
      if (clean.isEmpty) return null;
      final response = await _client
          .from('materials')
          .select()
          .ilike('description', clean)
          .limit(2);
      final list = response as List<dynamic>;
      if (list.length == 1) {
        return MaterialModel.fromJson(list.first as Map<String, dynamic>);
      }
      return null;
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

  Future<List<String>> fetchGrades() async {
    try {
      final response = await _client
          .from('materials')
          .select('grade')
          .not('grade', 'is', null);

      final set = <String>{};
      for (final row in response as List<dynamic>) {
        final g = row['grade']?.toString().trim();
        if (g != null && g.isNotEmpty) set.add(g);
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
    final cleanCode = TextStandardizer.normalizeCode(materialCode);
    final cleanUnit = TextStandardizer.normalizeBusinessText(newUnit);
    try {
      final response = await _client.rpc('update_material_unit', params: {
        'p_code': cleanCode,
        'p_new_unit': cleanUnit,
      });
      return response == true;
    } catch (_) {
      try {
        await _client.from('materials').update({
          'unit': cleanUnit,
          'last_updated': DateTime.now().toIso8601String(),
        }).eq('material_code', cleanCode);
        return true;
      } catch (e) {
        throw AppException.from(e);
      }
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

  Future<bool> updateMaterialCategory(String materialCode, String newCategory) async {
    final cleanCode = TextStandardizer.normalizeCode(materialCode);
    final cleanCat = TextStandardizer.normalizeBusinessText(newCategory);
    try {
      final response = await _client.rpc('update_material_category', params: {
        'p_code': cleanCode,
        'p_new_cat': cleanCat,
      });
      return response == true;
    } catch (_) {
      try {
        await _client.from('materials').update({
          'category': cleanCat,
          'last_updated': DateTime.now().toIso8601String(),
        }).eq('material_code', cleanCode);
        return true;
      } catch (e) {
        throw AppException.from(e);
      }
    }
  }
}
