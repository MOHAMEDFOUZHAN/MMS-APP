import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../models/batch_model.dart';

enum BatchViewMode {
  inStock,
  allHistory,
  depleted,
}

class BatchesRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// Server-side generation of day-of-year batch number (e.g. '001', '044', '274', '365', '366')
  Future<String> generateBatchNumber(DateTime date) async {
    try {
      final res = await _client.rpc('generate_storage_batch_number', params: {
        'p_date': date.toIso8601String().split('T')[0],
      });
      if (res != null && res.toString().isNotEmpty) {
        return res.toString();
      }
    } catch (_) {
      // Fallback in case of network issue
    }
    final cleanDate = DateTime(date.year, date.month, date.day);
    final startOfYear = DateTime(date.year, 1, 1);
    final doy = cleanDate.difference(startOfYear).inDays + 1;
    return doy.toString().padLeft(3, '0');
  }

  Future<List<BatchModel>> fetchBatches({
    BatchViewMode viewMode = BatchViewMode.inStock,
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? category,
    int limit = 200,
  }) async {
    try {
      var query = _client.from('batches').select();

      if (category != null && category.trim().isNotEmpty) {
        query = query.eq('category', category.trim().toUpperCase());
      }

      switch (viewMode) {
        case BatchViewMode.inStock:
          query = query.gt('available_quantity', 0.0001);
          break;
        case BatchViewMode.depleted:
          query = query.lte('available_quantity', 0.0001);
          break;
        case BatchViewMode.allHistory:
          // No quantity filter - show active, partial, and depleted
          break;
      }

      if (fromDate != null) {
        final fStr = fromDate.toIso8601String().split('T')[0];
        query = query.or('batch_date.gte.$fStr,received_date.gte.$fStr');
      }
      if (toDate != null) {
        final tStr = toDate.toIso8601String().split('T')[0];
        query = query.or('batch_date.lte.$tStr,received_date.lte.$tStr');
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or(
          'batch_no.ilike.%$term%,'
          'material_code.ilike.%$term%,'
          'description.ilike.%$term%,'
          'category.ilike.%$term%,'
          'grade.ilike.%$term%,'
          'department.ilike.%$term%',
        );
      }

      final response = await query
          .order('batch_date', ascending: false)
          .order('received_at', ascending: false)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((json) => BatchModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<BatchModel>> fetchActiveBatches({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? category,
  }) {
    return fetchBatches(
      viewMode: BatchViewMode.inStock,
      search: search,
      fromDate: fromDate,
      toDate: toDate,
      category: category,
    );
  }

  /// Fetches all active batches with available stock for a specific material in strict FIFO order
  /// Excludes expired batches per factory inventory rules
  Future<List<BatchModel>> getActiveBatchesForMaterial(
    String materialCode, {
    int? materialId,
    String? description,
  }) async {
    try {
      final code = materialCode.trim();
      var query = _client
          .from('batches')
          .select()
          .gt('available_quantity', 0.0001);

      if (materialId != null && materialId > 0) {
        query = query.or('material_id.eq.$materialId,product_id.eq.$materialId,material_code.eq.$code');
      } else if (description != null && description.trim().isNotEmpty) {
        final desc = description.trim();
        query = query.or('material_code.eq.$code,description.ilike.$desc');
      } else {
        query = query.eq('material_code', code);
      }

      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      // Exclude expired batches (expiry_date < today)
      query = query.or('expiry_date.is.null,expiry_date.gte.$todayStr');

      final response = await query
          .order('expiry_date', ascending: true, nullsFirst: false)
          .order('received_at', ascending: true)
          .order('created_at', ascending: true)
          .order('id', ascending: true);

      return (response as List<dynamic>)
          .map((json) => BatchModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<BatchModel>> fetchInwardHistory({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? category,
    int limit = 100,
  }) {
    return fetchBatches(
      viewMode: BatchViewMode.allHistory,
      search: search,
      fromDate: fromDate,
      toDate: toDate,
      category: category,
      limit: limit,
    );
  }

  Future<void> createBatch(BatchModel batch) async {
    try {
      var batchNo = batch.batchNo.trim();
      if (batchNo.isEmpty) {
        batchNo = await generateBatchNumber(batch.effectiveDate);
      }

      // Upsert product identity in storage_products table
      if (batch.materialCode.trim().isNotEmpty) {
        try {
          await _client.rpc('upsert_storage_product', params: {
            'p_product_code': batch.materialCode.trim(),
            'p_product_name': batch.description.trim().isNotEmpty ? batch.description.trim() : batch.materialCode.trim(),
            'p_uom': batch.uom,
            'p_grade': batch.grade,
            'p_category': batch.category,
          });
        } catch (e) {
          debugPrint('Error registering storage product identity: $e');
        }
      }

      final recAt = batch.receivedAt ?? DateTime.now();
      final payload = batch.copyWith(
        batchNo: batchNo,
        receivedAt: recAt,
      ).toJson();
      await _client.from('batches').insert(payload);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updateBatch(BatchModel batch) async {
    await updateBatchStock(
      batchId: batch.id,
      batchNo: batch.batchNo,
      description: batch.description,
      department: batch.department,
      uom: batch.uom,
      newAvailable: batch.availableQuantity,
      newReceived: batch.receivedQuantity,
    );
  }

  Future<void> updateBatchStock({
    required int batchId,
    required String batchNo,
    required String description,
    required String department,
    required String uom,
    required double newAvailable,
    required double newReceived,
  }) async {
    try {
      await _client.rpc('update_batch_stock', params: {
        'p_batch_id': batchId,
        'p_batch_no': batchNo,
        'p_description': description,
        'p_department': department,
        'p_uom': uom,
        'p_new_available': newAvailable,
        'p_new_received': newReceived,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> deleteBatch(int id) async {
    await safeDeleteBatch(id);
  }

  Future<void> safeDeleteBatch(int batchId) async {
    try {
      final res = await _client.rpc('safe_delete_batch', params: {
        'p_batch_id': batchId,
      });
      if (res is Map && res['success'] == false) {
        throw AppException(res['message']?.toString() ?? 'Failed to delete batch.');
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
