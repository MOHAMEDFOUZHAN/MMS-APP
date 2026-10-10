import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/material_model.dart';
import 'package:mms_app/data/repositories/materials_repository.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/reports/reorder_report.dart';

class MockMaterialsRepositoryForReorder extends Fake implements MaterialsRepository {
  Future<List<MaterialModel>> fetchMaterials({
    String? search,
    String? category,
    String? status,
    int limit = 100,
    int offset = 0,
    int invoiceMaterialExpiryAlertDays = 30,
  }) async {
    final list = [
      MaterialModel(
        id: 1,
        materialCode: 'RM-STEEL-001',
        description: 'Stainless Steel Sheet 2mm',
        category: 'Raw Material',
        quantity: 15.0,
        reorderLevel: 50.0,
        unit: 'kg',
      ),
      MaterialModel(
        id: 2,
        materialCode: 'RM-BRASS-002',
        description: 'Brass Rod 10mm',
        category: 'Raw Material',
        quantity: 8.0,
        reorderLevel: 20.0,
        unit: 'm',
      ),
    ];

    if (category != null && category != 'All') {
      return list.where((m) => m.category == category).toList();
    }
    return list;
  }

  Future<List<String>> fetchCategories() async => ['Raw Material', 'Packaging'];
}

void main() {
  group('Reorder Level Report Tests', () {
    test('1. MaterialModel isReorder calculation is accurate', () {
      final itemUnderReorder = MaterialModel(
        id: 1,
        materialCode: 'MAT-001',
        quantity: 25.0,
        reorderLevel: 50.0,
      );
      expect(itemUnderReorder.isReorder, isTrue);

      final itemAtReorder = MaterialModel(
        id: 2,
        materialCode: 'MAT-002',
        quantity: 50.0,
        reorderLevel: 50.0,
      );
      expect(itemAtReorder.isReorder, isTrue);

      final itemAboveReorder = MaterialModel(
        id: 3,
        materialCode: 'MAT-003',
        quantity: 75.0,
        reorderLevel: 50.0,
      );
      expect(itemAboveReorder.isReorder, isFalse);

      final itemOutOfStock = MaterialModel(
        id: 4,
        materialCode: 'MAT-004',
        quantity: 0.0,
        reorderLevel: 50.0,
      );
      // Depleted stock is out_of_stock, not strictly reorder
      expect(itemOutOfStock.isOutOfStock, isTrue);
      expect(itemOutOfStock.isReorder, isFalse);
    });

    testWidgets('2. ReorderReport widget renders cards and items requiring reorder without crashing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockRepo = MockMaterialsRepositoryForReorder();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            materialsRepositoryProvider.overrideWithValue(mockRepo as dynamic),
            categoriesProvider.overrideWith((ref) => Future.value(['Raw Material', 'Packaging'])),
          ],
          child: const MaterialApp(
            home: ReorderReport(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reorder Level Report'), findsOneWidget);
      expect(find.text('RM-STEEL-001'), findsOneWidget);
      expect(find.text('RM-BRASS-002'), findsOneWidget);
      expect(find.text('2 Items Require Reorder'), findsOneWidget);
      expect(find.text('Export PDF'), findsOneWidget);
    });
  });
}
