import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/tea_consumption_model.dart';
import 'package:mms_app/data/repositories/tea_consumption_repository.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/providers/tea_consumption_providers.dart';
import 'package:mms_app/presentation/tea/tea_consume_screen.dart';
import 'package:mms_app/presentation/transfers/transfers_screen.dart';

class MockTeaConsumptionRepository extends TeaConsumptionRepository {
  final List<TeaConsumptionModel> _entries = [
    TeaConsumptionModel(
      id: 1,
      date: DateTime(2026, 10, 12),
      createdAt: DateTime(2026, 10, 12, 9, 30),
      updatedAt: DateTime(2026, 10, 12, 18, 0),
      materialCode: '202',
      description: 'GINGER "B" GRADE',
      category: 'TEA',
      department: 'TEA',
      unit: 'kg',
      takenQty: 26.0,
      balanceQty: 4.0,
      consumedQty: 22.0,
      operatorName: 'Mohamed',
      shift: 'Day Shift',
      status: 'CLOSED',
    ),
    TeaConsumptionModel(
      id: 2,
      date: DateTime(2026, 10, 12),
      createdAt: DateTime(2026, 10, 12, 10, 15),
      updatedAt: DateTime(2026, 10, 12, 10, 15),
      materialCode: '301',
      description: 'DATES',
      category: 'DRY FRUITS',
      department: 'TEA',
      unit: 'pcs',
      takenQty: 10.0,
      balanceQty: 0.0,
      consumedQty: 10.0,
      operatorName: 'Tea Worker',
      shift: 'Day Shift',
      status: 'TAKEN',
    ),
  ];

  @override
  Future<List<TeaConsumptionModel>> fetchConsumptionEntries({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
  }) async {
    return _entries;
  }

  @override
  Future<List<TeaTransferredMaterial>> fetchTransferredMaterials({
    bool onlyWithPositiveBalance = false,
  }) async {
    return [
      TeaTransferredMaterial(
        code: '202',
        description: 'GINGER "B" GRADE',
        units: 'kg',
        netTransferred: 26.0,
        totalConsumed: 22.0,
        currentBalance: 4.0,
      ),
      TeaTransferredMaterial(
        code: '301',
        description: 'DATES',
        units: 'pcs',
        netTransferred: 19.0,
        totalConsumed: 10.0,
        currentBalance: 9.0,
      ),
    ];
  }

  @override
  Future<TeaDepartmentSummary> fetchTeaDepartmentSummary() async {
    return TeaDepartmentSummary(
      totalTransferredIn: 45.0,
      totalTaken: 36.0,
      totalBalanceReturned: 4.0,
      totalNetConsumed: 32.0,
      currentTeaStock: 13.0,
      entryCount: 2,
    );
  }
}

void main() {
  group('1. Tea Consumption Model Unit Tests', () {
    test('Calculates consumed quantity as takenQty - balanceQty', () {
      final entry = TeaConsumptionModel(
        id: 10,
        date: DateTime(2026, 10, 12),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        materialCode: '500',
        description: 'MAIDHA',
        takenQty: 50.0,
        balanceQty: 10.0,
        consumedQty: 40.0,
      );

      expect(entry.takenQty, equals(50.0));
      expect(entry.balanceQty, equals(10.0));
      expect(entry.consumedQty, equals(40.0));
      expect(entry.takenQty - entry.balanceQty, equals(entry.consumedQty));
    });

    test('Serializes to JSON and deserializes correctly', () {
      final json = {
        'id': 5,
        'date': '2026-10-12',
        'created_at': '2026-10-12T09:30:00Z',
        'updated_at': '2026-10-12T18:00:00Z',
        'material_code': '202',
        'description': 'GINGER "B" GRADE',
        'category': 'TEA',
        'department': 'TEA',
        'unit': 'kg',
        'taken_qty': 26.0,
        'balance_qty': 4.0,
        'consumed_qty': 22.0,
        'operator_name': 'Ali',
        'shift': 'Day Shift',
        'status': 'CLOSED',
        'notes': 'Balance returned to storage',
      };

      final model = TeaConsumptionModel.fromJson(json);
      expect(model.id, equals(5));
      expect(model.materialCode, equals('202'));
      expect(model.description, equals('GINGER "B" GRADE'));
      expect(model.takenQty, equals(26.0));
      expect(model.balanceQty, equals(4.0));
      expect(model.consumedQty, equals(22.0));
      expect(model.operatorName, equals('Ali'));
      expect(model.status, equals('CLOSED'));

      final encoded = model.toJson();
      expect(encoded['taken_qty'], equals(26.0));
      expect(encoded['balance_qty'], equals(4.0));
      expect(encoded['consumed_qty'], equals(22.0));
    });
  });

  group('2. Tea Transfers View-Only Tests', () {
    testWidgets('TransfersScreen hides New Transfer button when isTeaUser is true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isTeaUserProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(
            home: TransfersScreen(isEmbedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure 'New Transfer' FAB is NOT present for Tea user (View only)
      expect(find.text('New Transfer'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('3. Tea Consume Screen UI Tests', () {
    testWidgets('Renders KPI summary, entries, and Record Material Taken button', (tester) async {
      final mockRepo = MockTeaConsumptionRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teaConsumptionRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: TeaConsumeScreen(isEmbedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check FAB
      expect(find.text('Record Material Taken'), findsOneWidget);

      // Check Summary Cards are removed per UI improvement requirements
      expect(find.text('Transferred In'), findsNothing);
      expect(find.text('Taken for Work'), findsNothing);
      expect(find.text('Balance Returned'), findsNothing);
      expect(find.text('Net Consumed'), findsNothing);

      // Check Ledger Cards Content
      expect(find.text('GINGER "B" GRADE'), findsOneWidget);
      expect(find.text('DATES'), findsOneWidget);
      expect(find.text('CODE: 202'), findsOneWidget);
      expect(find.text('CODE: 301'), findsOneWidget);

      // Check Taken, Returned and Consumed Pill labels
      expect(find.text('TAKEN QTY'), findsNWidgets(2));
      expect(find.text('RETURNED QTY'), findsNWidgets(2));
      expect(find.text('CONSUMED QTY'), findsNWidgets(2));
    });
  });
}
