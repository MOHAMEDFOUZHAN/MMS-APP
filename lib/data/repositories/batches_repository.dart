import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../models/batch_model.dart';

class BatchesRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<BatchModel>> fetchActiveBatches({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _client.from('batches').select().gt('available_quantity', 0.001);

      if (fromDate != null) {
        query = query.gte('received_date', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        query = query.lte('received_date', toDate.toIso8601String().split('T')[0]);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or('batch_no.ilike.%$term%,material_code.ilike.%$term%,description.ilike.%$term%');
      }

      final response = await query.order('id', ascending: false);

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
    int limit = 100,
  }) async {
    try {
      var query = _client.from('batches').select();

      if (fromDate != null) {
        query = query.gte('received_date', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        query = query.lte('received_date', toDate.toIso8601String().split('T')[0]);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or('batch_no.ilike.%$term%,material_code.ilike.%$term%,description.ilike.%$term%');
      }

      final response = await query.order('id', ascending: false).limit(limit);

      return (response as List<dynamic>)
          .map((json) => BatchModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> createBatch(BatchModel batch) async {
    try {
      await _client.from('batches').insert(batch.toJson());
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
