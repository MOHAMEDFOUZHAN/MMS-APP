import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/connection_service.dart';
import '../../core/services/device_id_service.dart';
import '../../core/services/pending_operations_service.dart';
import '../../core/utils/text_standardizer.dart';
import '../models/invoice_model.dart';

class InvoicesRepository {
  final Ref? _ref;

  InvoicesRepository([this._ref]);

  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<InvoiceModel>> fetchInvoices({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client.from('invoices').select('*, invoice_items(*)');

      if (fromDate != null) {
        query = query.gte('date', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        query = query.lte('date', toDate.toIso8601String().split('T')[0]);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = TextStandardizer.collapseSpaces(search);
        query = query.or('invoice_no.ilike.%$term%,vendor.ilike.%$term%,purchase_id.ilike.%$term%');
      }

      final response = await query
          .order('date', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((json) => InvoiceModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<InvoiceModel> fetchInvoiceDetails(int invoiceId) async {
    try {
      final response = await _client
          .from('invoices')
          .select('*, invoice_items(*)')
          .eq('id', invoiceId)
          .single();

      return InvoiceModel.fromJson(response);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Map<String, dynamic>> createPurchaseInvoice({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
    String? idempotencyKey,
  }) async {
    final deviceId = await DeviceIdService.getDeviceId();
    final idKey = idempotencyKey ??
        'IDEMP-$deviceId-INV-${DateTime.now().millisecondsSinceEpoch}-${DeviceIdService.generateUuid().substring(0, 6)}';

    final cleanInvoice = Map<String, dynamic>.from(invoice);
    cleanInvoice['idempotency_key'] = idKey;
    cleanInvoice['device_id'] = deviceId;

    if (cleanInvoice['invoice_no'] != null) {
      cleanInvoice['invoice_no'] = TextStandardizer.normalizeBusinessText(cleanInvoice['invoice_no'].toString());
    }
    if (cleanInvoice['vendor'] != null) {
      cleanInvoice['vendor'] = TextStandardizer.normalizeBusinessText(cleanInvoice['vendor'].toString());
    }
    if (cleanInvoice['purchase_id'] != null) {
      cleanInvoice['purchase_id'] = TextStandardizer.normalizeBusinessText(cleanInvoice['purchase_id'].toString());
    }
    if (cleanInvoice['remarks'] != null) {
      cleanInvoice['remarks'] = TextStandardizer.normalizeBusinessText(cleanInvoice['remarks'].toString());
    }

    final cleanItems = items.map((item) {
      final m = Map<String, dynamic>.from(item);
      if (m['material'] != null) {
        m['material'] = TextStandardizer.normalizeCode(m['material'].toString());
      }
      if (m['description'] != null) {
        m['description'] = TextStandardizer.normalizeBusinessText(m['description'].toString());
      }
      if (m['category'] != null) {
        m['category'] = TextStandardizer.normalizeBusinessText(m['category'].toString());
      }
      if (m['unit'] != null) {
        m['unit'] = TextStandardizer.normalizeBusinessText(m['unit'].toString());
      }
      if (m['lot_no'] != null) {
        m['lot_no'] = TextStandardizer.normalizeBusinessText(m['lot_no'].toString());
      }
      if (m['grade'] != null) {
        m['grade'] = TextStandardizer.normalizeBusinessText(m['grade'].toString());
      }
      if (m['hsn_sac'] != null) {
        m['hsn_sac'] = TextStandardizer.normalizeBusinessText(m['hsn_sac'].toString());
      }
      return m;
    }).toList();

    // Check if offline explicitly
    if (_ref != null && _ref.read(connectionServiceProvider).state == AppConnectionState.offline) {
      await _ref.read(pendingOperationsProvider.notifier).enqueue(
            operationType: 'invoice_create',
            module: 'invoices',
            payload: {'invoice': cleanInvoice, 'items': cleanItems},
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
      final response = await _client.rpc('create_purchase', params: {
        'p_invoice': cleanInvoice,
        'p_items': cleanItems,
        'p_idempotency_key': idKey,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('createPurchaseInvoice network failure: $e');
      final errorStr = e.toString();
      final isNetwork = errorStr.contains('SocketException') ||
          errorStr.contains('ClientException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('connection abort');

      if (isNetwork && _ref != null) {
        await _ref.read(pendingOperationsProvider.notifier).enqueue(
              operationType: 'invoice_create',
              module: 'invoices',
              payload: {'invoice': cleanInvoice, 'items': cleanItems},
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

  Future<Map<String, dynamic>> updatePurchaseInvoice({
    required int invoiceId,
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final cleanInvoice = Map<String, dynamic>.from(invoice);
      if (cleanInvoice['vendor'] != null) {
        cleanInvoice['vendor'] = TextStandardizer.normalizeBusinessText(cleanInvoice['vendor'].toString());
      }
      if (cleanInvoice['purchase_id'] != null) {
        cleanInvoice['purchase_id'] = TextStandardizer.normalizeBusinessText(cleanInvoice['purchase_id'].toString());
      }
      if (cleanInvoice['remarks'] != null) {
        cleanInvoice['remarks'] = TextStandardizer.normalizeBusinessText(cleanInvoice['remarks'].toString());
      }

      final cleanItems = items.map((item) {
        final m = Map<String, dynamic>.from(item);
        if (m['material'] != null) {
          m['material'] = TextStandardizer.normalizeCode(m['material'].toString());
        }
        if (m['description'] != null) {
          m['description'] = TextStandardizer.normalizeBusinessText(m['description'].toString());
        }
        if (m['category'] != null) {
          m['category'] = TextStandardizer.normalizeBusinessText(m['category'].toString());
        }
        return m;
      }).toList();

      final response = await _client.rpc('update_purchase', params: {
        'p_invoice_id': invoiceId,
        'p_invoice': cleanInvoice,
        'p_items': cleanItems,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<bool> deleteInvoice(int invoiceId) async {
    try {
      final response = await _client.rpc('delete_purchase', params: {
        'p_invoice_id': invoiceId,
      });
      return response == true;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updatePaymentStatus(int invoiceId, String status) async {
    try {
      await _client.from('invoices').update({
        'payment_status': status,
      }).eq('id', invoiceId);
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
