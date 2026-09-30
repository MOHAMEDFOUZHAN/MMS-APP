import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/connection_service.dart';
import '../../core/services/device_id_service.dart';
import '../../core/services/pending_operations_service.dart';
import '../../core/utils/text_standardizer.dart';
import '../models/dispatch_model.dart';

class DispatchesRepository {
  final Ref? _ref;

  DispatchesRepository([this._ref]);

  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<DispatchModel>> fetchDispatches({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client.from('dispatches').select('*, dispatch_batches(*)');

      if (fromDate != null) {
        query = query.gte('date', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        query = query.lte('date', toDate.toIso8601String().split('T')[0]);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = TextStandardizer.collapseSpaces(search);
        query = query.or('product.ilike.%$term%,material_code.ilike.%$term%,location.ilike.%$term%,department.ilike.%$term%');
      }

      final response = await query
          .order('date', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((json) => DispatchModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Map<String, dynamic>> createDispatchFifo({
    required String materialCode,
    required String product,
    required double quantity,
    required String units,
    required String location,
    required String department,
    required DateTime date,
    String? idempotencyKey,
  }) async {
    final deviceId = await DeviceIdService.getDeviceId();
    final idKey = idempotencyKey ??
        'IDEMP-$deviceId-DSP-${DateTime.now().millisecondsSinceEpoch}-${DeviceIdService.generateUuid().substring(0, 6)}';

    final payload = {
      'material_code': TextStandardizer.normalizeCode(materialCode),
      'product': TextStandardizer.normalizeBusinessText(product),
      'quantity': quantity,
      'units': TextStandardizer.normalizeBusinessText(units),
      'location': TextStandardizer.normalizeBusinessText(location),
      'department': TextStandardizer.normalizeBusinessText(department),
      'date': date.toIso8601String().split('T')[0],
      'idempotency_key': idKey,
      'device_id': deviceId,
    };

    // If offline, save to pending queue
    if (_ref != null && _ref.read(connectionServiceProvider).state == AppConnectionState.offline) {
      await _ref.read(pendingOperationsProvider.notifier).enqueue(
            operationType: 'dispatch_create',
            module: 'dispatches',
            payload: {'dispatch': payload},
            customIdempotencyKey: idKey,
          );
      return {
        'success': true,
        'is_pending': true,
        'idempotency_key': idKey,
        'message': 'No internet connection. Saved locally and will sync automatically.',
      };
    }

    try {
      final response = await _client.rpc('create_dispatch_fifo', params: {
        'p_dispatch': payload,
        'p_idempotency_key': idKey,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('createDispatchFifo error: $e');
      final errorStr = e.toString();
      final isNetwork = errorStr.contains('SocketException') ||
          errorStr.contains('ClientException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('connection abort');

      if (isNetwork && _ref != null) {
        await _ref.read(pendingOperationsProvider.notifier).enqueue(
              operationType: 'dispatch_create',
              module: 'dispatches',
              payload: {'dispatch': payload},
              customIdempotencyKey: idKey,
            );
        return {
          'success': true,
          'is_pending': true,
          'idempotency_key': idKey,
          'message': 'Network error. Operation queued and will sync automatically.',
        };
      }

      throw AppException.from(e);
    }
  }

  Future<Map<String, dynamic>> updateDispatch({
    required int dispatchId,
    required String materialCode,
    required String product,
    required double quantity,
    required String units,
    required String location,
    required String department,
    required DateTime date,
  }) async {
    try {
      final payload = {
        'material_code': TextStandardizer.normalizeCode(materialCode),
        'product': TextStandardizer.normalizeBusinessText(product),
        'quantity': quantity,
        'units': FactoryConstants.normalizeUomCode(units),
        'location': TextStandardizer.normalizeBusinessText(location),
        'department': TextStandardizer.normalizeBusinessText(department),
        'date': date.toIso8601String().split('T')[0],
      };

      final response = await _client.rpc('update_dispatch', params: {
        'p_dispatch_id': dispatchId,
        'p_dispatch': payload,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<bool> deleteDispatch(int dispatchId) async {
    try {
      final response = await _client.rpc('delete_dispatch', params: {
        'p_dispatch_id': dispatchId,
      });
      return response == true;
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
