import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/text_standardizer.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../models/tea_consumption_model.dart';
import '../models/tea_material_received_model.dart';

class TeaTransferredMaterial {
  final String code;
  final String description;
  final String units;
  final double netTransferred;
  final double totalConsumed;
  final double currentBalance;

  TeaTransferredMaterial({
    required this.code,
    required this.description,
    required this.units,
    required this.netTransferred,
    this.totalConsumed = 0.0,
    required this.currentBalance,
  });
}

class TeaDepartmentSummary {
  final double totalTransferredIn;
  final double totalTaken;
  final double totalBalanceReturned;
  final double totalNetConsumed;
  final double currentTeaStock;
  final int entryCount;
  final double totalReturnedToAdmin;

  TeaDepartmentSummary({
    required this.totalTransferredIn,
    required this.totalTaken,
    required this.totalBalanceReturned,
    required this.totalNetConsumed,
    required this.currentTeaStock,
    required this.entryCount,
    this.totalReturnedToAdmin = 0.0,
  });
}

class TeaConsumptionRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// Fetch only materials that have been transferred to the Tea department
  Future<List<TeaTransferredMaterial>> fetchTransferredMaterials({
    bool onlyWithPositiveBalance = false,
  }) async {
    try {
      // 1. Fetch transfers strictly assigned to Tea department
      final transfersRes = await _client
          .from('transfers')
          .select('code, description, units, outward, return_units, department, category')
          .ilike('department', 'TEA');

      final Map<String, Map<String, dynamic>> materialMap = {};

      for (final row in (transfersRes as List<dynamic>)) {
        final dept = (row['department'] ?? '').toString().trim().toUpperCase();

        // Must strictly be transferred to Tea
        if (dept == 'TEA') {
          final code = (row['code'] ?? '').toString().trim();
          if (code.isEmpty) continue;

          final desc = (row['description'] ?? '').toString().trim();
          final units = (row['units'] ?? 'kg').toString().trim();
          final outward = (row['outward'] as num?)?.toDouble() ?? 0.0;
          final returnUnits = (row['return_units'] as num?)?.toDouble() ?? 0.0;

          if (!materialMap.containsKey(code)) {
            materialMap[code] = {
              'code': code,
              'description': desc.isNotEmpty ? desc : code,
              'units': units,
              'total_received': 0.0,
              'total_returned': 0.0,
            };
          }
          materialMap[code]!['total_received'] =
              (materialMap[code]!['total_received'] as double) + outward;
          materialMap[code]!['total_returned'] =
              (materialMap[code]!['total_returned'] as double) + returnUnits;
        }
      }

      // 2. Fetch total consumed for each material from ledger
      final consumptionRes = await _client
          .from('tea_consumption_ledger')
          .select('material_code, consumed_qty');

      final Map<String, double> consumedMap = {};
      for (final row in (consumptionRes as List<dynamic>)) {
        final code = (row['material_code'] ?? '').toString().trim();
        final consumed = (row['consumed_qty'] as num?)?.toDouble() ?? 0.0;
        consumedMap[code] = (consumedMap[code] ?? 0.0) + consumed;
      }

      final List<TeaTransferredMaterial> results = [];
      for (final entry in materialMap.values) {
        final code = entry['code'] as String;
        final totalReceived = entry['total_received'] as double;
        final totalReturned = entry['total_returned'] as double;
        final consumed = consumedMap[code] ?? 0.0;

        // Skip any material that never had a valid outward transfer to Tea
        if (totalReceived <= 0.0001) continue;

        // Available Balance = Valid Received - Consumed - Returned to Admin
        final netTransferred = totalReceived - totalReturned;
        final balance = (totalReceived - consumed - totalReturned).clamp(0.0, double.infinity);

        // Filter out zero balance if requested (for consume dropdown)
        if (onlyWithPositiveBalance && balance <= 0.0001) {
          continue;
        }

        results.add(
          TeaTransferredMaterial(
            code: code,
            description: entry['description'] as String,
            units: entry['units'] as String,
            netTransferred: netTransferred,
            totalConsumed: consumed,
            currentBalance: balance,
          ),
        );
      }

      results.sort((a, b) => a.description.toLowerCase().compareTo(b.description.toLowerCase()));
      return results;
    } catch (e) {
      debugPrint('Error fetching tea transferred materials: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch consumption ledger entries with optional date & search filters
  Future<List<TeaConsumptionModel>> fetchConsumptionEntries({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
  }) async {
    try {
      var query = _client.from('tea_consumption_ledger').select('*');

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

      final response = await query
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .order('id', ascending: false);

      return (response as List<dynamic>)
          .map((json) => TeaConsumptionModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching tea consumption entries: $e');
      throw AppException.from(e);
    }
  }

  /// Create a new material consumption record with authoritative backend validation
  Future<TeaConsumptionModel> createEntry(TeaConsumptionModel entry) async {
    try {
      final json = entry.toJson(includeId: false);
      final response = await _client.rpc('record_tea_consumption', params: {
        'p_entry': json,
      });

      return TeaConsumptionModel.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('Error creating tea consumption entry: $e');
      throw AppException.from(e);
    }
  }

  /// Update an existing record with authoritative backend balance validation
  Future<TeaConsumptionModel> updateEntry(TeaConsumptionModel entry) async {
    try {
      final json = entry.toJson(includeId: false);
      final response = await _client.rpc('update_tea_consumption', params: {
        'p_id': entry.id,
        'p_entry': json,
      });

      return TeaConsumptionModel.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('Error updating tea consumption entry: $e');
      throw AppException.from(e);
    }
  }

  /// Delete an entry
  Future<void> deleteEntry(int id) async {
    try {
      await _client.from('tea_consumption_ledger').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting tea consumption entry: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch full statistical summary for Tea department
  Future<TeaDepartmentSummary> fetchTeaDepartmentSummary() async {
    try {
      // Transferred in to Tea
      final transfers = await _client
          .from('transfers')
          .select('outward, return_units, department, category')
          .ilike('department', 'TEA');

      double totalTransferred = 0.0;
      double totalReturned = 0.0;
      for (final row in (transfers as List<dynamic>)) {
        final dept = (row['department'] ?? '').toString().trim().toUpperCase();
        if (dept == 'TEA') {
          final outward = (row['outward'] as num?)?.toDouble() ?? 0.0;
          final returns = (row['return_units'] as num?)?.toDouble() ?? 0.0;
          totalTransferred += outward;
          totalReturned += returns;
        }
      }

      // Consumption ledger
      final ledger = await _client.from('tea_consumption_ledger').select('*');

      double totalTaken = 0.0;
      double totalBalance = 0.0;
      double totalConsumed = 0.0;

      for (final row in (ledger as List<dynamic>)) {
        totalTaken += (row['taken_qty'] as num?)?.toDouble() ?? 0.0;
        totalBalance += (row['balance_qty'] as num?)?.toDouble() ?? 0.0;
        totalConsumed += (row['consumed_qty'] as num?)?.toDouble() ?? 0.0;
      }

      final currentStock = (totalTransferred - totalReturned - totalConsumed).clamp(0.0, double.infinity);

      return TeaDepartmentSummary(
        totalTransferredIn: totalTransferred,
        totalTaken: totalTaken,
        totalBalanceReturned: totalBalance,
        totalNetConsumed: totalConsumed,
        currentTeaStock: currentStock,
        entryCount: (ledger as List<dynamic>).length,
        totalReturnedToAdmin: totalReturned,
      );
    } catch (e) {
      debugPrint('Error fetching tea summary: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch live stock ledger for Tea Material Received page
  Future<List<TeaMaterialReceivedModel>> fetchTeaMaterialReceivedStock({
    String? search,
    String? category,
    bool onlyWithBalance = false,
  }) async {
    try {
      // 1. Fetch transfers for Tea department
      final transfersRes = await _client
          .from('transfers')
          .select('code, description, units, outward, return_units, department, category, created_at, date')
          .ilike('department', 'TEA')
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> materialMap = {};

      for (final row in (transfersRes as List<dynamic>)) {
        final dept = (row['department'] ?? '').toString().toUpperCase();

        if (dept == 'TEA') {
          final code = (row['code'] ?? '').toString().trim();
          if (code.isEmpty) continue;

          final desc = (row['description'] ?? '').toString().trim();
          final units = (row['units'] ?? 'kg').toString().trim();
          final itemCat = (row['category'] ?? 'TEA').toString().trim();
          final outward = (row['outward'] as num?)?.toDouble() ?? 0.0;
          final returnUnits = (row['return_units'] as num?)?.toDouble() ?? 0.0;
          final createdAt = row['created_at'] != null
              ? DateTime.tryParse(row['created_at'].toString())?.toLocal()
              : (row['date'] != null ? DateTime.tryParse(row['date'].toString())?.toLocal() : null);

          if (!materialMap.containsKey(code)) {
            materialMap[code] = {
              'code': code,
              'description': desc.isNotEmpty ? desc : code,
              'category': itemCat.isNotEmpty ? itemCat : 'TEA',
              'units': units,
              'total_received': 0.0,
              'total_returned': 0.0,
              'latest_tx': createdAt,
            };
          }
          materialMap[code]!['total_received'] =
              (materialMap[code]!['total_received'] as double) + outward;
          materialMap[code]!['total_returned'] =
              (materialMap[code]!['total_returned'] as double) + returnUnits;

          final curLatest = materialMap[code]!['latest_tx'] as DateTime?;
          if (createdAt != null && (curLatest == null || createdAt.isAfter(curLatest))) {
            materialMap[code]!['latest_tx'] = createdAt;
          }
        }
      }

      // 2. Fetch consumption ledger records for Tea
      final consumptionRes = await _client
          .from('tea_consumption_ledger')
          .select('material_code, consumed_qty, created_at, date')
          .order('created_at', ascending: false);

      final Map<String, double> consumedMap = {};
      final Map<String, DateTime> latestConsumptionMap = {};

      for (final row in (consumptionRes as List<dynamic>)) {
        final code = (row['material_code'] ?? '').toString().trim();
        if (code.isEmpty) continue;
        final consumed = (row['consumed_qty'] as num?)?.toDouble() ?? 0.0;
        consumedMap[code] = (consumedMap[code] ?? 0.0) + consumed;

        final createdAt = row['created_at'] != null
            ? DateTime.tryParse(row['created_at'].toString())?.toLocal()
            : (row['date'] != null ? DateTime.tryParse(row['date'].toString())?.toLocal() : null);
        if (createdAt != null) {
          final curLatest = latestConsumptionMap[code];
          if (curLatest == null || createdAt.isAfter(curLatest)) {
            latestConsumptionMap[code] = createdAt;
          }
        }
      }

      final List<TeaMaterialReceivedModel> list = [];
      for (final entry in materialMap.values) {
        final code = entry['code'] as String;
        final desc = entry['description'] as String;
        final cat = entry['category'] as String;
        final units = entry['units'] as String;
        final totalReceived = entry['total_received'] as double;
        final totalReturned = entry['total_returned'] as double;
        final totalConsumed = consumedMap[code] ?? 0.0;

        // Materials with no actual inward transfer to Tea must never appear
        if (totalReceived <= 0.0001) continue;

        final currentBalance = (totalReceived - totalConsumed - totalReturned).clamp(0.0, double.infinity);

        DateTime? latestTx = entry['latest_tx'] as DateTime?;
        final latestCons = latestConsumptionMap[code];
        if (latestCons != null && (latestTx == null || latestCons.isAfter(latestTx))) {
          latestTx = latestCons;
        }

        final stockStatus = currentBalance <= 0.0001
            ? 'ZERO_BALANCE'
            : (currentBalance <= 5.0 ? 'LOW_STOCK' : 'IN_STOCK');

        // Apply filters
        if (onlyWithBalance && currentBalance <= 0.0001) {
          continue;
        }

        if (category != null && category.isNotEmpty && category != 'All' && cat.toUpperCase() != category.toUpperCase()) {
          continue;
        }

        if (search != null && search.trim().isNotEmpty) {
          final term = search.trim().toLowerCase();
          final matchesCode = code.toLowerCase().contains(term);
          final matchesDesc = desc.toLowerCase().contains(term);
          if (!matchesCode && !matchesDesc) {
            continue;
          }
        }

        list.add(
          TeaMaterialReceivedModel(
            materialCode: code,
            description: desc,
            category: cat,
            unit: units,
            totalReceived: totalReceived,
            totalConsumed: totalConsumed,
            totalReturned: totalReturned,
            currentBalance: currentBalance,
            latestTransactionAt: latestTx,
            stockStatus: stockStatus,
          ),
        );
      }

      list.sort((a, b) => a.description.toLowerCase().compareTo(b.description.toLowerCase()));
      return list;
    } catch (e) {
      debugPrint('Error fetching tea material received stock: $e');
      throw AppException.from(e);
    }
  }

  /// Record an authorized physical return from Tea back to Admin Store
  Future<Map<String, dynamic>> recordReturnToAdmin({
    required String materialCode,
    required String description,
    required double returnQty,
    required String units,
    String? person,
    String? notes,
  }) async {
    if (returnQty <= 0) {
      throw AppException('Return quantity must be greater than zero.');
    }

    try {
      // 1. Verify that Tea currently holds enough available balance
      final currentList = await fetchTeaMaterialReceivedStock();
      final item = currentList.firstWhere(
        (m) => m.materialCode == materialCode,
        orElse: () => throw AppException('Material $materialCode is not registered in Tea inventory.'),
      );

      if (returnQty > (item.currentBalance + 0.0001)) {
        throw AppException(
          'Cannot return ${QuantityFormatter.formatClean(returnQty)} $units. Current Tea available balance is only ${QuantityFormatter.formatClean(item.currentBalance)} $units.',
        );
      }

      final idKey = 'ret_tea_${materialCode}_${DateTime.now().millisecondsSinceEpoch}';
      final effectiveDate = DateTime.now();

      final payload = {
        'code': TextStandardizer.normalizeCode(materialCode),
        'description': TextStandardizer.normalizeBusinessText(description),
        'department': 'TEA',
        'person': TextStandardizer.normalizeBusinessText(person ?? 'Tea Supervisor'),
        'outward': 0.0,
        'return_units': returnQty,
        'units': FactoryConstants.normalizeUomCode(units),
        'date': effectiveDate.toIso8601String().split('T')[0],
        'idempotency_key': idKey,
      };

      final response = await _client.rpc('create_transfer', params: {
        'p_transfer': payload,
        'p_idempotency_key': idKey,
      });

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('Error recording return to Admin: $e');
      throw AppException.from(e);
    }
  }
}
