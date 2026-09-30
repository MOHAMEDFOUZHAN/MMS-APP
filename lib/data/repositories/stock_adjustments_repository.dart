import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/connection_service.dart';
import '../../core/services/device_id_service.dart';
import '../../core/services/pending_operations_service.dart';
import '../../core/utils/text_standardizer.dart';
import '../models/stock_adjustment_model.dart';

class StockAdjustmentsRepository {
  final Ref? _ref;

  StockAdjustmentsRepository([this._ref]);

  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<StockAdjustmentModel>> fetchAdjustments({int limit = 50}) async {
    try {
      final response = await _client
          .from('stock_adjustments')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((json) => StockAdjustmentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Map<String, dynamic>> createAdjustment({
    required String materialCode,
    required String operation, // 'add' or 'subtract'
    required double amount,
    required String reason,
    String user = 'Supervisor',
    String? idempotencyKey,
  }) async {
    final deviceId = await DeviceIdService.getDeviceId();
    final idKey = idempotencyKey ??
        'IDEMP-$deviceId-ADJ-${DateTime.now().millisecondsSinceEpoch}-${DeviceIdService.generateUuid().substring(0, 6)}';

    final normalizedCode = TextStandardizer.normalizeCode(materialCode);
    final normalizedOp = operation.trim().toLowerCase();
    final normalizedReason = TextStandardizer.normalizeBusinessText(reason);
    final normalizedUser = TextStandardizer.normalizeBusinessText(user);

    // If offline, queue operation locally
    if (_ref != null && _ref.read(connectionServiceProvider).state == AppConnectionState.offline) {
      await _ref.read(pendingOperationsProvider.notifier).enqueue(
            operationType: 'stock_adjustment_create',
            module: 'stock_adjustments',
            payload: {
              'code': normalizedCode,
              'operation': normalizedOp,
              'amount': amount,
              'reason': normalizedReason,
              'user': normalizedUser,
            },
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
      final response = await _client.rpc('create_stock_adjustment', params: {
        'p_code': normalizedCode,
        'p_operation': normalizedOp,
        'p_amount': amount,
        'p_reason': normalizedReason,
        'p_user': normalizedUser,
        'p_idempotency_key': idKey,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('createAdjustment error: $e');
      final errorStr = e.toString();
      final isNetwork = errorStr.contains('SocketException') ||
          errorStr.contains('ClientException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('connection abort');

      if (isNetwork && _ref != null) {
        await _ref.read(pendingOperationsProvider.notifier).enqueue(
              operationType: 'stock_adjustment_create',
              module: 'stock_adjustments',
              payload: {
                'code': normalizedCode,
                'operation': normalizedOp,
                'amount': amount,
                'reason': normalizedReason,
                'user': normalizedUser,
              },
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
}
