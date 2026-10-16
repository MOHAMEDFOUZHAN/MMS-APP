import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/errors/app_exception.dart';
import 'package:mms_app/core/services/connection_service.dart';
import 'package:mms_app/data/models/tea_material_received_model.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/data/repositories/tea_consumption_repository.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/providers/tea_consumption_providers.dart';
import 'package:mms_app/presentation/tea/tea_material_received_screen.dart';

class MockConnectionService extends StateNotifier<ConnectionStatus> implements ConnectionService {
  MockConnectionService()
      : super(ConnectionStatus(state: AppConnectionState.online, lastChecked: DateTime.now()));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTeaStockRepository extends TeaConsumptionRepository {
  double outwardTransferred = 100.0;
  double consumedInLedger = 0.0;
  double returnedToAdmin = 0.0;

  @override
  Future<List<TeaMaterialReceivedModel>> fetchTeaMaterialReceivedStock({
    String? search,
    String? category,
    bool onlyWithBalance = false,
  }) async {
    final balance = (outwardTransferred - consumedInLedger - returnedToAdmin).clamp(0.0, double.infinity);
    final status = balance <= 0.0001 ? 'ZERO_BALANCE' : (balance <= 5.0 ? 'LOW_STOCK' : 'IN_STOCK');

    final item = TeaMaterialReceivedModel(
      materialCode: '101',
      description: 'LIME TEA',
      category: 'TEA',
      unit: 'kg',
      totalReceived: outwardTransferred,
      totalConsumed: consumedInLedger,
      totalReturned: returnedToAdmin,
      currentBalance: balance,
      latestTransactionAt: DateTime(2026, 10, 12, 14, 30),
      stockStatus: status,
    );

    if (onlyWithBalance && balance <= 0.0001) return [];
    if (search != null && search.isNotEmpty && !item.description.contains(search.toUpperCase())) return [];
    return [item];
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
    final currentBalance = (outwardTransferred - consumedInLedger - returnedToAdmin).clamp(0.0, double.infinity);
    if (returnQty <= 0) {
      throw AppException('Return quantity must be greater than zero.');
    }
    if (returnQty > currentBalance + 0.0001) {
      throw AppException('Cannot return $returnQty $units. Current Tea balance is only $currentBalance $units.');
    }

    returnedToAdmin += returnQty;
    return {
      'success': true,
      'outward': 0.0,
      'return_units': returnQty,
      'remaining_tea_balance': (outwardTransferred - consumedInLedger - returnedToAdmin).clamp(0.0, double.infinity),
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const teaProfile = UserProfileModel(
    id: 'tea-user-uuid',
    username: 'bm',
    fullName: 'Benchmark Tea Department',
    role: 'TEA_USER',
    permissions: ['tea.*', 'transfer.*', 'storage.*', 'dispatch.*', 'notifications.view'],
  );

  group('1. TeaMaterialReceivedModel Unit Tests', () {
    test('Calculates hasStock correctly based on currentBalance', () {
      const itemWithStock = TeaMaterialReceivedModel(
        materialCode: '101',
        description: 'LIME TEA',
        category: 'TEA',
        unit: 'kg',
        totalReceived: 100.0,
        totalConsumed: 80.0,
        totalReturned: 0.0,
        currentBalance: 20.0,
        stockStatus: 'IN_STOCK',
      );

      expect(itemWithStock.hasStock, isTrue);
      expect(itemWithStock.currentBalance, equals(20.0));

      final itemZero = itemWithStock.copyWith(
        totalReturned: 20.0,
        currentBalance: 0.0,
        stockStatus: 'ZERO_BALANCE',
      );

      expect(itemZero.hasStock, isFalse);
      expect(itemZero.currentBalance, equals(0.0));
      expect(itemZero.stockStatus, equals('ZERO_BALANCE'));
    });

    test('Serializes to JSON and deserializes correctly', () {
      final model = TeaMaterialReceivedModel(
        materialCode: '101',
        description: 'LIME TEA',
        category: 'TEA',
        unit: 'kg',
        totalReceived: 100.0,
        totalConsumed: 80.0,
        totalReturned: 20.0,
        currentBalance: 0.0,
        latestTransactionAt: DateTime(2026, 10, 12, 16, 45),
        stockStatus: 'ZERO_BALANCE',
      );

      final json = model.toJson();
      expect(json['material_code'], equals('101'));
      expect(json['total_received'], equals(100.0));
      expect(json['total_consumed'], equals(80.0));
      expect(json['total_returned'], equals(20.0));
      expect(json['current_balance'], equals(0.0));

      final restored = TeaMaterialReceivedModel.fromJson(json);
      expect(restored.materialCode, equals('101'));
      expect(restored.description, equals('LIME TEA'));
      expect(restored.totalReceived, equals(100.0));
      expect(restored.totalConsumed, equals(80.0));
      expect(restored.totalReturned, equals(20.0));
      expect(restored.currentBalance, equals(0.0));
    });
  });

  group('2. Transfer -> Material Received -> Consume -> Return Lifecycle Simulation', () {
    late FakeTeaStockRepository repo;

    setUp(() {
      repo = FakeTeaStockRepository();
    });

    test('Test A — Transfer: 100 kg transferred to Tea reflects 100 kg received and available', () async {
      final stock = await repo.fetchTeaMaterialReceivedStock();
      expect(stock.length, equals(1));
      final item = stock.first;
      expect(item.materialCode, equals('101'));
      expect(item.totalReceived, equals(100.0));
      expect(item.totalConsumed, equals(0.0));
      expect(item.totalReturned, equals(0.0));
      expect(item.currentBalance, equals(100.0));
      expect(item.stockStatus, equals('IN_STOCK'));
    });

    test('Test B — Consumption: Consuming 80 kg leaves 20 kg live balance in Tea', () async {
      repo.consumedInLedger = 80.0;

      final stock = await repo.fetchTeaMaterialReceivedStock();
      final item = stock.first;
      expect(item.totalReceived, equals(100.0));
      expect(item.totalConsumed, equals(80.0));
      expect(item.totalReturned, equals(0.0));
      expect(item.currentBalance, equals(20.0));
      expect(item.hasStock, isTrue);
    });

    test('Test C — Return: Returning 20 kg brings balance to 0 kg and prevents double return', () async {
      repo.consumedInLedger = 80.0;

      // 1. Confirm 20 kg is available
      var stock = await repo.fetchTeaMaterialReceivedStock();
      expect(stock.first.currentBalance, equals(20.0));

      // 2. Return 20 kg to Admin
      final result = await repo.recordReturnToAdmin(
        materialCode: '101',
        description: 'LIME TEA',
        returnQty: 20.0,
        units: 'kg',
        person: 'Tea Supervisor',
      );
      expect(result['success'], isTrue);
      expect(result['return_units'], equals(20.0));

      // 3. Verify Material Received now shows 0 kg balance
      stock = await repo.fetchTeaMaterialReceivedStock();
      expect(stock.first.totalReturned, equals(20.0));
      expect(stock.first.currentBalance, equals(0.0));
      expect(stock.first.stockStatus, equals('ZERO_BALANCE'));
      expect(stock.first.hasStock, isFalse);

      // 4. Attempting to return again must fail (prevent double return)
      expect(
        () => repo.recordReturnToAdmin(
          materialCode: '101',
          description: 'LIME TEA',
          returnQty: 20.0,
          units: 'kg',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('3. Tea Material Received Screen UI Widget Tests', () {
    testWidgets('Renders KPI header, material card, and metrics cleanly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = FakeTeaStockRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) => teaProfile),
            connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
            teaConsumptionRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: TeaMaterialReceivedScreen(isEmbedded: true),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Check Filter Chips
      expect(find.text('In-Stock Only'), findsOneWidget);

      // Check Material Card Content
      expect(find.text('LIME TEA'), findsOneWidget);
      expect(find.text('CODE: 101'), findsOneWidget);
      expect(find.text('IN STOCK'), findsOneWidget);

      // Check metrics
      expect(find.text('TOTAL RCVD'), findsOneWidget);
      expect(find.text('CONSUMED'), findsOneWidget);
      expect(find.text('RETURNED'), findsOneWidget);
      expect(find.text('LIVE BALANCE'), findsOneWidget);

      // Check Action Button
      expect(find.text('Return to Admin'), findsOneWidget);

      // Tap Return to Admin to open Dialog
      await tester.tap(find.text('Return to Admin'));
      await tester.pumpAndSettle();

      expect(find.text('Return Material to Admin'), findsOneWidget);
      expect(find.text('Currently Available in Tea:'), findsOneWidget);
      expect(find.text('100 kg'), findsWidgets);
    });
  });
}
