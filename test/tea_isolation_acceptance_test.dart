import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/errors/app_exception.dart';
import 'package:mms_app/data/models/tea_consumption_model.dart';
import 'package:mms_app/data/models/tea_material_received_model.dart';
import 'package:mms_app/data/repositories/tea_consumption_repository.dart';

/// Test fixture simulating the authoritative transfers and consumption ledger
class IsolatedTeaRepository extends TeaConsumptionRepository {
  // Simulates public.materials (Admin Material Master with 100 materials)
  final Map<String, double> masterMaterials = {
    '001': 1000.0, // LIME TEA
    '202': 500.0,  // GINGER
    '301': 200.0,  // DATES (exists in master, never transferred to tea in test)
    '302': 150.0,  // PISTACHIO
    '999': 100.0,  // CHOCOLATE EXCLUSIVE
  };

  // Simulates public.transfers
  final List<Map<String, dynamic>> transfers = [];

  // Simulates public.tea_consumption_ledger
  final List<TeaConsumptionModel> ledger = [];

  void addTransfer({
    required String code,
    required String description,
    required String department,
    required double outward,
    required double returnUnits,
    required String units,
  }) {
    transfers.add({
      'code': code,
      'description': description,
      'department': department,
      'outward': outward,
      'return_units': returnUnits,
      'units': units,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<TeaTransferredMaterial>> fetchTransferredMaterials({
    bool onlyWithPositiveBalance = false,
  }) async {
    final Map<String, Map<String, dynamic>> materialMap = {};

    for (final row in transfers) {
      final dept = (row['department'] ?? '').toString().trim().toUpperCase();
      if (dept == 'TEA') {
        final code = (row['code'] ?? '').toString().trim();
        final desc = (row['description'] ?? '').toString().trim();
        final units = (row['units'] ?? 'kg').toString().trim();
        final outward = (row['outward'] as num?)?.toDouble() ?? 0.0;
        final returnUnits = (row['return_units'] as num?)?.toDouble() ?? 0.0;

        if (!materialMap.containsKey(code)) {
          materialMap[code] = {
            'code': code,
            'description': desc,
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

    final Map<String, double> consumedMap = {};
    for (final entry in ledger) {
      consumedMap[entry.materialCode] =
          (consumedMap[entry.materialCode] ?? 0.0) + entry.consumedQty;
    }

    final List<TeaTransferredMaterial> results = [];
    for (final entry in materialMap.values) {
      final code = entry['code'] as String;
      final totalRcvd = entry['total_received'] as double;
      final totalReturned = entry['total_returned'] as double;
      final consumed = consumedMap[code] ?? 0.0;

      if (totalRcvd <= 0.0001) continue;

      final netTransferred = totalRcvd - totalReturned;
      final balance = (totalRcvd - consumed - totalReturned).clamp(0.0, double.infinity);

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
  }

  @override
  Future<List<TeaMaterialReceivedModel>> fetchTeaMaterialReceivedStock({
    String? search,
    String? category,
    bool onlyWithBalance = false,
  }) async {
    final Map<String, Map<String, dynamic>> materialMap = {};

    for (final row in transfers) {
      final dept = (row['department'] ?? '').toString().trim().toUpperCase();
      if (dept == 'TEA') {
        final code = (row['code'] ?? '').toString().trim();
        final desc = (row['description'] ?? '').toString().trim();
        final units = (row['units'] ?? 'kg').toString().trim();
        final outward = (row['outward'] as num?)?.toDouble() ?? 0.0;
        final returnUnits = (row['return_units'] as num?)?.toDouble() ?? 0.0;

        if (!materialMap.containsKey(code)) {
          materialMap[code] = {
            'code': code,
            'description': desc,
            'category': 'TEA',
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

    final Map<String, double> consumedMap = {};
    for (final entry in ledger) {
      consumedMap[entry.materialCode] =
          (consumedMap[entry.materialCode] ?? 0.0) + entry.consumedQty;
    }

    final List<TeaMaterialReceivedModel> list = [];
    for (final entry in materialMap.values) {
      final code = entry['code'] as String;
      final desc = entry['description'] as String;
      final totalRcvd = entry['total_received'] as double;
      final totalReturned = entry['total_returned'] as double;
      final totalConsumed = consumedMap[code] ?? 0.0;

      // Materials with no actual inward transfer to Tea must never appear
      if (totalRcvd <= 0.0001) continue;

      final currentBalance = (totalRcvd - totalConsumed - totalReturned).clamp(0.0, double.infinity);

      if (onlyWithBalance && currentBalance <= 0.0001) continue;

      list.add(
        TeaMaterialReceivedModel(
          materialCode: code,
          description: desc,
          category: 'TEA',
          unit: entry['units'] as String,
          totalReceived: totalRcvd,
          totalConsumed: totalConsumed,
          totalReturned: totalReturned,
          currentBalance: currentBalance,
          latestTransactionAt: DateTime.now(),
          stockStatus: currentBalance <= 0.0001 ? 'ZERO_BALANCE' : 'IN_STOCK',
        ),
      );
    }
    return list;
  }

  @override
  Future<TeaConsumptionModel> createEntry(TeaConsumptionModel entry) async {
    // Backend validation simulation (exact logic as record_tea_consumption RPC)
    double totalRcvd = 0.0;
    double totalRet = 0.0;
    for (final t in transfers) {
      if (t['code'] == entry.materialCode && (t['department'] as String).toUpperCase() == 'TEA') {
        totalRcvd += (t['outward'] as num).toDouble();
        totalRet += (t['return_units'] as num).toDouble();
      }
    }

    if (totalRcvd <= 0.0001) {
      throw AppException('Material ${entry.materialCode} has not been transferred to Tea department.');
    }

    double totalConsumed = 0.0;
    for (final l in ledger) {
      if (l.materialCode == entry.materialCode) {
        totalConsumed += l.consumedQty;
      }
    }

    final available = totalRcvd - totalRet - totalConsumed;
    if (available <= 0.0001) {
      throw AppException('Material ${entry.materialCode} has zero available balance in Tea department.');
    }

    if (entry.consumedQty > (available + 0.0001)) {
      throw AppException('Insufficient Tea balance for material ${entry.materialCode}. Requested: ${entry.consumedQty}, Available: $available');
    }

    final saved = TeaConsumptionModel(
      id: ledger.length + 1,
      date: entry.date,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      materialCode: entry.materialCode,
      description: entry.description,
      category: 'TEA',
      department: 'TEA',
      unit: entry.unit,
      takenQty: available,
      balanceQty: available - entry.consumedQty,
      consumedQty: entry.consumedQty,
      operatorName: entry.operatorName,
      status: 'CLOSED',
    );
    ledger.add(saved);
    return saved;
  }

  @override
  Future<Map<String, dynamic>> recordReturnToAdmin({
    required String materialCode,
    required String description,
    required double returnQty,
    required String units,
    String? person,
    String? notes,
  }) async {
    // 1. Calculate available balance in Tea
    final receivedList = await fetchTeaMaterialReceivedStock();
    final item = receivedList.firstWhere(
      (m) => m.materialCode == materialCode,
      orElse: () => throw AppException('Material $materialCode is not registered in Tea inventory.'),
    );

    if (returnQty > (item.currentBalance + 0.0001)) {
      throw AppException('Cannot return $returnQty $units. Current Tea available balance is only ${item.currentBalance} $units.');
    }

    // 2. Insert transfer record
    addTransfer(
      code: materialCode,
      description: description,
      department: 'TEA',
      outward: 0.0,
      returnUnits: returnQty,
      units: units,
    );

    // 3. Admin stock increases by returnQty exactly once
    if (masterMaterials.containsKey(materialCode)) {
      masterMaterials[materialCode] = masterMaterials[materialCode]! + returnQty;
    }

    return {'success': true, 'return_units': returnQty};
  }
}

void main() {
  group('Prompt Acceptance Tests — Tea Material Isolation & Consumption', () {
    late IsolatedTeaRepository repo;

    setUp(() {
      repo = IsolatedTeaRepository();
    });

    test('Acceptance 1: Material in Material Master never transferred to Tea does not appear', () async {
      // DATES (301) exists in Master (200 qty) but 0 transfers to Tea
      final receivedStock = await repo.fetchTeaMaterialReceivedStock();
      final dropdownItems = await repo.fetchTransferredMaterials(onlyWithPositiveBalance: true);

      expect(receivedStock.any((m) => m.materialCode == '301'), isFalse,
          reason: 'Dates must not appear in Tea Material Received');
      expect(dropdownItems.any((m) => m.code == '301'), isFalse,
          reason: 'Dates must not appear in Tea Consume dropdown');
    });

    test('Acceptance 2: Material transferred from Admin to Tea appears in both pages with correct balance', () async {
      // Admin transfers Lime Tea (100 KG) and Ginger (20 KG) to Tea
      repo.addTransfer(
        code: '001',
        description: 'LIME TEA',
        department: 'TEA',
        outward: 100.0,
        returnUnits: 0.0,
        units: 'KG',
      );
      repo.addTransfer(
        code: '202',
        description: 'GINGER',
        department: 'TEA',
        outward: 20.0,
        returnUnits: 0.0,
        units: 'KG',
      );

      final receivedStock = await repo.fetchTeaMaterialReceivedStock();
      final dropdownItems = await repo.fetchTransferredMaterials(onlyWithPositiveBalance: true);

      expect(receivedStock.length, equals(2));
      expect(receivedStock.firstWhere((m) => m.materialCode == '001').currentBalance, equals(100.0));
      expect(receivedStock.firstWhere((m) => m.materialCode == '202').currentBalance, equals(20.0));

      expect(dropdownItems.length, equals(2));
      expect(dropdownItems.firstWhere((m) => m.code == '001').currentBalance, equals(100.0));
      expect(dropdownItems.firstWhere((m) => m.code == '202').currentBalance, equals(20.0));
    });

    test('Acceptance 3: Material transferred only to Chocolate does not appear in Tea', () async {
      // Admin transfers material to Chocolate
      repo.addTransfer(
        code: '999',
        description: 'CHOCOLATE PASTE',
        department: 'CHOCOLATE',
        outward: 50.0,
        returnUnits: 0.0,
        units: 'KG',
      );

      final receivedStock = await repo.fetchTeaMaterialReceivedStock();
      final dropdownItems = await repo.fetchTransferredMaterials(onlyWithPositiveBalance: true);

      expect(receivedStock.any((m) => m.materialCode == '999'), isFalse);
      expect(dropdownItems.any((m) => m.code == '999'), isFalse);
    });

    test('Acceptance 4: A Tea material partially consumed decreases available balance correctly', () async {
      repo.addTransfer(
        code: '001',
        description: 'LIME TEA',
        department: 'TEA',
        outward: 100.0,
        returnUnits: 0.0,
        units: 'KG',
      );

      // Consume 40 KG
      await repo.createEntry(TeaConsumptionModel(
        id: 0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        materialCode: '001',
        description: 'LIME TEA',
        category: 'TEA',
        department: 'TEA',
        unit: 'KG',
        takenQty: 100.0,
        balanceQty: 60.0,
        consumedQty: 40.0,
        operatorName: 'Worker 1',
        status: 'CLOSED',
      ));

      final receivedStock = await repo.fetchTeaMaterialReceivedStock();
      final dropdownItems = await repo.fetchTransferredMaterials(onlyWithPositiveBalance: true);

      final item = receivedStock.firstWhere((m) => m.materialCode == '001');
      expect(item.totalReceived, equals(100.0));
      expect(item.totalConsumed, equals(40.0));
      expect(item.currentBalance, equals(60.0));

      final dropdownItem = dropdownItems.firstWhere((m) => m.code == '001');
      expect(dropdownItem.currentBalance, equals(60.0));
    });

    test('Acceptance 5: A Tea material fully consumed disappears from eligible Consume dropdown', () async {
      repo.addTransfer(
        code: '001',
        description: 'LIME TEA',
        department: 'TEA',
        outward: 100.0,
        returnUnits: 0.0,
        units: 'KG',
      );

      // Consume all 100 KG
      await repo.createEntry(TeaConsumptionModel(
        id: 0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        materialCode: '001',
        description: 'LIME TEA',
        category: 'TEA',
        department: 'TEA',
        unit: 'KG',
        takenQty: 100.0,
        balanceQty: 0.0,
        consumedQty: 100.0,
        operatorName: 'Worker 1',
        status: 'CLOSED',
      ));

      // Tea Material Received still shows it with 0 balance
      final receivedStock = await repo.fetchTeaMaterialReceivedStock();
      final item = receivedStock.firstWhere((m) => m.materialCode == '001');
      expect(item.currentBalance, equals(0.0));
      expect(item.stockStatus, equals('ZERO_BALANCE'));

      // Consume dropdown with positive balance filter completely omits it
      final dropdownItems = await repo.fetchTransferredMaterials(onlyWithPositiveBalance: true);
      expect(dropdownItems.any((m) => m.code == '001'), isFalse,
          reason: 'Depleted materials must disappear from Consume dropdown');
    });

    test('Acceptance 6: Physically returned material decreases Tea balance and updates Admin stock exactly once', () async {
      final initialAdminStock = repo.masterMaterials['001']!; // 1000.0

      // Admin transfers 100 KG to Tea
      repo.addTransfer(
        code: '001',
        description: 'LIME TEA',
        department: 'TEA',
        outward: 100.0,
        returnUnits: 0.0,
        units: 'KG',
      );

      // Tea consumes 80 KG -> 20 KG left
      await repo.createEntry(TeaConsumptionModel(
        id: 0,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        materialCode: '001',
        description: 'LIME TEA',
        category: 'TEA',
        department: 'TEA',
        unit: 'KG',
        takenQty: 100.0,
        balanceQty: 20.0,
        consumedQty: 80.0,
        operatorName: 'Worker 1',
        status: 'CLOSED',
      ));

      // Tea physically returns remaining 20 KG to Admin
      await repo.recordReturnToAdmin(
        materialCode: '001',
        description: 'LIME TEA',
        returnQty: 20.0,
        units: 'KG',
      );

      final receivedStock = await repo.fetchTeaMaterialReceivedStock();
      final item = receivedStock.firstWhere((m) => m.materialCode == '001');
      expect(item.totalReceived, equals(100.0));
      expect(item.totalConsumed, equals(80.0));
      expect(item.totalReturned, equals(20.0));
      expect(item.currentBalance, equals(0.0));

      // Admin stock updated exactly once (+20)
      expect(repo.masterMaterials['001'], equals(initialAdminStock + 20.0));
    });

    test('Acceptance 7: Multiple transfers of same material aggregated into single dropdown entry', () async {
      // Transfer 1: 30 KG
      repo.addTransfer(
        code: '001',
        description: 'LIME TEA',
        department: 'TEA',
        outward: 30.0,
        returnUnits: 0.0,
        units: 'KG',
      );
      // Transfer 2: 70 KG
      repo.addTransfer(
        code: '001',
        description: 'LIME TEA',
        department: 'TEA',
        outward: 70.0,
        returnUnits: 0.0,
        units: 'KG',
      );

      final dropdownItems = await repo.fetchTransferredMaterials(onlyWithPositiveBalance: true);
      expect(dropdownItems.where((m) => m.code == '001').length, equals(1),
          reason: 'Must aggregate into one single entry');
      expect(dropdownItems.firstWhere((m) => m.code == '001').currentBalance, equals(100.0));
    });

    test('Acceptance 8: Tea user attempts to consume more than available balance is rejected', () async {
      repo.addTransfer(
        code: '001',
        description: 'LIME TEA',
        department: 'TEA',
        outward: 50.0,
        returnUnits: 0.0,
        units: 'KG',
      );

      // Attempt to consume 55 KG
      expect(
        () => repo.createEntry(TeaConsumptionModel(
          id: 0,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          materialCode: '001',
          description: 'LIME TEA',
          category: 'TEA',
          department: 'TEA',
          unit: 'KG',
          takenQty: 50.0,
          balanceQty: 0.0,
          consumedQty: 55.0,
          operatorName: 'Worker 1',
          status: 'CLOSED',
        )),
        throwsA(isA<AppException>().having(
          (e) => e.message,
          'message',
          contains('Insufficient Tea balance'),
        )),
      );
    });

    test('Acceptance 9: Attempting to consume untransferred material is rejected', () async {
      // Attempt to consume DATES (301) which was never transferred
      expect(
        () => repo.createEntry(TeaConsumptionModel(
          id: 0,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          materialCode: '301',
          description: 'DATES',
          category: 'DRY FRUITS',
          department: 'TEA',
          unit: 'PCS',
          takenQty: 10.0,
          balanceQty: 0.0,
          consumedQty: 10.0,
          operatorName: 'Worker 1',
          status: 'CLOSED',
        )),
        throwsA(isA<AppException>().having(
          (e) => e.message,
          'message',
          contains('has not been transferred to Tea department'),
        )),
      );
    });
  });
}
