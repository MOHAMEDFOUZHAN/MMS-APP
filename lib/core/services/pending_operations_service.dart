import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import 'connection_service.dart';
import 'device_id_service.dart';

class PendingOperation {
  final String localOperationId;
  final String operationType; // 'invoice_create', 'transfer_create', 'dispatch_create', 'stock_adjustment_create'
  final String module; // 'invoices', 'transfers', 'dispatches', 'stock_adjustments'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String? userId;
  final String deviceId;
  final int retryCount;
  final String status; // 'pending', 'syncing', 'synced', 'error'
  final String? lastError;
  final String idempotencyKey;

  PendingOperation({
    required this.localOperationId,
    required this.operationType,
    required this.module,
    required this.payload,
    required this.createdAt,
    this.userId,
    required this.deviceId,
    this.retryCount = 0,
    this.status = 'pending',
    this.lastError,
    required this.idempotencyKey,
  });

  PendingOperation copyWith({
    int? retryCount,
    String? status,
    String? lastError,
  }) {
    return PendingOperation(
      localOperationId: localOperationId,
      operationType: operationType,
      module: module,
      payload: payload,
      createdAt: createdAt,
      userId: userId,
      deviceId: deviceId,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
      idempotencyKey: idempotencyKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'local_operation_id': localOperationId,
        'operation_type': operationType,
        'module': module,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'user_id': userId,
        'device_id': deviceId,
        'retry_count': retryCount,
        'status': status,
        'last_error': lastError,
        'idempotency_key': idempotencyKey,
      };

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      localOperationId: json['local_operation_id']?.toString() ?? DeviceIdService.generateUuid(),
      operationType: json['operation_type']?.toString() ?? 'unknown',
      module: json['module']?.toString() ?? 'unknown',
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload'] as Map) : {},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      userId: json['user_id']?.toString(),
      deviceId: json['device_id']?.toString() ?? 'DEV-UNKNOWN',
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      lastError: json['last_error']?.toString(),
      idempotencyKey: json['idempotency_key']?.toString() ?? DeviceIdService.generateUuid(),
    );
  }
}

class PendingOperationsNotifier extends StateNotifier<List<PendingOperation>> {
  static const String _storageKey = 'mms_pending_operations_queue_v1';
  final Ref _ref;
  bool _isProcessing = false;

