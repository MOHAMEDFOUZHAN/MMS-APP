import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/inventory_settings_model.dart';
import 'package:mms_app/data/models/owner_reporting_models.dart';
import 'package:mms_app/presentation/auth/login_screen.dart';
import 'package:mms_app/presentation/owner/owner_login_screen.dart';
import 'package:mms_app/presentation/owner/owner_shell_screen.dart';
import 'package:mms_app/presentation/owner/sections/owner_live_stock_screen.dart';
import 'package:mms_app/presentation/owner/sections/owner_out_of_stock_screen.dart';
import 'package:mms_app/presentation/owner/sections/owner_reorder_screen.dart';
import 'package:mms_app/presentation/providers/inventory_settings_provider.dart';
import 'package:mms_app/presentation/providers/owner_providers.dart';

void main() {
  final sampleLiveStock = [
    OwnerAdminLiveStockItem(
      materialCode: '2008',
      description: 'DOOMNI- ASSAM TEA',
      category: 'TEA',
      unit: 'KG',
      adminStock: 500.0,
      teaStock: 300.0,
      chocolateStock: 0.0,
      otherStock: 0.0,
      totalTransferred: 300.0,
      totalSystemStock: 800.0,
    ),
    OwnerAdminLiveStockItem(
      materialCode: '518',
      description: 'FRESH CREAM',
      category: 'CHOCOLATE',
      unit: 'BOX',
      adminStock: 0.0,
      teaStock: 0.0,
      chocolateStock: 0.0,
      otherStock: 0.0,
      totalTransferred: 0.0,
      totalSystemStock: 0.0,
    ),
    OwnerAdminLiveStockItem(
      materialCode: '1001',
      description: 'COCOA POWDER 25KG',
      category: 'CHOCOLATE',
      unit: 'BAG',
      adminStock: 10.0,
      teaStock: 0.0,
      chocolateStock: 5.0,
      otherStock: 0.0,
      totalTransferred: 5.0,
      totalSystemStock: 15.0,
    ),
  ];

  final sampleOutOfStock = [
    OwnerOutOfStockItem(
      materialCode: '518',
      description: 'FRESH CREAM',
      category: 'CHOCOLATE',
      unit: 'BOX',
      location: 'Business-Wide',
      locationStock: 0.0,
      adminStock: 0.0,
      teaStock: 0.0,
      chocolateStock: 0.0,
      totalBusinessStock: 0.0,
      reorderLevel: 112.0,
      stockStatus: 'OUT_OF_STOCK_BUSINESS',
      statusMessage: 'Create Purchase Order from Supplier',
    ),
  ];

  final sampleReorder = [
    OwnerReorderItem(
      materialCode: '518',
      description: 'FRESH CREAM',
      category: 'CHOCOLATE',
      unit: 'BOX',
      location: 'Business-Wide',
      availableStock: 0.0,
      totalBusinessStock: 0.0,
      adminStock: 0.0,
      teaStock: 0.0,
      chocolateStock: 0.0,
      reorderLevel: 112.0,
      status: 'OUT_OF_STOCK',
      statusMessage: 'Reorder required',
    ),
    OwnerReorderItem(
      materialCode: '2008',
      description: 'DOOMNI- ASSAM TEA',
      category: 'TEA',
      unit: 'KG',
      location: 'Business-Wide',
      availableStock: 800.0,
      totalBusinessStock: 800.0,
      adminStock: 500.0,
      teaStock: 300.0,
      chocolateStock: 0.0,
      reorderLevel: 100.0, // Healthy (800 > 100)
      status: 'NORMAL',
      statusMessage: 'Healthy',
    ),
    OwnerReorderItem(
      materialCode: '9999',
      description: 'UNCONFIGURED MATERIAL',
      category: 'GENERAL',
      unit: 'PCS',
      location: 'Business-Wide',
      availableStock: 50.0,
      totalBusinessStock: 50.0,
      adminStock: 50.0,
      teaStock: 0.0,
      chocolateStock: 0.0,
      reorderLevel: 0.0, // Not configured
      status: 'NOT_CONFIGURED',
      statusMessage: 'Needs configuration',
    ),
  ];

  Widget buildTestApp({required Widget child}) {
    return ProviderScope(
      overrides: [
        ownerLiveStockProvider.overrideWith((ref, search) => Future.value(sampleLiveStock)),
        ownerOutOfStockReportProvider.overrideWith((ref, arg) => Future.value(sampleOutOfStock)),
        ownerReorderReportProvider.overrideWith((ref, arg) => Future.value(sampleReorder)),
        ownerExpiryReportProvider.overrideWith((ref, arg) => Future.value([])),
        inventorySettingsProvider.overrideWith((ref) => FakeTestInventorySettingsNotifier(
              const InventorySettingsModel(
                invoiceMaterialExpiryAlertDays: 30,
                storageProductExpiryAlertDays: 30,
              ),
            )),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('SIMPLIFIED MANAGEMENT LOGIN PORTAL VERIFICATION', () {
    testWidgets('1. Page One — Live Stock renders unified materials and required columns', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const OwnerLiveStockScreen()));
      await tester.pumpAndSettle();

      // Verify Page Title & Subtitle
      expect(find.text('Live Stock'), findsOneWidget);
      expect(find.textContaining('All materials across Admin, Tea, Chocolate'), findsOneWidget);

      // Verify Required Table Headers: CODE, DESCRIPTION, CURRENT STOCK, UNIT
      expect(find.text('CODE'), findsOneWidget);
      expect(find.text('DESCRIPTION'), findsOneWidget);
      expect(find.text('CURRENT STOCK'), findsOneWidget);
      expect(find.text('UNIT'), findsOneWidget);

      // Verify Material Data rendered
      expect(find.text('2008'), findsOneWidget);
      expect(find.text('DOOMNI- ASSAM TEA'), findsOneWidget);
      expect(find.text('KG'), findsWidgets);

      // Verify Total Business Stock clearly distinguished with location breakdown
      expect(find.text('800'), findsOneWidget);
      expect(find.textContaining('Admin: 500 • Tea: 300'), findsOneWidget);

      // Verify Search box exists
      expect(find.byType(TextField), findsOneWidget);

      // Test Search box filtering
      await tester.enterText(find.byType(TextField), 'DOOMNI');
      await tester.pumpAndSettle();
      expect(find.text('DOOMNI- ASSAM TEA'), findsOneWidget);
      expect(find.text('FRESH CREAM'), findsNothing);
    });

    testWidgets('2. Page Two — Out of Stock displays strictly Code, Description, Qty (0)', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const OwnerOutOfStockScreen()));
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Out of Stock'), findsOneWidget);

      // Verify Headers: strictly CODE, DESCRIPTION, QTY
      expect(find.text('CODE'), findsOneWidget);
      expect(find.text('DESCRIPTION'), findsOneWidget);
      expect(find.text('QTY'), findsOneWidget);

      // Verify only depleted materials are shown
      expect(find.text('518'), findsOneWidget);
      expect(find.text('FRESH CREAM'), findsOneWidget);
      expect(find.text('0 BOX'), findsOneWidget);

      // Verify items with positive stock are NOT displayed
      expect(find.text('DOOMNI- ASSAM TEA'), findsNothing);
      expect(find.text('COCOA POWDER 25KG'), findsNothing);
    });

    testWidgets('3. Page Three — Reorder Level displays Code, Description, Current Qty, Reorder Level & Edit option', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const OwnerReorderScreen()));
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Reorder Level'), findsOneWidget);

      // Verify Headers: CODE, DESCRIPTION, CURRENT QTY, REORDER LEVEL
      expect(find.text('CODE'), findsOneWidget);
      expect(find.text('DESCRIPTION'), findsOneWidget);
      expect(find.text('CURRENT QTY'), findsOneWidget);
      expect(find.text('REORDER LEVEL'), findsOneWidget);

      // In Default "At / Below Reorder" mode, only items at or below threshold are shown
      expect(find.text('518'), findsOneWidget);
      expect(find.text('FRESH CREAM'), findsOneWidget);
      expect(find.text('0 BOX'), findsOneWidget);
      expect(find.text('112 BOX'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      // Healthy item (stock 800 > reorder 100) must NOT be shown in default "At / Below Reorder" list
      expect(find.text('DOOMNI- ASSAM TEA'), findsNothing);

      // Switch to "Needs Configuration"
      await tester.tap(find.text('Needs Configuration'));
      await tester.pumpAndSettle();

      expect(find.text('9999'), findsOneWidget);
      expect(find.text('UNCONFIGURED MATERIAL'), findsOneWidget);
      expect(find.text('Not Set'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      // Tapping "Edit" opens the Edit Reorder Level dialog
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Reorder Level'), findsOneWidget);
      expect(find.textContaining('Current Stock:'), findsOneWidget);
      expect(find.text('Save Reorder Level'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Reorder Level'), findsNothing);
    });

    testWidgets('4. Navigation Shell has exactly the 4 main pages without department menus', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const OwnerShellScreen()));
      await tester.pumpAndSettle();

      // Top Bar Branding
      expect(find.text('Benchmark MMS'), findsOneWidget);
      expect(find.text('Management Portal'), findsOneWidget);

      // Exactly 4 Navigation Buttons
      expect(find.widgetWithText(InkWell, 'Live Stock'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Out of Stock'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Reorder Level'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Expiry List'), findsOneWidget);

      // Separate operational department menus must NOT exist in the Management Portal
      expect(find.text('Admin Section'), findsNothing);
      expect(find.text('Tea Section'), findsNothing);
      expect(find.text('Chocolate Section'), findsNothing);
      expect(find.text('Dashboard'), findsNothing);

      // Switching pages
      await tester.tap(find.widgetWithText(InkWell, 'Out of Stock'));
      await tester.pumpAndSettle();
      expect(find.byType(OwnerOutOfStockScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, 'Reorder Level'));
      await tester.pumpAndSettle();
      expect(find.byType(OwnerReorderScreen), findsOneWidget);
    });

    testWidgets('5a. Mobile Phone Layout — OwnerLiveStockScreen alone', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const OwnerLiveStockScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('5b. Mobile Phone Layout — OwnerOutOfStockScreen alone', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const OwnerOutOfStockScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('5c. Mobile Phone Layout — OwnerReorderScreen alone', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const OwnerReorderScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('5d. Mobile Phone Layout — OwnerShellScreen', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const OwnerShellScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6a. Management Login branding replaces all visible Owner labels', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const OwnerLoginScreen()));
      await tester.pumpAndSettle();

      // Ensure "MANAGEMENT ACCESS" and "MANAGEMENT USERNAME / ID" are visible
      expect(find.text('MANAGEMENT ACCESS'), findsOneWidget);
      expect(find.text('MANAGEMENT USERNAME / ID'), findsOneWidget);
      expect(find.text('Authorized management access only.'), findsOneWidget);

      // Ensure no visible "Owner" or "OWNER" text remains
      expect(find.text('Owner Login'), findsNothing);
      expect(find.text('OWNER ACCESS'), findsNothing);
      expect(find.text('OWNER IDENTIFIER'), findsNothing);
      expect(find.text('Authorized owner access only.'), findsNothing);
    });

    testWidgets('6b. Management Portal shell displays Management badge and branding', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(child: const OwnerShellScreen()));
      await tester.pumpAndSettle();

      // Top bar title is Management Portal
      expect(find.text('Management Portal'), findsOneWidget);
      // Mobile user badge says Management, not Owner
      expect(find.text('Management'), findsOneWidget);
      expect(find.text('Owner'), findsNothing);
    });
  });
}

class FakeTestInventorySettingsNotifier extends StateNotifier<AsyncValue<InventorySettingsModel>>
    implements InventorySettingsNotifier {
  FakeTestInventorySettingsNotifier(InventorySettingsModel initial)
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

