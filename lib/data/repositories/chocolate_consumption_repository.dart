import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/text_standardizer.dart';
import '../models/chocolate_consumption_model.dart';
import '../../presentation/providers/app_providers.dart';

class ChocolateTransferredMaterial {
  final String code;
  final String description;
  final String units;
  final double netTransferred;
  final double totalConsumed;
  final double currentBalance;

  ChocolateTransferredMaterial({
    required this.code,
    required this.description,
    required this.units,
    required this.netTransferred,
    this.totalConsumed = 0.0,
    required this.currentBalance,
  });
}

class ChocolateDepartmentSummary {
  final double totalTransferredIn;
  final double totalTaken;
  final double totalBalanceReturned;
  final double totalNetConsumed;
  final double currentChocolateStock;
  final int entryCount;
  final double totalReturnedToAdmin;

  ChocolateDepartmentSummary({
    required this.totalTransferredIn,
    required this.totalTaken,
    required this.totalBalanceReturned,
    required this.totalNetConsumed,
    required this.currentChocolateStock,
    required this.entryCount,
    this.totalReturnedToAdmin = 0.0,
  });
}

class ChocolateConsumptionRepository {
  final Ref? _ref;

  ChocolateConsumptionRepository([this._ref]);

  SupabaseClient get _client => SupabaseConfig.client;

  /// Fetch only materials that have been transferred from Admin to the Chocolate department
  Future<List<ChocolateTransferredMaterial>> fetchTransferredMaterials({
    bool onlyWithPositiveBalance = false,
  }) async {
    try {
      // 1. Fetch transfers strictly assigned to Chocolate department
      final transfersRes = await _client
          .from('transfers')
          .select('code, description, units, outward, return_units, department, category')
          .ilike('department', 'CHOCOLATE');

      final Map<String, Map<String, dynamic>> materialMap = {};

      for (final row in (transfersRes as List<dynamic>)) {
        final dept = (row['department'] ?? '').toString().trim().toUpperCase();

        // Must strictly be transferred to Chocolate
        if (dept == 'CHOCOLATE') {
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

      // 2. Fetch total consumed for each material from chocolate ledger
      final consumptionRes = await _client
          .from('chocolate_consumption_ledger')
          .select('material_code, consumed_qty');

      final Map<String, double> consumedMap = {};
      for (final row in (consumptionRes as List<dynamic>)) {
        final code = (row['material_code'] ?? '').toString().trim();
        final consumed = (row['consumed_qty'] as num?)?.toDouble() ?? 0.0;
        consumedMap[code] = (consumedMap[code] ?? 0.0) + consumed;
      }

      final List<ChocolateTransferredMaterial> results = [];
      for (final entry in materialMap.values) {
        final code = entry['code'] as String;
        final totalReceived = entry['total_received'] as double;
        final totalReturned = entry['total_returned'] as double;
        final consumed = consumedMap[code] ?? 0.0;

        // Skip any material that never had a valid outward transfer to Chocolate
        if (totalReceived <= 0.0001) continue;

        // Available Balance = Valid Received - Consumed - Returned to Admin
        final netTransferred = totalReceived - totalReturned;
        final balance = (totalReceived - consumed - totalReturned).clamp(0.0, double.infinity);

        // Filter out zero balance if requested (for consume dropdown)
        if (onlyWithPositiveBalance && balance <= 0.0001) {
          continue;
        }

        results.add(
          ChocolateTransferredMaterial(
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
      debugPrint('Error fetching chocolate transferred materials: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch consumption ledger entries with optional date & search filters
  Future<List<ChocolateConsumptionModel>> fetchConsumptionEntries({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
  }) async {
    try {
      var query = _client.from('chocolate_consumption_ledger').select('*');

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
          .map((json) => ChocolateConsumptionModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching chocolate consumption entries: $e');
      throw AppException.from(e);
    }
  }

  /// Create a new material consumption record with authoritative backend validation
  Future<ChocolateConsumptionModel> createEntry(ChocolateConsumptionModel entry) async {
    if (_ref != null && _ref.read(isChocolateUserProvider)) {
      throw AppException('Access Denied: Chocolate users cannot record or modify consumption entries.');
    }

    try {
      final json = entry.toJson(includeId: false);
      final response = await _client.rpc('record_chocolate_consumption', params: {
        'p_entry': json,
      });

      return ChocolateConsumptionModel.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      debugPrint('Error creating chocolate consumption entry: $e');
      throw AppException.from(e);
    }
  }

  /// Update an existing record (e.g. entering night balance and updating consumed qty)
  Future<ChocolateConsumptionModel> updateEntry(ChocolateConsumptionModel entry) async {
    if (_ref != null && _ref.read(isChocolateUserProvider)) {
      throw AppException('Access Denied: Chocolate users cannot record or modify consumption entries.');
    }

    try {
      final json = entry.toJson(includeId: false);
      final response = await _client
          .from('chocolate_consumption_ledger')
          .update(json)
          .eq('id', entry.id)
          .select()
          .single();

      return ChocolateConsumptionModel.fromJson(response);
    } catch (e) {
      debugPrint('Error updating chocolate consumption entry: $e');
      throw AppException.from(e);
    }
  }

  /// Delete an entry
  Future<void> deleteEntry(int id) async {
    if (_ref != null && _ref.read(isChocolateUserProvider)) {
      throw AppException('Access Denied: Chocolate users cannot record or modify consumption entries.');
    }

    try {
      await _client.from('chocolate_consumption_ledger').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting chocolate consumption entry: $e');
      throw AppException.from(e);
    }
  }

  /// Fetch full statistical summary for Chocolate department
  Future<ChocolateDepartmentSummary> fetchChocolateDepartmentSummary() async {
    try {
      // Transferred in to Chocolate
      final transfers = await _client
          .from('transfers')
          .select('outward, return_units, department, category')
          .ilike('department', 'CHOCOLATE');

      double totalTransferred = 0.0;
      double totalReturned = 0.0;
      for (final row in (transfers as List<dynamic>)) {
        final dept = (row['department'] ?? '').toString().trim().toUpperCase();
        if (dept == 'CHOCOLATE') {
          final outward = (row['outward'] as num?)?.toDouble() ?? 0.0;
          final returns = (row['return_units'] as num?)?.toDouble() ?? 0.0;
          totalTransferred += outward;
          totalReturned += returns;
        }
      }

      // Consumption ledger
      final ledger = await _client.from('chocolate_consumption_ledger').select('*');

      double totalTaken = 0.0;
      double totalBalance = 0.0;
      double totalConsumed = 0.0;

      for (final row in (ledger as List<dynamic>)) {
        final taken = (row['taken_qty'] as num?)?.toDouble() ?? 0.0;
        final bal = (row['balance_qty'] as num?)?.toDouble() ?? 0.0;
        final consumed = (row['consumed_qty'] as num?)?.toDouble() ?? 0.0;

        totalTaken += taken;
        totalBalance += bal;
        totalConsumed += consumed;
      }

      final currentStock = (totalTransferred - totalReturned - totalConsumed).clamp(0.0, double.infinity);

      return ChocolateDepartmentSummary(
        totalTransferredIn: totalTransferred,
        totalTaken: totalTaken,
        totalBalanceReturned: totalBalance,
        totalNetConsumed: totalConsumed,
        currentChocolateStock: currentStock,
        entryCount: (ledger as List).length,
        totalReturnedToAdmin: totalReturned,
      );
    } catch (e) {
      debugPrint('Error fetching chocolate department summary: $e');
      throw AppException.from(e);
    }
  }
}