  PendingOperationsNotifier(this._ref) : super([]) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = (jsonDecode(jsonStr) as List)
            .map((e) => PendingOperation.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((op) => op.status != 'synced')
            .toList();
        state = list;
        _ref.read(connectionServiceProvider.notifier).updatePendingCount(state.length);
      }
    } catch (e) {
      debugPrint('Error loading pending operations: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
      _ref.read(connectionServiceProvider.notifier).updatePendingCount(state.length);
    } catch (e) {
      debugPrint('Error saving pending operations: $e');
    }
  }

  Future<PendingOperation> enqueue({
    required String operationType,
    required String module,
    required Map<String, dynamic> payload,
    String? customIdempotencyKey,
  }) async {
    final deviceId = await DeviceIdService.getDeviceId();
    final user = SupabaseConfig.isInitialized ? SupabaseConfig.client.auth.currentUser : null;
    final idKey = customIdempotencyKey ??
        'IDEMP-$deviceId-${operationType.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}-${DeviceIdService.generateUuid().substring(0, 6)}';

    final op = PendingOperation(
      localOperationId: DeviceIdService.generateUuid(),
      operationType: operationType,
      module: module,
      payload: payload,
      createdAt: DateTime.now(),
      userId: user?.id,
      deviceId: deviceId,
      retryCount: 0,
      status: 'pending',
      idempotencyKey: idKey,
    );

    state = [...state, op];
    await _saveToStorage();

    // Trigger auto-sync attempt
    processPendingQueue();
    return op;
  }

  Future<void> removeOperation(String localOperationId) async {
    state = state.where((op) => op.localOperationId != localOperationId).toList();
    await _saveToStorage();
  }

  Future<void> retryOperation(String localOperationId) async {
    state = state.map((op) {
      if (op.localOperationId == localOperationId) {
        return op.copyWith(status: 'pending', retryCount: 0, lastError: null);
      }
      return op;
    }).toList();
    await _saveToStorage();
    await processPendingQueue();
  }

  Future<void> retryAll() async {
    state = state.map((op) => op.copyWith(status: 'pending', retryCount: 0, lastError: null)).toList();
    await _saveToStorage();
    await processPendingQueue();
  }

  Future<void> processPendingQueue() async {
    if (_isProcessing || state.isEmpty) return;

    final conn = _ref.read(connectionServiceProvider);
    if (conn.state == AppConnectionState.offline) {
      return;
    }

    _isProcessing = true;
    _ref.read(connectionServiceProvider.notifier).setSyncing('SYNCING (${state.length} pending)...');

    final client = SupabaseConfig.client;

    for (int i = 0; i < state.length; i++) {
      var op = state[i];
      if (op.status == 'synced') continue;

      // Exponential backoff wait based on retry count
      // Attempt 1 -> 0s, Attempt 2 -> 2s, Attempt 3 -> 5s, Attempt 4 -> 10s, Attempt 5+ -> 30s
      if (op.retryCount > 0 && op.status == 'error') {
        final backoffSec = _getBackoffSeconds(op.retryCount);
        final elapsed = DateTime.now().difference(op.createdAt).inSeconds;
        if (elapsed < backoffSec) continue;
      }

      state = [
        for (int j = 0; j < state.length; j++)
          j == i ? state[j].copyWith(status: 'syncing') : state[j],
      ];

      try {
        dynamic result;

        switch (op.operationType) {
          case 'invoice_create':
            final invoice = Map<String, dynamic>.from(op.payload['invoice'] as Map);
            invoice['idempotency_key'] = op.idempotencyKey;
            invoice['device_id'] = op.deviceId;
            final items = (op.payload['items'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

            result = await client.rpc('create_purchase', params: {
              'p_invoice': invoice,
              'p_items': items,
              'p_idempotency_key': op.idempotencyKey,
            });
            break;

          case 'dispatch_create':
            final dispatch = Map<String, dynamic>.from(op.payload['dispatch'] as Map);
            dispatch['idempotency_key'] = op.idempotencyKey;
            dispatch['device_id'] = op.deviceId;

            result = await client.rpc('create_dispatch_fifo', params: {
              'p_dispatch': dispatch,
              'p_idempotency_key': op.idempotencyKey,
            });
            break;

          case 'transfer_create':
            final transfer = Map<String, dynamic>.from(op.payload['transfer'] as Map);
            transfer['idempotency_key'] = op.idempotencyKey;
            transfer['device_id'] = op.deviceId;

            result = await client.rpc('create_transfer', params: {
              'p_transfer': transfer,
              'p_idempotency_key': op.idempotencyKey,
            });
            break;

          case 'stock_adjustment_create':
            result = await client.rpc('create_stock_adjustment', params: {
              'p_code': op.payload['code'],
              'p_operation': op.payload['operation'],
              'p_amount': op.payload['amount'],
              'p_reason': op.payload['reason'],
              'p_user': op.payload['user'] ?? 'Supervisor',
              'p_idempotency_key': op.idempotencyKey,
            });
            break;

          default:
            throw Exception('Unknown operation type: ${op.operationType}');
        }

        debugPrint('Successfully synchronized operation: ${op.localOperationId} -> $result');

        // Mark synced and remove from pending queue
        state = state.where((item) => item.localOperationId != op.localOperationId).toList();
        await _saveToStorage();
        i--; // Adjust index
      } catch (e) {
        debugPrint('Sync failure for ${op.localOperationId}: $e');
        final newRetryCount = op.retryCount + 1;
        final errorMsg = e.toString();

        state = [
          for (int j = 0; j < state.length; j++)
            j == i
                ? state[j].copyWith(
                    status: newRetryCount >= 5 ? 'error' : 'pending',
                    retryCount: newRetryCount,
                    lastError: errorMsg,
                  )
                : state[j],
        ];
        await _saveToStorage();

        // If network error, stop queue processing
        if (errorMsg.contains('SocketException') ||
            errorMsg.contains('ClientException') ||
            errorMsg.contains('Failed host lookup') ||
            errorMsg.contains('connection abort')) {
          _ref.read(connectionServiceProvider.notifier).setOffline();
          break;
        }
      }
    }

    _isProcessing = false;

    if (state.isEmpty) {
      _ref.read(connectionServiceProvider.notifier).setOnline('SYNC COMPLETE');
    } else {
      final hasErrors = state.any((op) => op.status == 'error');
      if (hasErrors) {
        _ref.read(connectionServiceProvider.notifier).setSyncError('SYNC_ERROR — ${state.length} pending');
      } else {
        _ref.read(connectionServiceProvider.notifier).setOnline('ONLINE — ${state.length} pending');
      }
    }
  }

  int _getBackoffSeconds(int retryCount) {
    switch (retryCount) {
      case 1:
        return 0; // immediate
      case 2:
        return 2;
      case 3:
        return 5;
      case 4:
        return 10;
      default:
        return 30;
    }
  }
}

final pendingOperationsProvider =
    StateNotifierProvider<PendingOperationsNotifier, List<PendingOperation>>((ref) {
  return PendingOperationsNotifier(ref);
});
