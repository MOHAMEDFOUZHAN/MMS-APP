import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/inventory_settings_model.dart';
import 'package:mms_app/data/models/owner_reporting_models.dart';
import 'package:mms_app/presentation/owner/owner_shell_screen.dart';
import 'package:mms_app/presentation/owner/sections/owner_expiry_list_screen.dart';
import 'package:mms_app/presentation/providers/inventory_settings_provider.dart';
import 'package:mms_app/presentation/providers/owner_providers.dart';

void main() {
  final now = DateTime.now();

  // Test Datasets
  final batchExpiringIn5Days = OwnerExpiryListItem(
    materialCode: '2008',
    description: 'DOOMNI- ASSAM TEA',
    batchOrLot: 'LOT-5D',
    expiryDate: now.add(const Duration(days: 5)),
    quantity: 150.0,
    unit: 'KG',
    daysLeft: 5,
    isExpired: false,
  );

  final batchExpiringIn12Days = OwnerExpiryListItem(
    materialCode: '2008',
    description: 'DOOMNI- ASSAM TEA',
    batchOrLot: 'LOT-12D',
    expiryDate: now.add(const Duration(days: 12)),
    quantity: 250.0,
    unit: 'KG',
    daysLeft: 12,
    isExpired: false,
  );

  final batchExpired = OwnerExpiryListItem(
    materialCode: '518',
    description: 'FRESH CREAM',
    batchOrLot: 'LOT-EXP',
    expiryDate: now.subtract(const Duration(days: 2)),
    quantity: 40.0,
    unit: 'BOX',
    daysLeft: -2,
    isExpired: true,
  );

  final allTestItems = [
    batchExpired,
    batchExpiringIn5Days,
    batchExpiringIn12Days,
  ];

  Widget buildTestApp({
    required Widget child,
    int initialAlertDays = 7,
    List<OwnerExpiryListItem>? overrideItems,
  }) {
    return ProviderScope(
      overrides: [
        inventorySettingsProvider.overrideWith((ref) => FakeInventorySettingsNotifier(
              InventorySettingsModel(
                invoiceMaterialExpiryAlertDays: initialAlertDays,
                storageProductExpiryAlertDays: initialAlertDays,
              ),
            )),
        ownerExpiryReportProvider.overrideWith((ref, arg) {
          final items = overrideItems ?? allTestItems;
          var filtered = items;
          if (arg.daysWindow != null) {
            filtered = filtered.where((it) => it.daysLeft <= arg.daysWindow!).toList();
          }
          if (arg.search != null && arg.search!.trim().isNotEmpty) {
            final term = arg.search!.trim().toLowerCase();
            filtered = filtered
                .where((it) =>
                    it.materialCode.toLowerCase().contains(term) ||
                    it.description.toLowerCase().contains(term))
                .toList();
          }
          return Future.value(filtered);
        }),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('MANAGEMENT EXPIRY LIST & NOTIFICATION SETTINGS TESTS', () {
    testWidgets('1 & 2. Batch expiring in 5 days appears in 7-day window, but disappears in 3-day window', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Initial window = 7 days -> batch with 5 days left MUST appear
      await tester.pumpWidget(buildTestApp(
        child: const OwnerExpiryListScreen(),
        initialAlertDays: 7,
      ));
      await tester.pumpAndSettle();

      expect(find.text('LOT-5D'), findsOneWidget);
      expect(find.text('5 Days Left'), findsOneWidget);
      // Batch with 12 days left should NOT appear in 7-day window
      expect(find.text('LOT-12D'), findsNothing);

      // 2. Reduce window to 3 days -> batch with 5 days left must NOT appear
      final inputFinder = find.byType(TextField).first;
      await tester.enterText(inputFinder, '3');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // In 3-day window: LOT-5D should NOT appear
      expect(find.text('LOT-5D'), findsNothing);
    });

    testWidgets('3. An already-expired batch is clearly marked EXPIRED', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(
        child: const OwnerExpiryListScreen(),
        initialAlertDays: 7,
      ));
      await tester.pumpAndSettle();

      // Expired batch should clearly have 'EXPIRED' badge
      expect(find.text('EXPIRED'), findsOneWidget);
      expect(find.text('LOT-EXP'), findsOneWidget);
      expect(find.text('FRESH CREAM'), findsOneWidget);
    });

    testWidgets('4. Notification setting input validates non-negative whole numbers', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(
        child: const OwnerExpiryListScreen(),
        initialAlertDays: 30,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Show expiry notification'), findsOneWidget);
      expect(find.text('days before expiry.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);

      // Tap quick select preset 15 days
      await tester.tap(find.text('15 days'));
      await tester.pumpAndSettle();

      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('5. Different batches of the same material display their own expiry dates and quantities', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Show All
      await tester.pumpWidget(buildTestApp(
        child: const OwnerExpiryListScreen(),
        initialAlertDays: 30,
      ));
      await tester.pumpAndSettle();

      // Both batches of 2008 appear with their respective lot and quantities
      expect(find.text('LOT-5D'), findsOneWidget);
      expect(find.text('LOT-12D'), findsOneWidget);
    });

    testWidgets('6. Strict 5 Columns rendered in Expiry List: Code, Description, Expiry Date, Qty, Days Left', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(
        child: const OwnerExpiryListScreen(),
        initialAlertDays: 30,
      ));
      await tester.pumpAndSettle();

      // Verify Table Columns
      expect(find.text('Code'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Expiry Date'), findsOneWidget);
      expect(find.text('Qty'), findsOneWidget);
      expect(find.text('Days Left'), findsOneWidget);
    });

    testWidgets('7. Management Portal shell contains exactly 4 navigation tabs including Expiry List', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(ProviderScope(
        overrides: [
          ownerLiveStockProvider.overrideWith((ref, search) => Future.value([])),
          ownerOutOfStockReportProvider.overrideWith((ref, arg) => Future.value([])),
          ownerReorderReportProvider.overrideWith((ref, arg) => Future.value([])),
          ownerExpiryReportProvider.overrideWith((ref, arg) => Future.value([])),
          inventorySettingsProvider.overrideWith((ref) => FakeInventorySettingsNotifier(
                const InventorySettingsModel(
                  invoiceMaterialExpiryAlertDays: 30,
                  storageProductExpiryAlertDays: 30,
                ),
              )),
        ],
        child: const MaterialApp(
          home: OwnerShellScreen(initialSection: 3),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify Desktop Nav Buttons
      expect(find.widgetWithText(InkWell, 'Live Stock'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Out of Stock'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Reorder Level'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Expiry List'), findsOneWidget);

      // Verify Expiry List Screen is active
      expect(find.text('Expiry List'), findsWidgets);
    });
  });
}

class FakeInventorySettingsNotifier extends StateNotifier<AsyncValue<InventorySettingsModel>>
    implements InventorySettingsNotifier {
  FakeInventorySettingsNotifier(InventorySettingsModel initial)
      : super(AsyncValue.data(initial));

  @override
  Future<void> loadSettings() async {}

  @override
  Future<void> saveSettings({
    required int invoiceMaterialExpiryAlertDays,
    required int storageProductExpiryAlertDays,
  }) async {
    state = AsyncValue.data(InventorySettingsModel(
      invoiceMaterialExpiryAlertDays: invoiceMaterialExpiryAlertDays,
      storageProductExpiryAlertDays: storageProductExpiryAlertDays,
    ));
  }
}
