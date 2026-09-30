import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../models/report_models.dart';

class ReportsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// 1. Material Directory / Wall Chart Report
  Future<List<MaterialDirectoryRow>> fetchMaterialDirectory() async {
    try {
      // Fetch locations
      final locRes = await _client.from('category_locations').select('category, location');
      final locMap = <String, String>{};
      for (final r in locRes as List<dynamic>) {
        locMap[r['category']?.toString() ?? ''] = r['location']?.toString() ?? '';
      }

      // Fetch materials
      final matRes = await _client.from('materials').select();
      final aggMap = <String, MaterialDirectoryRow>{};

      for (final r in matRes as List<dynamic>) {
        final code = r['material_code']?.toString() ?? '';
        final desc = r['description']?.toString() ?? '';
        final cat = r['category']?.toString() ?? 'General';
        final unit = r['unit']?.toString() ?? 'kg';
        final qty = (r['quantity'] as num?)?.toDouble() ?? 0.0;
        final reorder = (r['reorder_level'] as num?)?.toDouble() ?? 0.0;
        final shelf = locMap[cat] ?? 'Not Assigned';

        if (aggMap.containsKey(code)) {
          final existing = aggMap[code]!;
          aggMap[code] = MaterialDirectoryRow(
            materialCode: code,
            description: existing.description.isNotEmpty ? existing.description : desc,
            category: cat,
            unit: unit,
            currentStock: existing.currentStock + qty,
            reorderLevel: reorder > 0 ? reorder : existing.reorderLevel,
            shelfLocation: shelf,
          );
        } else {
          aggMap[code] = MaterialDirectoryRow(
            materialCode: code,
            description: desc,
            category: cat,
            unit: unit,
            currentStock: qty,
            reorderLevel: reorder,
            shelfLocation: shelf,
          );
        }
      }

      final list = aggMap.values.toList()
        ..sort((a, b) => a.materialCode.compareTo(b.materialCode));
      return list;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// 2. Daily Stock Ledger
  Future<List<DailyLedgerRow>> fetchDailyStockLedger(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];

      final materialsRes = await _client.from('materials').select();
      final purchasesRes = await _client
          .from('invoice_items')
          .select('material, quantity, invoices!inner(date)')
          .eq('invoices.date', dateStr);

      final transfersRes = await _client
          .from('transfers')
          .select('code, outward, return_units')
          .eq('date', dateStr);

      final dispatchesRes = await _client
          .from('dispatches')
          .select('material_code, quantity')
          .eq('date', dateStr);

      final purchaseMap = <String, double>{};
      for (final p in purchasesRes as List<dynamic>) {
        final code = p['material']?.toString() ?? '';
        final q = (p['quantity'] as num?)?.toDouble() ?? 0.0;
        purchaseMap[code] = (purchaseMap[code] ?? 0.0) + q;
      }

      final transferOutMap = <String, double>{};
      final returnInMap = <String, double>{};
      for (final t in transfersRes as List<dynamic>) {
        final code = t['code']?.toString() ?? '';
        final outQty = (t['outward'] as num?)?.toDouble() ?? 0.0;
        final retQty = (t['return_units'] as num?)?.toDouble() ?? 0.0;
        transferOutMap[code] = (transferOutMap[code] ?? 0.0) + outQty;
        returnInMap[code] = (returnInMap[code] ?? 0.0) + retQty;
      }

      final dispatchMap = <String, double>{};
      for (final d in dispatchesRes as List<dynamic>) {
        final code = d['material_code']?.toString() ?? '';
        final q = (d['quantity'] as num?)?.toDouble() ?? 0.0;
        dispatchMap[code] = (dispatchMap[code] ?? 0.0) + q;
      }

      // Group materials by code
      final rowsMap = <String, DailyLedgerRow>{};
      for (final m in materialsRes as List<dynamic>) {
        final code = m['material_code']?.toString() ?? '';
        final desc = m['description']?.toString() ?? '';
        final unit = m['unit']?.toString() ?? 'kg';
        final openStock = (m['opening_stock'] as num?)?.toDouble() ?? 0.0;
        final currQty = (m['quantity'] as num?)?.toDouble() ?? 0.0;

        if (rowsMap.containsKey(code)) {
          final existing = rowsMap[code]!;
          rowsMap[code] = DailyLedgerRow(
            materialCode: code,
            description: existing.description.isNotEmpty ? existing.description : desc,
            unit: unit,
            openingStock: existing.openingStock + openStock,
            purchased: existing.purchased,
            transferOut: existing.transferOut,
            returnIn: existing.returnIn,
            dispatched: existing.dispatched,
            closingStock: existing.closingStock + currQty,
          );
        } else {
          final pur = purchaseMap[code] ?? 0.0;
          final tOut = transferOutMap[code] ?? 0.0;
          final rIn = returnInMap[code] ?? 0.0;
          final disp = dispatchMap[code] ?? 0.0;

          rowsMap[code] = DailyLedgerRow(
            materialCode: code,
            description: desc,
            unit: unit,
            openingStock: openStock,
            purchased: pur,
            transferOut: tOut,
            returnIn: rIn,
            dispatched: disp,
            closingStock: currQty,
          );
        }
      }

      return rowsMap.values.toList()..sort((a, b) => a.materialCode.compareTo(b.materialCode));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// 3. Department Consumption Report
  Future<List<DepartmentConsumptionRow>> fetchDepartmentConsumption(
    DateTime fromDate,
    DateTime toDate, {
    String? department,
  }) async {
    try {
      var query = _client.from('transfers').select();

      query = query
          .gte('date', fromDate.toIso8601String().split('T')[0])
          .lte('date', toDate.toIso8601String().split('T')[0]);

      if (department != null && department.isNotEmpty && department != 'All') {
        query = query.eq('department', department);
      }

      final response = await query;
      final aggMap = <String, DepartmentConsumptionRow>{};

      for (final t in response as List<dynamic>) {
        final dept = t['department']?.toString().trim() ?? 'General';
        final code = t['code']?.toString() ?? '';
        final desc = t['description']?.toString() ?? code;
        final unit = t['units']?.toString() ?? 'kg';
        final outQty = (t['outward'] as num?)?.toDouble() ?? 0.0;
        final retQty = (t['return_units'] as num?)?.toDouble() ?? 0.0;
        final key = '$dept::$code';

        if (aggMap.containsKey(key)) {
          final existing = aggMap[key]!;
          final newOut = existing.totalOutward + outQty;
          final newRet = existing.totalReturn + retQty;
          aggMap[key] = DepartmentConsumptionRow(
            department: dept,
            materialCode: code,
            description: existing.description.isNotEmpty ? existing.description : desc,
            unit: unit,
            totalOutward: newOut,
            totalReturn: newRet,
            netConsumed: newOut - newRet,
          );
        } else {
          aggMap[key] = DepartmentConsumptionRow(
            department: dept,
            materialCode: code,
            description: desc,
            unit: unit,
            totalOutward: outQty,
            totalReturn: retQty,
            netConsumed: outQty - retQty,
          );
        }
      }

      return aggMap.values.toList()
        ..sort((a, b) => a.department.compareTo(b.department));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// 4. Material Utilization Report (MUR) with Historical Backtracking
  Future<List<MurReportRow>> fetchMurReport({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
  }) async {
    try {
      final response = await _client.rpc('get_mur_report', params: {
        'p_start_date': startDate.toIso8601String().split('T')[0],
        'p_end_date': endDate.toIso8601String().split('T')[0],
        'p_category': (category != null && category != 'All') ? category : null,
      });

      return (response as List<dynamic>)
          .map((json) => MurReportRow.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
