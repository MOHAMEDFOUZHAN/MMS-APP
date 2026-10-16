import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/text_standardizer.dart';
import '../models/batch_model.dart';
import '../models/chocolate_ocr_ledger_model.dart';
import '../models/dispatch_model.dart';
import '../models/invoice_model.dart';
import '../models/owner_dashboard_model.dart';
import '../models/owner_reporting_models.dart';
import '../models/tea_consumption_model.dart';
import '../models/tea_material_received_model.dart';
import '../models/transfer_model.dart';

class OwnerRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// Authoritative server-side role verification for Owner privileges
  Future<Map<String, dynamic>> verifyOwnerAccess() async {
    try {
      final res = await _client.rpc('verify_owner_access');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'authorized': true};
    } catch (e) {
      debugPrint('Owner access verification failed: $e');
      throw AppException.from(e);
    }
  }

  /// Authoritative master summary aggregation for the Owner Executive Portal
  Future<OwnerDashboardSummary> fetchOwnerDashboardSummary({
    DateTime? fromDate,
    DateTime? toDate,
    int invoiceExpiryDays = 30,
    int storageExpiryDays = 30,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_invoice_expiry_days': invoiceExpiryDays,
        'p_storage_expiry_days': storageExpiryDays,
      };

      if (fromDate != null) {
        params['p_from_date'] = fromDate.toIso8601String().split('T')[0];
      }
      if (toDate != null) {
        params['p_to_date'] = toDate.toIso8601String().split('T')[0];
      }

      final res = await _client.rpc('get_owner_dashboard_summary', params: params);
      if (res is Map) {
        return OwnerDashboardSummary.fromJson(Map<String, dynamic>.from(res));
      }
      throw AppException('Invalid server response format for owner dashboard');
    } catch (e) {
      debugPrint('Error loading owner dashboard summary: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch full audit log trail for the Owner Activity & Audit section
  Future<List<OwnerActivityItem>> fetchAuditLogs({int limit = 100}) async {
    try {
      final res = await _client
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (res as List<dynamic>).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final dt = DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now();
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final minuteStr = dt.minute.toString().padLeft(2, '0');
        map['time_ampm'] = '$hour:$minuteStr $ampm';
        map['date_str'] = dt.toIso8601String().split('T')[0];
        return OwnerActivityItem.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
      throw AppException.from(e);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. ADMIN SECTION REPORTING APIS
  // ════════════════════════════════════════════════════════════════════════════

  /// Fetch Admin Live Stock with department breakdown and last transaction
  Future<List<OwnerAdminLiveStockItem>> fetchAdminLiveStock({String? search}) async {
    try {
      final params = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        params['p_search'] = search.trim();
      }

      final res = await _client.rpc('get_owner_admin_live_stock', params: params);
      return (res as List<dynamic>)
          .map((row) => OwnerAdminLiveStockItem.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching admin live stock: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch Invoices with items (defaults to today or selected date)
  Future<List<InvoiceModel>> fetchInvoicesReport({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int limit = 100,
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

      final res = await query
          .order('date', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return (res as List<dynamic>)
          .map((json) => InvoiceModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching owner invoices report: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch Transfers report (Admin to Tea / Chocolate)
  Future<List<TransferModel>> fetchTransfersReport({
    String? department,
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int limit = 150,
  }) async {
    try {
      var query = _client.from('transfers').select();

      if (department != null && department.trim().isNotEmpty && department.toUpperCase() != 'ALL') {
        query = query.ilike('department', department.trim());
      }

      if (fromDate != null) {
        query = query.gte('date', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        query = query.lte('date', toDate.toIso8601String().split('T')[0]);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = TextStandardizer.collapseSpaces(search);
        query = query.or('code.ilike.%$term%,description.ilike.%$term%,person.ilike.%$term%');
      }

      final res = await query
          .order('date', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return (res as List<dynamic>)
          .map((json) => TransferModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching owner transfers report: $e');
      throw AppException.from(e);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. TEA SECTION REPORTING APIS
  // ════════════════════════════════════════════════════════════════════════════

  /// Fetch Tea Live Materials (strictly materials transferred to Tea)
  Future<List<TeaMaterialReceivedModel>> fetchTeaLiveMaterials({
    String? search,
    String? category,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        params['p_search'] = search.trim();
      }
      if (category != null && category.trim().isNotEmpty && category.toUpperCase() != 'ALL') {
        params['p_category'] = category.trim();
      }

      final res = await _client.rpc('get_tea_material_received_ledger', params: params);
      return (res as List<dynamic>)
          .map((row) => TeaMaterialReceivedModel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching tea live materials: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch Tea Consumption report
  Future<List<TeaConsumptionModel>> fetchTeaConsumptionReport({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int limit = 150,
  }) async {
    try {
      var query = _client.from('tea_consumption_ledger').select();

      if (fromDate != null) {
        query = query.gte('date', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        query = query.lte('date', toDate.toIso8601String().split('T')[0]);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = TextStandardizer.collapseSpaces(search);
        query = query.or('material_code.ilike.%$term%,description.ilike.%$term%,operator_name.ilike.%$term%');
      }

      final res = await query
          .order('date', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return (res as List<dynamic>)
          .map((json) => TeaConsumptionModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching tea consumption report: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch Tea Storage Live Stock (batches where category='TEA' or department='Tea')
  Future<List<BatchModel>> fetchTeaStorageReport({
    String? search,
    int limit = 150,
  }) async {
    try {
      var query = _client
          .from('batches')
          .select()
          .or('category.ilike.TEA,department.ilike.TEA');

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or('batch_no.ilike.%$term%,material_code.ilike.%$term%,description.ilike.%$term%');
      }

      final res = await query
          .order('batch_date', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return (res as List<dynamic>)
          .map((json) => BatchModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching tea storage report: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch Tea Dispatch report
  Future<List<DispatchModel>> fetchTeaDispatchesReport({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int limit = 100,
  }) async {
    try {
      var query = _client
          .from('dispatches')
          .select('*, dispatch_batches(*)')
          .or('category.ilike.TEA,department.ilike.TEA');

      if (fromDate != null) {
        query = query.gte('date', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        query = query.lte('date', toDate.toIso8601String().split('T')[0]);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = TextStandardizer.collapseSpaces(search);
        query = query.or('product.ilike.%$term%,material_code.ilike.%$term%,location.ilike.%$term%');
      }

      final res = await query
          .order('date', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return (res as List<dynamic>)
          .map((json) => DispatchModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching tea dispatches report: $e');
      throw AppException.from(e);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. CHOCOLATE SECTION REPORTING APIS
  // ════════════════════════════════════════════════════════════════════════════

  /// Fetch Chocolate Live Materials (strictly materials transferred to Chocolate)
  Future<List<OwnerChocolateLiveMaterialItem>> fetchChocolateLiveMaterials({
    String? search,
    String? category,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        params['p_search'] = search.trim();
      }
      if (category != null && category.trim().isNotEmpty && category.toUpperCase() != 'ALL') {
        params['p_category'] = category.trim();
      }

      final res = await _client.rpc('get_chocolate_material_received_ledger', params: params);
      return (res as List<dynamic>)
          .map((row) => OwnerChocolateLiveMaterialItem.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching chocolate live materials: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch Confirmed Chocolate OCR Records
  Future<List<ChocolateOcrLedgerModel>> fetchConfirmedChocolateOcr({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int limit = 150,
  }) async {
    try {
      var query = _client
          .from('chocolate_ocr_ledger')
          .select()
          .eq('status', 'CONFIRMED');

      if (fromDate != null) {
        query = query.gte('confirmed_at', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        final toNext = toDate.add(const Duration(days: 1)).toIso8601String().split('T')[0];
        query = query.lt('confirmed_at', toNext);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = TextStandardizer.collapseSpaces(search);
        query = query.or('description.ilike.%$term%,product_code.ilike.%$term%,document_name.ilike.%$term%');
      }

      final res = await query
          .order('confirmed_at', ascending: false)
          .limit(limit);

      return (res as List<dynamic>)
          .map((json) => ChocolateOcrLedgerModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching confirmed chocolate OCR report: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch Chocolate Rack Report (batches with rack_location or department/category Chocolate)
  Future<List<BatchModel>> fetchChocolateRackReport({
    String? search,
    int limit = 150,
  }) async {
    try {
      var query = _client
          .from('batches')
          .select()
          .or('rack_location.not.is.null,category.ilike.CHOCOLATE,department.ilike.CHOCOLATE');

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or('batch_no.ilike.%$term%,material_code.ilike.%$term%,description.ilike.%$term%,rack_location.ilike.%$term%');
      }

      final res = await query
          .order('batch_date', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return (res as List<dynamic>)
          .map((json) => BatchModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching chocolate rack report: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch Chocolate Consignment Report (dispatches for Chocolate department/category)
  Future<List<DispatchModel>> fetchChocolateConsignmentReport({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int limit = 100,
  }) async {
    try {
      var query = _client
          .from('dispatches')
          .select('*, dispatch_batches(*)')
          .or('category.ilike.CHOCOLATE,department.ilike.CHOCOLATE');

      if (fromDate != null) {
        query = query.gte('date', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        query = query.lte('date', toDate.toIso8601String().split('T')[0]);
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = TextStandardizer.collapseSpaces(search);
        query = query.or('product.ilike.%$term%,material_code.ilike.%$term%,location.ilike.%$term%');
      }

      final res = await query
          .order('date', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return (res as List<dynamic>)
          .map((json) => DispatchModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching chocolate consignment report: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch Out of Stock report distinguishing location stock from total business stock
  Future<List<OwnerOutOfStockItem>> fetchOutOfStockReport({
    String? department,
    String? search,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (department != null && department.trim().isNotEmpty && department.toUpperCase() != 'ALL') {
        params['p_department'] = department.trim().toUpperCase();
      } else {
        params['p_department'] = 'ALL';
      }

      if (search != null && search.trim().isNotEmpty) {
        params['p_search'] = search.trim();
      }

      final res = await _client.rpc('get_owner_out_of_stock_report', params: params);
      return (res as List<dynamic>)
          .map((row) => OwnerOutOfStockItem.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching out of stock report: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch Reorder report identifying items needing replenishment with suggested stock
  Future<List<OwnerReorderItem>> fetchReorderReport({
    String? department,
    String? search,
    String? status,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (department != null && department.trim().isNotEmpty && department.toUpperCase() != 'ALL') {
        params['p_department'] = department.trim().toUpperCase();
      } else {
        params['p_department'] = 'ALL';
      }

      if (search != null && search.trim().isNotEmpty) {
        params['p_search'] = search.trim();
      }

      if (status != null && status.trim().isNotEmpty && status.toUpperCase() != 'ALL') {
        params['p_status'] = status.trim().toUpperCase();
      } else {
        params['p_status'] = 'ALL';
      }

      final res = await _client.rpc('get_owner_reorder_report', params: params);
      return (res as List<dynamic>)
          .map((row) => OwnerReorderItem.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching reorder report: $e');
      throw AppException.from(e);
    }
  }

  /// Update reorder level for a material (strictly modifies threshold, never alters stock)
  Future<bool> updateMaterialReorderLevel(String materialCode, double newReorderLevel) async {
    final cleanCode = materialCode.trim();
    final validLevel = newReorderLevel < 0 ? 0.0 : newReorderLevel;
    try {
      final res = await _client.rpc('update_material_reorder_level', params: {
        'p_material_code': cleanCode,
        'p_reorder_level': validLevel,
      });
      return res == true;
    } catch (e) {
      debugPrint('update_material_reorder_level RPC fallback to direct update: $e');
      try {
        await _client.from('materials').update({
          'reorder_level': validLevel,
          'last_updated': DateTime.now().toIso8601String(),
        }).eq('material_code', cleanCode);
        return true;
      } catch (err) {
        debugPrint('Direct materials update failed: $err');
        throw AppException.from(err);
      }
    }
  }

  /// Fetch Expiry report for Management Login
  Future<List<OwnerExpiryListItem>> fetchExpiryReport({
    int? daysWindow,
    String? search,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (daysWindow != null && daysWindow > 0) {
        params['p_days_window'] = daysWindow;
      }
      if (search != null && search.trim().isNotEmpty) {
        params['p_search'] = search.trim();
      }

      final res = await _client.rpc('get_owner_expiry_report', params: params);
      return (res as List<dynamic>)
          .map((row) => OwnerExpiryListItem.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching owner expiry report: $e');
      throw AppException.from(e);
    }
  }
}
