import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/text_standardizer.dart';
import '../models/storage_product_model.dart';

class StorageProductsRepository {
  StorageProductsRepository();

  SupabaseClient get _client => SupabaseConfig.client;

  /// Fetch all reusable Storage product identities (filtered optionally by code or name search)
  Future<List<StorageProductModel>> searchStorageProducts(String? query, {String? category}) async {
    try {
      final res = await _client.rpc('get_storage_products', params: {
        'p_search': query != null && query.trim().isNotEmpty ? query.trim() : null,
        'p_category': category != null && category.trim().isNotEmpty ? category.trim().toUpperCase() : null,
      });

      return (res as List<dynamic>)
          .map((json) => StorageProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('searchStorageProducts RPC error, falling back to direct table query: $e');
      try {
        var q = _client.from('storage_products').select();
        if (category != null && category.trim().isNotEmpty) {
          q = q.eq('category', category.trim().toUpperCase());
        }
        if (query != null && query.trim().isNotEmpty) {
          final term = query.trim();
          q = q.or('product_code.ilike.%$term%,product_name.ilike.%$term%');
        }
        final res = await q.order('product_name', ascending: true);
        return (res as List<dynamic>)
            .map((json) => StorageProductModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e2) {
        throw AppException.from(e2);
      }
    }
  }

  /// Upserts a finished product into Storage product identities (case-insensitive, trimmed, no duplicates)
  Future<StorageProductModel> upsertProduct({
    required String productCode,
    required String productName,
    String uom = 'kg',
    String grade = 'STANDARD',
    String category = 'Finished Goods',
  }) async {
    try {
      final res = await _client.rpc('upsert_storage_product', params: {
        'p_product_code': TextStandardizer.normalizeCode(productCode),
        'p_product_name': TextStandardizer.normalizeBusinessText(productName),
        'p_uom': TextStandardizer.normalizeBusinessText(uom),
        'p_grade': grade.isNotEmpty ? grade : 'STANDARD',
        'p_category': category.isNotEmpty ? category : 'Finished Goods',
      });

      return StorageProductModel.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      debugPrint('upsertProduct error: $e');
      throw AppException.from(e);
    }
  }

  /// Critical Business Rule: Dispatch must only show products currently present in Storage with available stock > 0
  Future<List<DispatchAvailableProductModel>> getDispatchAvailableProducts({String? search, String? category}) async {
    try {
      final res = await _client.rpc('get_dispatch_available_products', params: {
        'p_search': search != null && search.trim().isNotEmpty ? search.trim() : null,
        'p_category': category != null && category.trim().isNotEmpty ? category.trim().toUpperCase() : null,
      });

      return (res as List<dynamic>)
          .map((json) => DispatchAvailableProductModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getDispatchAvailableProducts error: $e');
      throw AppException.from(e);
    }
  }
}
