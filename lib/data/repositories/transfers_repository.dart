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
import '../models/transfer_model.dart';

class TransfersRepository {
  final Ref? _ref;

  TransfersRepository([this._ref]);

  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<TransferModel>> fetchTransfers({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client.from('transfers').select();

      if (fromDate != null) {
        query = query.gte('date', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        query = query.lte('date', toDate.toIso8601String().split('T')[0]);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = TextStandardizer.collapseSpaces(search);
        query = query.or('code.ilike.%$term%,description.ilike.%$term%,department.ilike.%$term%,person.ilike.%$term%');
      }

      final response = await query
          .order('date', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((json) => TransferModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Map<String, dynamic>> createTransfer({
    required String code,
    String? lotNo,
    required String department,
    required String person,
    required double outward,
    required double returnUnits,
    required String units,
    required DateTime date,
    String? idempotencyKey,
  }) async {
    final deviceId = await DeviceIdService.getDeviceId();
    final idKey = idempotencyKey ??
        'IDEMP-$deviceId-TRF-${DateTime.now().millisecondsSinceEpoch}-${DeviceIdService.generateUuid().substring(0, 6)}';

    final payload = {
      'code': TextStandardizer.normalizeCode(code),
      'lot_no': TextStandardizer.normalizeBusinessText(lotNo),
      'department': TextStandardizer.normalizeBusinessText(department),
      'person': TextStandardizer.normalizeBusinessText(person),
      'outward': outward,
      'return_units': returnUnits,
      'units': TextStandardizer.normalizeBusinessText(units),
      'date': date.toIso8601String().split('T')[0],
      'idempotency_key': idKey,
      'device_id': deviceId,
    };

    // If offline, save to pending queue
    if (_ref != null && _ref.read(connectionServiceProvider).state == AppConnectionState.offline) {
      await _ref.read(pendingOperationsProvider.notifier).enqueue(
            operationType: 'transfer_create',
            module: 'transfers',
            payload: {'transfer': payload},
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
      final response = await _client.rpc('create_transfer', params: {
        'p_transfer': payload,
        'p_idempotency_key': idKey,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('createTransfer error: $e');
      final errorStr = e.toString();
      final isNetwork = errorStr.contains('SocketException') ||
          errorStr.contains('ClientException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('connection abort');

      if (isNetwork && _ref != null) {
        await _ref.read(pendingOperationsProvider.notifier).enqueue(
              operationType: 'transfer_create',
              module: 'transfers',
              payload: {'transfer': payload},
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

  Future<Map<String, dynamic>> updateTransfer({
    required int transferId,
    required String code,
    String? lotNo,
    required String department,
    required String person,
    required double outward,
    required double returnUnits,
    required String units,
    required DateTime date,
  }) async {
    try {
      final payload = {
        'code': TextStandardizer.normalizeCode(code),
        'lot_no': TextStandardizer.normalizeBusinessText(lotNo),
        'department': TextStandardizer.normalizeBusinessText(department),
        'person': TextStandardizer.normalizeBusinessText(person),
        'outward': outward,
        'return_units': returnUnits,
        'units': FactoryConstants.normalizeUomCode(units),
        'date': date.toIso8601String().split('T')[0],
      };

      final response = await _client.rpc('update_transfer', params: {
        'p_transfer_id': transferId,
        'p_transfer': payload,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<bool> deleteTransfer(int transferId) async {
    try {
      final response = await _client.rpc('delete_transfer', params: {
        'p_transfer_id': transferId,
      });
      return response == true;
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
