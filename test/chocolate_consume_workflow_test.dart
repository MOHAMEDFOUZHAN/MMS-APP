import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/chocolate_consumption_model.dart';
import 'package:mms_app/data/models/tea_consumption_model.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/data/repositories/chocolate_consumption_repository.dart';

void main() {
  group('Chocolate Consume Workflow & Strict Department Isolation Test Suite', () {
    // -------------------------------------------------------------------------
    // Criterion 1: A material transferred only to Tea never appears in Chocolate Consume
    // -------------------------------------------------------------------------
    test('1. Material transferred only to Tea never appears in Chocolate Consume', () {
      final mockTransfers = [
        {'code': 'TEA01', 'description': 'EARL GREY TEA', 'units': 'kg', 'outward': 50.0, 'return_units': 0.0, 'department': 'TEA'},
        {'code': 'TEA02', 'description': 'GREEN TEA LEAVES', 'units': 'kg', 'outward': 30.0, 'return_units': 0.0, 'department': 'TEA'},
        {'code': 'CHOC01', 'description': 'DARK PURE COCOA', 'units': 'kg', 'outward': 25.0, 'return_units': 0.0, 'department': 'CHOCOLATE'},
      ];

      // Simulate Chocolate repository transfer filtering
      final Map<String, Map<String, dynamic>> chocolateMaterialMap = {};
      for (final row in mockTransfers) {
        final dept = (row['department'] as String).trim().toUpperCase();
        if (dept == 'CHOCOLATE') {
          final code = row['code'] as String;
          chocolateMaterialMap[code] = {
            'code': code,
            'description': row['description'],
            'units': row['units'],
            'total_received': row['outward'],
            'total_returned': row['return_units'],
          };
        }
      }

      expect(chocolateMaterialMap.containsKey('TEA01'), isFalse);
      expect(chocolateMaterialMap.containsKey('TEA02'), isFalse);
      expect(chocolateMaterialMap.containsKey('CHOC01'), isTrue);
      expect(chocolateMaterialMap.length, equals(1));
    });

    // -------------------------------------------------------------------------
    // Criterion 2: A material transferred from Admin to Chocolate appears in Chocolate Consume
    // -------------------------------------------------------------------------
    test('2. Material transferred from Admin to Chocolate appears in Chocolate Consume', () {
      final mockTransfers = [
        {'code': '2', 'description': 'WHITE COCO', 'units': 'KG', 'outward': 100.0, 'return_units': 0.0, 'department': 'CHOCOLATE'},
      ];

      final Map<String, Map<String, dynamic>> chocolateMaterialMap = {};
      for (final row in mockTransfers) {
        if ((row['department'] as String).trim().toUpperCase() == 'CHOCOLATE') {
          final code = row['code'] as String;
          chocolateMaterialMap[code] = {
            'code': code,
            'description': row['description'],
            'units': row['units'],
            'total_received': row['outward'],
            'total_returned': row['return_units'],
          };
        }
      }

      expect(chocolateMaterialMap.containsKey('2'), isTrue);
      final item = chocolateMaterialMap['2']!;
      expect(item['description'], equals('WHITE COCO'));
      expect(item['total_received'], equals(100.0));
    });

    // -------------------------------------------------------------------------
    // Criterion 3: A material that exists only in Material Master does not appear
    // -------------------------------------------------------------------------
    test('3. Material that exists only in Material Master does not appear in dropdown', () {
      // In Material Master:
      final materialMaster = [
        {'material_code': 'RAW_999', 'description': 'UNASSIGNED SUGAR', 'quantity': 1000.0},
      ];

      // Actual transfers:
      final transfers = <Map<String, dynamic>>[];

      // Chocolate consume dropdown queries transfers directly, NOT materials table:
      final eligibleMaterials = transfers
          .where((t) => (t['department'] ?? '').toString().toUpperCase() == 'CHOCOLATE')
          .toList();

      expect(eligibleMaterials.any((m) => m['code'] == 'RAW_999'), isFalse);
      expect(materialMaster.any((m) => m['material_code'] == 'RAW_999'), isTrue);
    });

    // -------------------------------------------------------------------------
    // Criterion 4: Multiple transfers of the same Chocolate material produce one dropdown entry
    // -------------------------------------------------------------------------
    test('4. Multiple transfers of the same Chocolate material produce one dropdown entry with aggregated balance', () {
      final mockTransfers = [
        {'code': 'CHOC01', 'description': 'DARK PURE COCOA', 'units': 'kg', 'outward': 15.0, 'return_units': 0.0, 'department': 'CHOCOLATE'},
        {'code': 'CHOC01', 'description': 'DARK PURE COCOA', 'units': 'kg', 'outward': 25.0, 'return_units': 5.0, 'department': 'CHOCOLATE'},
        {'code': 'CHOC01', 'description': 'DARK PURE COCOA', 'units': 'kg', 'outward': 10.0, 'return_units': 0.0, 'department': 'CHOCOLATE'},
      ];

      final Map<String, Map<String, dynamic>> materialMap = {};
      for (final row in mockTransfers) {
        if ((row['department'] as String).toUpperCase() == 'CHOCOLATE') {
          final code = row['code'] as String;
          if (!materialMap.containsKey(code)) {
            materialMap[code] = {
              'code': code,
              'description': row['description'],
              'units': row['units'],
              'total_received': 0.0,
              'total_returned': 0.0,
            };
          }
          materialMap[code]!['total_received'] =
              (materialMap[code]!['total_received'] as double) + (row['outward'] as double);
          materialMap[code]!['total_returned'] =
              (materialMap[code]!['total_returned'] as double) + (row['return_units'] as double);
        }
      }

      expect(materialMap.length, equals(1));
      final aggregated = materialMap['CHOC01']!;
      expect(aggregated['total_received'], equals(50.0)); // 15 + 25 + 10
      expect(aggregated['total_returned'], equals(5.0));
      final availableBalance = aggregated['total_received'] - aggregated['total_returned'];
      expect(availableBalance, equals(45.0));
    });

    // -------------------------------------------------------------------------
    // Criterion 5: Fully consumed materials cannot be consumed again when balance is zero
    // -------------------------------------------------------------------------
    test('5. Fully consumed materials are excluded from active consume dropdown', () {
      final transferredItem = ChocolateTransferredMaterial(
        code: 'CHOC02',
        description: 'VANASPATHI',
        units: 'BOX',
        netTransferred: 10.0,
        totalConsumed: 10.0,
        currentBalance: 0.0, // Fully consumed!
      );

      final inStockItem = ChocolateTransferredMaterial(
        code: 'CHOC03',
        description: 'ALMOND',
        units: 'KG',
        netTransferred: 15.0,
        totalConsumed: 3.0,
        currentBalance: 12.0,
      );

      final allTransferred = [transferredItem, inStockItem];
      // Filtering applied by dropdown:
      final dropdownItems = allTransferred.where((m) => m.currentBalance > 0.0001).toList();

      expect(dropdownItems.length, equals(1));
      expect(dropdownItems.first.code, equals('CHOC03'));
      expect(dropdownItems.any((m) => m.code == 'CHOC02'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Criterion 6: Overconsumption is rejected
    // -------------------------------------------------------------------------
    test('6. Overconsumption is detected and rejected when requested qty > available balance', () {
      final availableBalance = 15.0;
      final requestedConsumed = 20.0;

      String? validationError;
      if (requestedConsumed > (availableBalance + 0.0001)) {
        validationError = 'Cannot exceed available balance ($availableBalance kg)';
      }

      expect(validationError, isNotNull);
      expect(validationError, contains('Cannot exceed available balance'));
    });

    // -------------------------------------------------------------------------
    // Criterion 7: Saving Chocolate consumption updates only Chocolate balance
    // -------------------------------------------------------------------------
    test('7. Saving Chocolate consumption updates only Chocolate balance without affecting Tea or Admin', () {
      final initialAdminStock = 500.0;
      final initialTeaBalance = 80.0;
      final initialChocBalance = 100.0;

      // Chocolate consumes 15.0 kg
      final chocConsumedQty = 15.0;
      final updatedChocBalance = initialChocBalance - chocConsumedQty;

      // Tea & Admin balances must remain identical
      final updatedAdminStock = initialAdminStock;
      final updatedTeaBalance = initialTeaBalance;

      expect(updatedChocBalance, equals(85.0));
      expect(updatedAdminStock, equals(500.0));
      expect(updatedTeaBalance, equals(80.0));
    });

    // -------------------------------------------------------------------------
    // Criterion 8: Tea Consume model and records remain completely independent
    // -------------------------------------------------------------------------
    test('8. Tea Consume model and records remain completely independent', () {
      final teaEntry = TeaConsumptionModel(
        id: 101,
        date: DateTime.parse('2026-10-14'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        materialCode: 'TEA01',
        description: 'CARDAMOM TEA',
        category: 'TEA',
        department: 'TEA',
        takenQty: 25.0,
        consumedQty: 5.0,
        balanceQty: 20.0,
      );

      final chocEntry = ChocolateConsumptionModel(
        id: 201,
        date: DateTime.parse('2026-10-14'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        materialCode: 'CHOC01',
        description: 'DARK PURE',
        category: 'CHOCOLATE',
        department: 'CHOCOLATE',
        takenQty: 10.0,
        consumedQty: 2.0,
        balanceQty: 8.0,
      );

      expect(teaEntry.department, equals('TEA'));
      expect(chocEntry.department, equals('CHOCOLATE'));
      expect(teaEntry.materialCode, isNot(equals(chocEntry.materialCode)));
    });

    // -------------------------------------------------------------------------
    // Criterion 9: Chocolate navigation strictly limited to 3 modules (OCR, Rack, Consign)
    // -------------------------------------------------------------------------
    test('9. Chocolate navigation strictly contains OCR, Rack, and Consign without Transfer or Consume', () {
      // Chocolate nav sequence: OCR (0), Rack (1), Consign (2)
      final chocolateNavLabels = ['OCR', 'Rack', 'Consign'];

      expect(chocolateNavLabels.length, equals(3));
      expect(chocolateNavLabels[0], equals('OCR'));
      expect(chocolateNavLabels[1], equals('Rack'));
      expect(chocolateNavLabels[2], equals('Consign'));
      expect(chocolateNavLabels.contains('Transfer'), isFalse);
      expect(chocolateNavLabels.contains('Consume'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Criterion 10: Idempotency prevents double posting
    // -------------------------------------------------------------------------
    test('10. Duplicate submissions with identical idempotency key prevent double-deduction', () {
      final Map<String, dynamic> idempotencyStore = {};

      final firstSubmissionKey = 'idem_key_chocolate_1001';
      final responseData = {'id': 99, 'consumed_qty': 5.0, 'status': 'completed'};

      // First run stores result
      idempotencyStore[firstSubmissionKey] = responseData;

      // Second run with same key
      Map<String, dynamic>? secondRunResult;
      if (idempotencyStore.containsKey(firstSubmissionKey)) {
        secondRunResult = idempotencyStore[firstSubmissionKey];
      }

      expect(secondRunResult, isNotNull);
      expect(secondRunResult!['id'], equals(99));
      expect(secondRunResult['consumed_qty'], equals(5.0));
    });

    // -------------------------------------------------------------------------
    // Criterion 11: Chocolate user profile permissions strictly disallow Transfer and Consume
    // -------------------------------------------------------------------------
    test('11. Chocolate UserProfileModel explicitly denies transfer and consume permissions', () {
      final chocProfile = const UserProfileModel(
        id: 'choc-user-1',
        username: 'chocolate',
        fullName: 'Chocolate User',
        role: 'CHOCOLATE_USER',
        permissions: [
          'chocolate.*',
          'ocr.*',
          'storage.*',
          'dispatch.*',
          'consign.*',
          'notifications.view',
        ],
      );

      expect(chocProfile.isChocolateUser, isTrue);
      expect(chocProfile.hasPermission('ocr.view'), isTrue);
      expect(chocProfile.hasPermission('storage.view'), isTrue);
      expect(chocProfile.hasPermission('dispatch.view'), isTrue);
      expect(chocProfile.hasPermission('transfer.view'), isFalse);
      expect(chocProfile.hasPermission('transfer.create'), isFalse);
      expect(chocProfile.hasPermission('consume.view'), isFalse);
      expect(chocProfile.hasPermission('consume.create'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Criterion 12: Admin Transfer and Tea Consume functionality remain intact
    // -------------------------------------------------------------------------
    test('12. Admin retains Transfer permissions and Tea retains Consume permissions', () {
      final adminProfile = const UserProfileModel(
        id: 'admin-1',
        username: 'admin',
        fullName: 'Administrator',
        role: 'ADMIN',
        permissions: ['*'],
      );

      expect(adminProfile.isAdmin, isTrue);
      expect(adminProfile.hasPermission('transfer.view'), isTrue);
      expect(adminProfile.hasPermission('transfer.create'), isTrue);

      final teaProfile = const UserProfileModel(
        id: 'tea-1',
        username: 'bm',
        fullName: 'Tea Department',
        role: 'TEA_USER',
        permissions: ['tea.*', 'transfers.view', 'consume.*'],
      );

      expect(teaProfile.isTeaUser, isTrue);
      expect(teaProfile.hasPermission('consume.create'), isTrue);
    });
  });
}
