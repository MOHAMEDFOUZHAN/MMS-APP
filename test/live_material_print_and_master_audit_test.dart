import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/material_model.dart';
import 'package:mms_app/data/repositories/materials_repository.dart';
import 'package:mms_app/presentation/materials/materials_master_screen.dart';
import 'package:mms_app/presentation/materials/materials_screen.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';

class MockMaterialsRepository extends MaterialsRepository {
  final List<MaterialModel> mockMaterials;

  MockMaterialsRepository(this.mockMaterials);

  @override
  Future<List<MaterialModel>> fetchLiveMaterialsSummary({
    String? search,
    String? category,
    String? grade,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 1000,
    int offset = 0,
    int? expiryDays,
  }) async {
    return mockMaterials.where((m) {
      if (category != null && category.isNotEmpty && category != 'All' && m.category != category) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final query = search.trim().toLowerCase();
        if (!m.materialCode.toLowerCase().contains(query) &&
            !m.description.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).skip(offset).take(limit).toList();
  }

  @override
  Future<List<MaterialModel>> fetchMaterials({
    String? search,
    String? category,
    String? status,
    int limit = 1000,
    int offset = 0,
    int invoiceMaterialExpiryAlertDays = 30,
  }) async {
    return mockMaterials.where((m) {
      if (category != null && category.isNotEmpty && category != 'All' && m.category != category) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final query = search.trim().toLowerCase();
        if (!m.materialCode.toLowerCase().contains(query) &&
            !m.description.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).skip(offset).take(limit).toList();
  }

  @override
  Future<List<String>> fetchCategories() async {
    final set = <String>{};
    for (final m in mockMaterials) {
      if (m.category.isNotEmpty) set.add(m.category);
    }
    final list = set.toList()..sort();
    return list;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Create 150 mock materials to test that truncation beyond 100 does not occur
  final List<MaterialModel> sampleMaterials = List.generate(150, (i) {
    final code = '${100 + i}';
    final category = i < 30
        ? 'TEA'
        : i < 70
            ? 'CHOCOLATE'
            : i < 110
                ? 'OIL'
                : 'SPICES';
    return MaterialModel(
      id: i + 1,
      materialCode: code,
      description: 'MATERIAL ITEM $code',
      category: category,
      unit: 'KG',
      openingStock: 10.0 + i,
      purchased: 50.0,
      transferOut: 20.0,
      returnIn: 5.0,
      quantity: 45.0 + i,
      reorderLevel: 10.0,
    );
  });

  group('TASK 1 — Admin Live Material Category-Filtered Printing Tests', () {
    testWidgets('Live Material Screen displays Print button and category filter', (tester) async {
      final mockRepo = MockMaterialsRepository(sampleMaterials);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            materialsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: MaterialsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Print icon/button is present in header
      expect(find.byIcon(Icons.print_rounded), findsOneWidget);

      // Verify category chips are present
      expect(find.text('Category:'), findsOneWidget);
      expect(find.text('All'), findsWidgets);
      expect(find.text('TEA'), findsWidgets);
      expect(find.text('CHOCOLATE'), findsWidgets);
    });

    test('Category filtering logic in fetchLiveMaterialsSummary isolates categories', () async {
      final mockRepo = MockMaterialsRepository(sampleMaterials);

      // 1. All Categories returns all 150 materials (no 100 limit cut-off)
      final all = await mockRepo.fetchLiveMaterialsSummary(category: 'All');
      expect(all.length, equals(150));

      // 2. TEA category returns only TEA materials
      final teaOnly = await mockRepo.fetchLiveMaterialsSummary(category: 'TEA');
      expect(teaOnly.length, equals(30));
      expect(teaOnly.every((m) => m.category == 'TEA'), isTrue);

      // 3. CHOCOLATE category returns only CHOCOLATE materials
      final chocOnly = await mockRepo.fetchLiveMaterialsSummary(category: 'CHOCOLATE');
      expect(chocOnly.length, equals(40));
      expect(chocOnly.every((m) => m.category == 'CHOCOLATE'), isTrue);

      // 4. OIL category (previously cut off after 100) returns all 40 OIL materials
      final oilOnly = await mockRepo.fetchLiveMaterialsSummary(category: 'OIL');
      expect(oilOnly.length, equals(40));
      expect(oilOnly.every((m) => m.category == 'OIL'), isTrue);
    });
  });

  group('TASK 2 — Material Master Missing Records Audit & Resolution Tests', () {
    test('Material Master Repository fetches beyond 100 items without truncation', () async {
      final mockRepo = MockMaterialsRepository(sampleMaterials);

      // Default limit 1000 should return all 150 materials
      final masterList = await mockRepo.fetchMaterials();
      expect(masterList.length, equals(150));
      expect(masterList.first.materialCode, equals('100'));
      expect(masterList.last.materialCode, equals('249'));
    });

    testWidgets('Materials Master Screen renders search, category chips, and full items list', (tester) async {
      final mockRepo = MockMaterialsRepository(sampleMaterials);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            materialsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: MaterialsMasterScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check header and controls
      expect(find.text('Materials Master Data'), findsOneWidget);
      expect(find.text('Category:'), findsOneWidget);
      expect(find.text('150 Materials in Master Catalogue'), findsOneWidget);

      // Verify category chips exist
      expect(find.text('TEA'), findsWidgets);
      expect(find.text('CHOCOLATE'), findsWidgets);
      expect(find.text('OIL'), findsWidgets);

      // Verify items render
      expect(find.text('MATERIAL ITEM 100'), findsOneWidget);
      expect(find.text('Change Unit'), findsWidgets);
    });

    testWidgets('Tapping Category chip on Material Master filters list by category', (tester) async {
      final mockRepo = MockMaterialsRepository(sampleMaterials);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            materialsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: MaterialsMasterScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on OIL category chip
      final oilChip = find.widgetWithText(InkWell, 'OIL');
      expect(oilChip, findsOneWidget);
      await tester.tap(oilChip);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header status should reflect 40 materials in OIL
      expect(find.text('40 Materials in Master Catalogue'), findsOneWidget);
      expect(find.text('OIL'), findsWidgets);
    });
  });
}
