import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mms_app/core/services/connection_service.dart';
import 'package:mms_app/data/models/dashboard_summary_model.dart';
import 'package:mms_app/data/models/notification_model.dart';
import 'package:mms_app/presentation/adjustments/stock_adjustment_screen.dart';
import 'package:mms_app/presentation/dashboard/dashboard_screen.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';
import 'package:mms_app/presentation/shell/home_shell.dart';
import 'package:mms_app/shared/widgets/connection_status_indicator.dart';
import 'package:mms_app/shared/widgets/notification_bell_icon.dart';
import 'package:mms_app/shared/widgets/notifications_sheet.dart';

class MockConnectionService extends StateNotifier<ConnectionStatus> implements ConnectionService {
  MockConnectionService([ConnectionStatus? status])
      : super(status ?? ConnectionStatus(state: AppConnectionState.online, lastChecked: DateTime.now()));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Stock Adjustment Authorization & Startup Popup Tests', () {
    testWidgets('StockAdjustmentScreen does NOT show automatic PIN popup on initialization', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StockAdjustmentScreen(isEmbedded: true),
          ),
        ),
      );

      // Pump a frame to ensure any post frame callbacks would have run
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Must find the protected lock screen, NOT a PIN dialog
      expect(find.text('Authorization Required'), findsOneWidget);
      expect(find.text('Enter PIN'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      // Verify no dialog / AlertDialog / PinAuthDialog is visible
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Stock Adjustment Authorization'), findsNothing);
      expect(find.text('Enter Supervisor PIN to access secure inventory adjustments.'), findsNothing);
    });

    testWidgets('StockAdjustmentScreen standalone displays protected lock state with action button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StockAdjustmentScreen(isEmbedded: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Authorization Required'), findsOneWidget);
      expect(find.text('Enter PIN'), findsOneWidget);
    });
  });

  group('2. Notification Badge & Rules Tests', () {
    testWidgets('Notification badge is hidden when count is 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsCountProvider.overrideWith((ref) => Future.value(0)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationBellIcon(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('Notification badge shows exact number when 1 <= count <= 99', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsCountProvider.overrideWith((ref) => Future.value(5)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationBellIcon(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('5'), findsOneWidget);
      expect(find.text('99+'), findsNothing);
    });

    testWidgets('Notification badge shows 99+ when count exceeds 99 and does not blow up layout', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsCountProvider.overrideWith((ref) => Future.value(150)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationBellIcon(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('150'), findsNothing);
    });
  });

  group('3. Connection Status Indicator Mode Tests', () {
    testWidgets('ConnectionStatusIndicator renders compact glowing dot mode cleanly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConnectionStatusIndicator(compact: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(ConnectionStatusIndicator), findsOneWidget);
      // In compact mode with 0 pending, 'Online' text is in Tooltip message, not displayed in a wide text widget
      expect(find.text('Online'), findsNothing);
    });

    testWidgets('ConnectionStatusIndicator renders full pill mode with label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ConnectionStatusIndicator(compact: false),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Online'), findsOneWidget);
    });
  });

  group('4. Multi-Screen Layout Responsiveness & Overflow Prevention Tests', () {
    final testSizes = [
      const Size(360, 800),  // Small phone portrait
      const Size(390, 844),  // iPhone 12/13/14
      const Size(412, 915),  // Pixel 7 / Samsung A series phone
      const Size(600, 1024), // Small 7-inch tablet portrait
      const Size(800, 1280), // Samsung Tab A9+ / A11+ portrait
      const Size(1024, 768), // Tablet landscape
      const Size(1280, 800), // Large tablet landscape / Desktop
    ];

    for (final size in testSizes) {
      testWidgets('Dashboard renders with 0 RenderFlex overflow on ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockSummary = DashboardSummaryModel(
          totalMaterials: 142,
          totalInventoryValue: 1250450.75,
          reorderItems: 8,
          expiringSoon: 3,
          outOfStock: 2,
          todayPurchaseValue: 45000.0,
          categoryBreakdown: [
            CategoryStock(category: 'RAW', totalQuantity: 80, itemCount: 10),
            CategoryStock(category: 'PACKAGING', totalQuantity: 40, itemCount: 8),
            CategoryStock(category: 'CONSUMABLE', totalQuantity: 22, itemCount: 4),
          ],
          topMaterials: [
            TopMaterialItem(materialCode: 'RM-001', description: 'Almond Oil Pure', quantity: 450.0, unit: 'kg'),
            TopMaterialItem(materialCode: 'RM-002', description: 'Lavender Essence', quantity: 210.0, unit: 'L'),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardSummaryProvider.overrideWith((ref) => Future.value(mockSummary)),
              unreadNotificationsCountProvider.overrideWith((ref) => Future.value(4)),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: DashboardScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify key widgets are rendered and no layout exception was thrown
        expect(find.text('Key Performance Indicators'), findsOneWidget);
        expect(find.text('Total Materials'), findsOneWidget);
        expect(find.text('Inventory Value'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final size in testSizes) {
      testWidgets('HomeShell renders with 0 RenderFlex overflow on ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockSummary = DashboardSummaryModel(
          totalMaterials: 50,
          totalInventoryValue: 100000.0,
          reorderItems: 1,
          expiringSoon: 0,
          outOfStock: 0,
          todayPurchaseValue: 0.0,
          categoryBreakdown: [],
          topMaterials: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardSummaryProvider.overrideWith((ref) => Future.value(mockSummary)),
              unreadNotificationsCountProvider.overrideWith((ref) => Future.value(12)),
              connectionServiceProvider.overrideWith((ref) => MockConnectionService()),
            ],
            child: const MaterialApp(
              home: HomeShell(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Crucial: absolutely no RenderFlex overflow!
        expect(tester.takeException(), isNull);

        // Crucial: no automatic Stock Adjustment popup opened on HomeShell launch
        expect(find.text('Stock Adjustment Authorization'), findsNothing);
      });
    }
  });

  group('5. Notifications Sheet & Dialog Mode Tests', () {
    testWidgets('NotificationsSheet renders properly with notifications and clear filter', (tester) async {
      final mockNotifs = [
        NotificationModel(
          id: 1,
          type: 'reorder',
          title: 'Reorder Alert: RM-101',
          message: 'Current stock is 5 kg, below reorder level of 20 kg.',
          severity: 'CRITICAL',
          referenceType: 'material',
          referenceId: 'RM-101',
          isRead: false,
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: 2,
          type: 'expiring',
          title: 'Expiring Soon: BATCH-889',
          message: 'Batch expires in 12 days.',
          severity: 'WARNING',
          referenceType: 'batch',
          referenceId: 'BATCH-889',
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsListProvider.overrideWith((ref) => Future.value(mockNotifs)),
            unreadNotificationsCountProvider.overrideWith((ref) => Future.value(1)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationsSheet(isDialog: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications & Alerts'), findsOneWidget);
      expect(find.text('Reorder Alert: RM-101'), findsOneWidget);
      expect(find.text('Expiring Soon: BATCH-889'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
