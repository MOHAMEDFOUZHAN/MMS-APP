import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../models/dashboard_summary_model.dart';

class DashboardRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<DashboardSummaryModel> fetchDashboardSummary() async {
    try {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      // 1. Total Materials
      final totalMaterialsRes = await _client.from('materials').select('id');
      final totalMaterials = (totalMaterialsRes as List).length;

      // 2. Reorder Items
      final allMaterials = await _client
          .from('materials')
          .select('material_code, description, category, quantity, reorder_level, expiry_date, unit');

      int reorderCount = 0;
      int expiringCount = 0;
      int outOfStockCount = 0;

      final categoryMap = <String, Map<String, dynamic>>{};
      final materialMap = <String, Map<String, dynamic>>{};

      for (final row in allMaterials as List<dynamic>) {
        final qty = (row['quantity'] as num?)?.toDouble() ?? 0.0;
        final reorder = (row['reorder_level'] as num?)?.toDouble() ?? 0.0;
        final expiry = row['expiry_date']?.toString();
        final cat = (row['category']?.toString().trim().isNotEmpty == true)
            ? row['category'].toString().trim()
            : 'General';
        final code = row['material_code']?.toString() ?? '';
        final desc = row['description']?.toString() ?? code;
        final unit = row['unit']?.toString() ?? 'kg';

        if (qty <= 0.0001) {
          outOfStockCount++;
        } else if (qty <= reorder) {
          reorderCount++;
        }

        if (expiry != null && expiry.isNotEmpty && expiry != '-') {
          try {
            final expDate = DateTime.parse(expiry.split(' ')[0]);
            final diff = expDate.difference(now).inDays;
            if (diff >= 0 && diff <= 30) {
              expiringCount++;
            }
          } catch (_) {}
        }

        // Category breakdown aggregation
        categoryMap.putIfAbsent(cat, () => {'total_quantity': 0.0, 'item_count': 0});
        categoryMap[cat]!['total_quantity'] = (categoryMap[cat]!['total_quantity'] as double) + qty;
        categoryMap[cat]!['item_count'] = (categoryMap[cat]!['item_count'] as int) + 1;

        // Top materials aggregation by code
        materialMap.putIfAbsent(code, () => {
          'material_code': code,
          'description': desc,
          'quantity': 0.0,
          'unit': unit,
        });
        materialMap[code]!['quantity'] = (materialMap[code]!['quantity'] as double) + qty;
      }

      // 3. Pending Invoices
      final pendingInvoicesRes = await _client
          .from('invoices')
          .select('id')
          .eq('payment_status', 'Pending');
      final pendingInvoices = (pendingInvoicesRes as List).length;

      // 4. Active Batches
      final activeBatchesRes = await _client
          .from('batches')
          .select('id')
          .gt('available_quantity', 0.001);
      final activeBatches = (activeBatchesRes as List).length;

      // 5. Today's Purchases
      final todayPurchasesRes = await _client
          .from('invoices')
          .select('final_total')
          .eq('date', todayStr);

      double todayPurchaseValue = 0.0;
      for (final inv in todayPurchasesRes as List<dynamic>) {
        todayPurchaseValue += (inv['final_total'] as num?)?.toDouble() ?? 0.0;
      }

      // 6. Today's Dispatches & Transfers
      final todayDispatchesRes = await _client
          .from('dispatches')
          .select('id')
          .eq('date', todayStr);
      final todayDispatches = (todayDispatchesRes as List).length;

      final todayTransfersRes = await _client
          .from('transfers')
          .select('id')
          .eq('date', todayStr);
      final todayTransfers = (todayTransfersRes as List).length;

      // Sort Category Breakdown
      final categoryList = categoryMap.entries.map((e) {
        return CategoryStock(
          category: e.key,
          totalQuantity: e.value['total_quantity'] as double,
          itemCount: e.value['item_count'] as int,
        );
      }).toList()..sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));

      // Sort Top Materials
      final topList = materialMap.values.map((v) {
        return TopMaterialItem(
          materialCode: v['material_code'] as String,
          description: v['description'] as String,
          quantity: v['quantity'] as double,
          unit: v['unit'] as String,
        );
      }).toList()..sort((a, b) => b.quantity.compareTo(a.quantity));

      return DashboardSummaryModel(
        totalMaterials: totalMaterials,
        reorderItems: reorderCount,
        expiringSoon: expiringCount,
        outOfStock: outOfStockCount,
        pendingInvoices: pendingInvoices,
        activeBatches: activeBatches,
        todayPurchaseValue: todayPurchaseValue,
        todayDispatches: todayDispatches,
        todayTransfers: todayTransfers,
        categoryBreakdown: categoryList,
        topMaterials: topList.take(5).toList(),
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
