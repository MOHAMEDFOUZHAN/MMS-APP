import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/material_lot_model.dart';
import 'package:mms_app/data/models/material_model.dart';
import 'package:mms_app/presentation/materials/widgets/material_summary_card.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';

void main() {
  group('BENCHMARK MMS — Live Materials Summary & Lots Tests', () {
    test('1. MaterialModel parses all 10 summary fields + category and lotCount', () {
      final json = {
        'id': 19,
        'material_code': '100',
        'description': 'MINT',
        'category': 'SPICES',
        'grade': 'STANDARD',
        'opening_stock': '90.000',
        'purchased': '100.000',
        'transfer_out': '25.000',
        'return_in': '0.000',
        'closing_stock': '165.000',
        'shelves_bin': 'A-01',
        'reorder_level': '10.000',
        'unit': 'kg',
        'lot_count': 3,
        'earliest_expiry': '2026-06-30',
      };

      final mat = MaterialModel.fromJson(json);

      expect(mat.materialCode, equals('100'));
      expect(mat.description, equals('MINT'));
      expect(mat.grade, equals('STANDARD'));
      expect(mat.category, equals('SPICES'));
      expect(mat.openingStock, equals(90.0));
      expect(mat.purchased, equals(100.0));
      expect(mat.transferOut, equals(25.0));
      expect(mat.returnIn, equals(0.0));
      expect(mat.closingStock, equals(165.0));
      expect(mat.shelvesBin, equals('A-01'));
      expect(mat.reorderLevel, equals(10.0));
      expect(mat.unit, equals('kg'));
      expect(mat.lotCount, equals(3));
      expect(mat.isOutOfStock, isFalse);
      expect(mat.isReorder, isFalse);
    });

    test('2. MaterialLotModel parses all lot fields and strictly formats dates as DD/MM/YYYY', () {
      final lotJson = {
        'id': 70,
        'material_id': 19,
        'material_code': '100',
        'lot_no': 'BATCH-342',
        'lot_date': '2025-12-08',
        'expiry_date': '2026-02-28',
        'initial_quantity': '90.000',
        'available_quantity': '90.000',
        'uom': 'kg',
        'grade': 'STANDARD',
      };

      final lot = MaterialLotModel.fromJson(lotJson);

      expect(lot.lotNo, equals('BATCH-342'));
      expect(lot.grade, equals('STANDARD'));
      expect(lot.opening, equals(90.0));
      expect(lot.currentAvailability, equals(90.0));
      expect(lot.formattedPurchaseDate, equals('08/12/2025'));
      expect(lot.formattedExpiryDate, equals('28/02/2026'));
      expect(lot.isDepleted, isFalse);
    });

    test('3. Stock Reconciliation: Multi-lot sum exactly reconciles with material closing stock', () {
      final lot1 = MaterialLotModel.fromJson({
        'id': 1,
        'material_code': '100',
        'lot_no': 'BATCH-342',
        'lot_date': '2025-12-08',
        'initial_quantity': 90.0,
        'available_quantity': 90.0,
      });
      final lot2 = MaterialLotModel.fromJson({
        'id': 2,
        'material_code': '100',
        'lot_no': 'BATCH-350',
        'lot_date': '2025-12-15',
        'initial_quantity': 50.0,
        'available_quantity': 50.0,
      });
      final lot3 = MaterialLotModel.fromJson({
        'id': 3,
        'material_code': '100',
        'lot_no': 'BATCH-361',
        'lot_date': '2025-12-20',
        'initial_quantity': 25.0,
        'available_quantity': 25.0,
      });

      final lots = [lot1, lot2, lot3];
      final totalLotStock = lots.fold<double>(0.0, (acc, l) => acc + l.availableQuantity);
      const materialClosingStock = 165.0;

      // 90 + 50 + 25 = 165.0
      expect(totalLotStock, equals(materialClosingStock));
      expect((totalLotStock - materialClosingStock).abs() <= 0.001, isTrue);
    });

    test('4. Stock Reconciliation: Discrepancy detection between lots and material closing stock', () {
      final lot1 = MaterialLotModel.fromJson({
        'id': 1,
        'material_code': '100',
        'lot_no': 'BATCH-342',
        'lot_date': '2025-12-08',
        'initial_quantity': 90.0,
        'available_quantity': 90.0,
      });
      final lots = [lot1]; // Only 90 kg in lots
      const materialClosingStock = 165.0; // Material claims 165 kg

      final totalLotStock = lots.fold<double>(0.0, (acc, l) => acc + l.availableQuantity);
      final hasDiscrepancy = (totalLotStock - materialClosingStock).abs() > 0.005;

      expect(hasDiscrepancy, isTrue);
    });

    test('5. MaterialsFilter state management supports search, category, grade, status, and dates', () {
      var filter = MaterialsFilter();
      expect(filter.search, isEmpty);
      expect(filter.category, equals('All'));
      expect(filter.grade, equals('All'));
      expect(filter.status, equals('all'));
      expect(filter.fromDate, isNull);
      expect(filter.toDate, isNull);

      final from = DateTime(2026, 1, 1);
      final to = DateTime(2026, 12, 31);
      filter = filter.copyWith(
        search: 'BATCH-342',
        category: 'SPICES',
        grade: 'STANDARD',
        status: 'reorder',
        fromDate: from,
        toDate: to,
      );

      expect(filter.search, equals('BATCH-342'));
      expect(filter.category, equals('SPICES'));
      expect(filter.grade, equals('STANDARD'));
      expect(filter.status, equals('reorder'));
      expect(filter.fromDate, equals(from));
      expect(filter.toDate, equals(to));

      filter = filter.copyWith(clearDates: true);
      expect(filter.fromDate, isNull);
      expect(filter.toDate, isNull);
      expect(filter.search, equals('BATCH-342'));
    });

    testWidgets('6. MaterialSummaryCard renders all 10 summary fields and expands lot details', (tester) async {
      final sampleMaterial = MaterialModel(
        id: 19,
        materialCode: '100',
        description: 'MINT LEAVES',
        category: 'SPICES',
        grade: 'STANDARD',
        openingStock: 90.0,
        purchased: 100.0,
        transferOut: 25.0,
        returnIn: 0.0,
        quantity: 165.0,
        reorderLevel: 10.0,
        shelvesBin: 'BIN-12',
        unit: 'kg',
        lotCount: 1,
      );

      final sampleLot = MaterialLotModel(
        id: 70,
        materialCode: '100',
        lotNo: 'BATCH-342',
        lotDate: DateTime(2025, 12, 8),
        expiryDate: DateTime(2026, 2, 28),
        initialQuantity: 90.0,
        availableQuantity: 90.0,
        uom: 'kg',
        grade: 'STANDARD',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            materialLotsProvider('100').overrideWith((ref) async => [sampleLot]),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MaterialSummaryCard(
                material: sampleMaterial,
                isInitiallyExpanded: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify master summary fields rendered
      expect(find.text('100'), findsOneWidget);
      expect(find.text('MINT LEAVES'), findsOneWidget);
      expect(find.text('Category: SPICES'), findsOneWidget);
      expect(find.text('Grade: STANDARD'), findsWidgets);
      expect(find.text('Opening'), findsOneWidget);
      expect(find.text('Purchased'), findsOneWidget);
      expect(find.text('Transfer Out'), findsOneWidget);
      expect(find.text('Return In'), findsOneWidget);
      expect(find.text('Closing Stock'), findsOneWidget);
      expect(find.text('Shelves/Bin: BIN-12'), findsOneWidget);
      expect(find.text('Reorder: 10 kg'), findsOneWidget);

      // Verify expanded lot breakdown rendered
      expect(find.text('BATCH-342'), findsOneWidget);
      expect(find.text('Purchase Date: 08/12/2025'), findsOneWidget);
      expect(find.text('Expiry Date: 28/02/2026'), findsOneWidget);
    });
  });
}
