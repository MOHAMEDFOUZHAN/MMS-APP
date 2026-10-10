import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';

/// Authorized Read-Only Inventory Tools for MIRA
/// Strictly read-only queries with zero SQL execution permissions.
class MiraInventoryTools {
  static SupabaseClient get _client => SupabaseConfig.client;

  /// 1. Get stock information for a specific material by code or name
  static Future<Map<String, dynamic>?> getMaterialStock(String query) async {
    try {
      final clean = query.trim().toLowerCase();
      final res = await _client
          .from('materials')
          .select('id, material_code, description, category, quantity, unit, unit_price, reorder_level, expiry_date')
          .or('material_code.ilike.%$clean%,description.ilike.%$clean%')
          .limit(1)
          .maybeSingle();

      if (res == null) return null;

      final materialId = res['id']?.toString() ?? '';
      int lotCount = 0;
      String oldestLot = 'None';

      if (materialId.isNotEmpty) {
        final lotsRes = await _client
            .from('batches')
            .select('lot_no, batch_no, quantity, created_at')
            .eq('material_id', materialId)
            .gt('quantity', 0)
            .order('created_at', ascending: true);

        final lotsList = lotsRes as List;
        lotCount = lotsList.length;
        if (lotsList.isNotEmpty) {
          oldestLot = lotsList.first['lot_no']?.toString() ?? lotsList.first['batch_no']?.toString() ?? 'BATCH-01';
        }
      }

      return {
        'material_code': res['material_code'],
        'description': res['description'],
        'category': res['category'] ?? 'General',
        'quantity': (res['quantity'] as num?)?.toDouble() ?? 0.0,
        'unit': res['unit'] ?? 'kg',
        'unit_price': (res['unit_price'] as num?)?.toDouble() ?? 0.0,
        'reorder_level': (res['reorder_level'] as num?)?.toDouble() ?? 0.0,
        'lots_count': lotCount,
        'oldest_lot': oldestLot,
      };
    } catch (_) {
      return null;
    }
  }

  /// 2. Get materials currently out of stock
  static Future<List<Map<String, dynamic>>> getOutOfStockMaterials() async {
    try {
      final res = await _client
          .from('materials')
          .select('material_code, description, category, unit')
          .lte('quantity', 0.0001)
          .limit(10);

      return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 3. Get materials requiring reorder
  static Future<List<Map<String, dynamic>>> getReorderMaterials() async {
    try {
      final res = await _client
          .from('materials')
          .select('material_code, description, quantity, reorder_level, unit')
          .gt('reorder_level', 0)
          .limit(20);

      final list = <Map<String, dynamic>>[];
      for (final row in res as List) {
        final qty = (row['quantity'] as num?)?.toDouble() ?? 0.0;
        final reorder = (row['reorder_level'] as num?)?.toDouble() ?? 0.0;
        if (qty > 0 && qty <= reorder) {
          list.add(Map<String, dynamic>.from(row));
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// 4. Get materials expiring soon (within next N days)
  static Future<List<Map<String, dynamic>>> getExpiringMaterials({int days = 30}) async {
    try {
      final now = DateTime.now();
      final threshold = now.add(Duration(days: days));

      final res = await _client
          .from('materials')
          .select('material_code, description, quantity, unit, expiry_date')
          .not('expiry_date', 'is', null)
          .limit(50);

      final expiring = <Map<String, dynamic>>[];
      for (final row in res as List) {
        final expStr = row['expiry_date']?.toString();
        if (expStr != null && expStr.isNotEmpty && expStr != '-') {
          final dt = DateTime.tryParse(expStr.split(' ')[0]);
          if (dt != null && dt.isAfter(now.subtract(const Duration(days: 1))) && dt.isBefore(threshold)) {
            final daysLeft = dt.difference(now).inDays;
            expiring.add({
              ...Map<String, dynamic>.from(row),
              'days_left': daysLeft < 0 ? 0 : daysLeft,
            });
          }
        }
      }
      return expiring;
    } catch (_) {
      return [];
    }
  }

  /// 5. Get today's invoices
  static Future<List<Map<String, dynamic>>> getTodayInvoices() async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final res = await _client
          .from('invoices')
          .select('invoice_no, vendor_name, total_amount, invoice_date')
          .gte('created_at', '${todayStr}T00:00:00')
          .limit(10);

      return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 6. Get overall inventory summary and total valuation
  static Future<Map<String, dynamic>> getInventorySummary() async {
    try {
      final allMaterials = await _client
          .from('materials')
          .select('quantity, unit_price, reorder_level');

      double totalValuation = 0.0;
      int totalItems = 0;
      int lowStockCount = 0;
      int outOfStockCount = 0;

      for (final row in allMaterials as List) {
        final qty = (row['quantity'] as num?)?.toDouble() ?? 0.0;
        final price = (row['unit_price'] as num?)?.toDouble() ?? 0.0;
        final reorder = (row['reorder_level'] as num?)?.toDouble() ?? 0.0;

        totalItems++;
        if (qty > 0 && price > 0) {
          totalValuation += (qty * price);
        }
        if (qty <= 0.0001) {
          outOfStockCount++;
        } else if (qty <= reorder && reorder > 0) {
          lowStockCount++;
        }
      }

      return {
        'total_materials_count': totalItems,
        'total_inventory_valuation': totalValuation,
        'low_stock_count': lowStockCount,
        'out_of_stock_count': outOfStockCount,
      };
    } catch (_) {
      return {
        'total_materials_count': 0,
        'total_inventory_valuation': 0.0,
        'low_stock_count': 0,
        'out_of_stock_count': 0,
      };
    }
  }

  /// 7. Get today's dispatches
  static Future<List<Map<String, dynamic>>> getTodayDispatches() async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final res = await _client
          .from('dispatches')
          .select('id, dispatch_no, customer_name, total_qty, dispatch_date')
          .gte('created_at', '${todayStr}T00:00:00')
          .limit(10);

      return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
