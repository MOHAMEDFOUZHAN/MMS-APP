import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/security/security_finding_model.dart';
import 'package:mms_app/data/models/owner_dashboard_model.dart';
import 'package:mms_app/presentation/owner/owner_activity_screen.dart';
import 'package:mms_app/presentation/owner/owner_alerts_screen.dart';
import 'package:mms_app/presentation/owner/owner_analytics_screen.dart';
import 'package:mms_app/presentation/owner/owner_dashboard_screen.dart';
import 'package:mms_app/presentation/owner/owner_reports_hub_screen.dart';
import 'package:mms_app/presentation/owner/owner_settings_screen.dart';
import 'package:mms_app/presentation/owner/owner_shell_screen.dart';
import 'package:mms_app/presentation/owner/reports/owner_expiring_report_screen.dart';
import 'package:mms_app/presentation/providers/owner_providers.dart';
import 'package:mms_app/presentation/providers/security_providers.dart';
import 'package:mms_app/presentation/security/security_center_screen.dart';
import 'package:mms_app/data/repositories/owner_repository.dart';
import 'package:mms_app/data/models/inventory_settings_model.dart';
import 'package:mms_app/data/repositories/inventory_settings_repository.dart';
import 'package:mms_app/presentation/providers/inventory_settings_provider.dart';

OwnerDashboardSummary _createMockSummary() {
  final sampleJson = {
    'timestamp': '2026-10-05T14:30:00Z',
    'kpi': {
      'total_materials': 151,
      'active_storage_products': 42,
      'total_storage_stock': 1245678.50,
      'total_purchases_val': 450000.0,
      'total_purchases_cnt': 35,
      'total_dispatched_qty': 8200.0,
      'total_dispatched_cnt': 64,
      'total_transferred_net': 3400.0,
      'out_of_stock_cnt': 5,
      'low_stock_cnt': 12,
      'expiring_soon_cnt': 8,
      'pending_invoices_cnt': 3,
      'total_vendors_cnt': 18,
      'active_batches_cnt': 94,
    },
    'today': {
      'today_purchases_val': 35000.0,
      'today_purchases_cnt': 2,
      'today_stock_in_qty': 1200.0,
      'today_dispatch_qty': 950.0,
      'today_transfer_out': 400.0,
      'today_transfer_ret': 50.0,
      'today_closing_stock': 24000.0,
    },
    'health': {
      'healthy_stock': 134,
      'low_stock': 12,
      'out_of_stock': 5,
      'expiring_soon': 8,
      'expired': 1,
      'active_batches': 94,
      'depleted_batches': 15,
    },
    'storage': {
      'total_storage_stock': 1245678.50,
      'active_batches': 94,
      'depleted_batches': 15,
      'today_stock_in': 1200.0,
      'today_dispatch': 950.0,
      'top_products': [
        {'product_name': 'Tea Powder 500g', 'available_quantity': 4500.0, 'unit': 'pkt'},
      ],
      'lowest_products': [],
      'expiring_batches': [],
      'distribution': [
        {'department': 'Warehouse A', 'total_quantity': 5000.0, 'batch_count': 12},
      ],
    },
    'materials': {
      'total_materials': 151,
      'total_quantity': 45000.0,
      'low_stock': 12,
      'out_of_stock': 5,
      'today_purchases': 35000.0,
      'today_transfer_out': 400.0,
      'today_returns': 50.0,
      'highest_stock': [],
      'distribution': [
        {'category': 'Packaging Material', 'total_quantity': 12000.0, 'item_count': 15},
      ],
    },
    'invoices': {
      'today_invoices_cnt': 2,
      'today_invoices_val': 35000.0,
      'week_invoices_cnt': 8,
      'week_invoices_val': 120000.0,
      'month_invoices_cnt': 35,
      'month_invoices_val': 450000.0,
      'total_purchase_val': 450000.0,
      'pending_invoices_cnt': 3,
      'pending_invoices_val': 25000.0,
      'recent_vendors': [],
      'recent_purchases': [],
      'purchase_trend': [
        {'date': '2026-10-01', 'value': 12000.0},
        {'date': '2026-10-02', 'value': 25000.0},
      ],
    },
    'dispatches': {
      'today_dispatch_cnt': 4,
      'today_dispatch_qty': 950.0,
      'week_dispatch_cnt': 22,
      'week_dispatch_qty': 3500.0,
      'month_dispatch_cnt': 64,
      'month_dispatch_qty': 8200.0,
      'total_dispatch_qty': 8200.0,
      'top_dispatched_products': [],
      'top_departments': [],
      'recent_dispatches': [],
      'returns': 15.0,
      'dispatch_trend': [
        {'date': '2026-10-01', 'quantity': 150.0},
        {'date': '2026-10-02', 'quantity': 300.0},
      ],
    },
    'transfers': {
      'today_transfers_out': 400.0,
      'today_transfers_ret': 50.0,
      'total_transfers_out': 4200.0,
      'total_transfers_ret': 800.0,
      'net_consumed': 3400.0,
      'top_departments': [],
      'most_transferred_materials': [],
      'transfer_trend': [
        {'date': '2026-10-01', 'outward': 100.0, 'returns': 10.0},
      ],
    },
    'top_lists': {
      'reorder_risk': [
        {
          'material_code': 'MAT-001',
          'description': 'Corrugated Outer Carton 10kg',
          'quantity': 20.0,
          'reorder_level': 100.0,
          'unit': 'pcs',
        },
      ],
      'highest_storage': [],
      'highest_materials': [],
      'top_dispatched': [],
    },
    'expiry_monitor': {
      'invoice_materials': [
        {
          'material_code': 'ING-099',
          'description': 'Flavoring Essence Pure Extract',
          'days_remaining': 15,
          'quantity': 50.0,
          'unit': 'L',
          'category': 'Ingredients',
          'expiry_date': '2026-10-20',
        },
      ],
      'storage_products': [
        {
          'batch_no': 'B-2026-0901',
          'material_code': 'FG-01',
          'description': 'Export Tea 250g Jar',
          'days_remaining': 18,
          'available_quantity': 400.0,
          'uom': 'jars',
          'expiry_date': '2026-10-23',
        },
      ],
      'invoice_threshold_days': 30,
      'storage_threshold_days': 30,
    },
    'recent_activity': [
      {
        'id': 101,
        'user_email': 'owner@benchmarkmms.com',
        'operation': 'DISPATCH_CREATE',
        'module': 'dispatches',
        'record_id': 'DISP-892',
        'details': {'qty': 150},
        'created_at': '2026-10-05T10:45:00Z',
        'time_ampm': '10:45 AM',
        'date_str': '2026-10-05',
      }
    ],
    'alerts': [
      {
        'severity': 'CRITICAL',
        'title': 'Critical Stock Depletion in Raw Ingredients',
        'message': 'Material MAT-001 has fallen below minimum safety threshold.',
        'reference_type': 'material',
        'reference_id': 'MAT-001',
      },
      {
        'severity': 'WARNING',
        'title': 'Storage Finished Batch Expiring Soon',
        'message': 'Batch B-2026-0901 approaches shelf-life expiration.',
        'reference_type': 'batch',
        'reference_id': 'B-2026-0901',
      },
    ],
  };

  return OwnerDashboardSummary.fromJson(sampleJson);
}

List<OwnerActivityItem> _createMockLogs() {
  return [
    OwnerActivityItem(
      id: 1,
      userEmail: 'owner@benchmarkmms.com',
      operation: 'DISPATCH_CONFIRM',
      module: 'dispatches',
      recordId: 'REC-001',
      details: {'dest': 'Depot 1', 'units': 500},
      createdAt: DateTime.now(),
      dateStr: '05/10/2026',
      timeAmPm: '04:30 PM',
    ),
  ];
}

class _MockOwnerRepository extends OwnerRepository {
  @override
  Future<Map<String, dynamic>> verifyOwnerAccess() async {
    return {'authorized': true, 'role': 'OWNER'};
  }
}

class _MockInventorySettingsRepository extends InventorySettingsRepository {
  @override
  Future<InventorySettingsModel> fetchSettings() async {
    return const InventorySettingsModel(
      invoiceMaterialExpiryAlertDays: 30,
      storageProductExpiryAlertDays: 30,
    );
  }
}

Widget _wrapWithOverrides(Widget child, {OwnerDashboardSummary? summary}) {
  final sum = summary ?? _createMockSummary();
  return ProviderScope(
    overrides: [
      ownerRepositoryProvider.overrideWithValue(_MockOwnerRepository()),
      inventorySettingsRepositoryProvider.overrideWithValue(_MockInventorySettingsRepository()),
      ownerDashboardSummaryProvider.overrideWith((ref) => Future.value(sum)),
      ownerAuditLogsProvider.overrideWith((ref) => Future.value(_createMockLogs())),
      securityAuditStateProvider.overrideWith((ref) {
        final notifier = SecurityAuditNotifier(ref);
        notifier.state = SecurityAuditState(
          currentReport: SecurityAuditReport(
            id: 'AUD-001',
            timestamp: DateTime.now(),
            securityScore: 88,
            status: SecurityAuditStatus.secure,
            totalChecks: 23,
            findings: [],
            summary: 'System security audit passed. RLS and configurations healthy.',
          ),
        );
        return notifier;
      }),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
}

void main() {
  const phoneSizes = <String, Size>{
    '320x568 (Small Phone)': Size(320, 568),
    '360x640 (Compact Android)': Size(360, 640),
    '360x800 (Normal Android)': Size(360, 800),
    '375x812 (iPhone X/12 Mini)': Size(375, 812),
    '390x844 (Standard Phone)': Size(390, 844),
    '393x873 (Pixel 7/8)': Size(393, 873),
    '412x915 (Pixel Pro)': Size(412, 915),
    '430x932 (Large Phone)': Size(430, 932),
  };

  const landscapeSizes = <String, Size>{
    '800x360 (Phone Landscape)': Size(800, 360),
    '844x390 (Standard Landscape)': Size(844, 390),
    '932x430 (Large Phone Landscape)': Size(932, 430),
  };

  const tabletSizes = <String, Size>{
    '600x960 (Small Tablet Portrait)': Size(600, 960),
    '960x600 (Small Tablet Landscape)': Size(960, 600),
    '800x1280 (8-inch Tablet Portrait)': Size(800, 1280),
    '1280x800 (10-inch Tablet Landscape)': Size(1280, 800),
  };

  group('A. Owner Dashboard Responsive Breakpoints Tests', () {
    for (final entry in phoneSizes.entries) {
      testWidgets('Renders cleanly on ${entry.key} without overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapWithOverrides(const OwnerDashboardScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('TOP EXECUTIVE KEY PERFORMANCE INDICATORS'), findsOneWidget);
        expect(find.text("TODAY'S BUSINESS SNAPSHOT"), findsOneWidget);
        expect(find.text('INVENTORY HEALTH & STATUS'), findsOneWidget);
      });
    }

    for (final entry in landscapeSizes.entries) {
      testWidgets('Renders and scrolls in landscape on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapWithOverrides(const OwnerDashboardScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('TOP EXECUTIVE KEY PERFORMANCE INDICATORS'), findsOneWidget);
      });
    }

    for (final entry in tabletSizes.entries) {
      testWidgets('Renders with multi-column layout on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapWithOverrides(const OwnerDashboardScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('TOP EXECUTIVE KEY PERFORMANCE INDICATORS'), findsOneWidget);
      });
    }
  });

  group('B. Owner Analytics Responsive Tests', () {
    for (final entry in [phoneSizes['320x568 (Small Phone)']!, phoneSizes['360x800 (Normal Android)']!, tabletSizes['800x1280 (8-inch Tablet Portrait)']!]) {
      testWidgets('Analytics screen renders trend charts cleanly at size $entry', (tester) async {
        tester.view.physicalSize = entry;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapWithOverrides(const OwnerAnalyticsScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('DISPATCH TREND'), findsOneWidget);
        expect(find.text('PURCHASE INWARD TREND'), findsOneWidget);
      });
    }
  });

  group('C. Owner Reports Hub Responsive Tests', () {
    for (final entry in [phoneSizes['320x568 (Small Phone)']!, phoneSizes['360x800 (Normal Android)']!, tabletSizes['600x960 (Small Tablet Portrait)']!, Size(1024, 768)]) {
      testWidgets('Reports Hub renders grid cleanly at size $entry', (tester) async {
        tester.view.physicalSize = entry;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapWithOverrides(const OwnerReportsHubScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Executive Reports Repository'), findsOneWidget);
        expect(find.text('Material Directory / Wall Chart'), findsOneWidget);
        expect(find.text('Daily Stock Ledger'), findsOneWidget);
      });
    }
  });

  group('D. Owner Expiring Report Responsive Tests', () {
    for (final entry in [phoneSizes['320x568 (Small Phone)']!, phoneSizes['390x844 (Standard Phone)']!]) {
      testWidgets('Expiring Report renders scrollable TabBar at size $entry', (tester) async {
        tester.view.physicalSize = entry;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapWithOverrides(const OwnerExpiringReportScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Expiring Items Monitor'), findsOneWidget);
        expect(find.text('SOURCE: INVOICE MATERIAL'), findsOneWidget);
      });
    }
  });

  group('E. Owner Activity Responsive Tests', () {
    for (final entry in [phoneSizes['320x568 (Small Phone)']!, phoneSizes['360x800 (Normal Android)']!]) {
      testWidgets('Activity screen renders responsive search & filter at size $entry', (tester) async {
        tester.view.physicalSize = entry;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapWithOverrides(const OwnerActivityScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Executive Activity & Audit Trail'), findsOneWidget);
      });
    }
  });

  group('F. Owner Alerts Responsive Tests', () {
    for (final entry in [phoneSizes['320x568 (Small Phone)']!, phoneSizes['360x800 (Normal Android)']!]) {
      testWidgets('Alerts screen renders horizontal severity chips and wrapped cards at size $entry', (tester) async {
        tester.view.physicalSize = entry;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapWithOverrides(const OwnerAlertsScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Executive Alert Center'), findsOneWidget);
        expect(find.text('All Alerts'), findsOneWidget);
        expect(find.text('Critical Stock Depletion in Raw Ingredients'), findsOneWidget);
      });
    }
  });

  group('G. Security Center Responsive Tests', () {
    for (final entry in [phoneSizes['320x568 (Small Phone)']!, phoneSizes['360x800 (Normal Android)']!, tabletSizes['800x1280 (8-inch Tablet Portrait)']!]) {
      testWidgets('Security Center stacks buttons on mobile and renders cleanly at size $entry', (tester) async {
        tester.view.physicalSize = entry;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapWithOverrides(const SecurityCenterScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('SECURITY CENTER'), findsOneWidget);
        expect(find.text('RUN SECURITY AUDIT'), findsOneWidget);
        expect(find.text('VIEW SECURITY HISTORY'), findsOneWidget);
      });
    }
  });

  group('H. Owner Settings Responsive Tests', () {
    for (final entry in [phoneSizes['320x568 (Small Phone)']!, phoneSizes['360x800 (Normal Android)']!]) {
      testWidgets('Settings screen renders full-width touch-friendly button at size $entry', (tester) async {
        tester.view.physicalSize = entry;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(_wrapWithOverrides(const OwnerSettingsScreen()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Management Settings & Configurations'), findsOneWidget);
        expect(find.text('Save Thresholds'), findsOneWidget);
      });
    }
  });

  group('I. Owner Shell Responsive Navigation Tests', () {
    testWidgets('Shows 5-item mobile bottom navigation bar on phone width 360', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithOverrides(const OwnerShellScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Analytics'), findsWidgets);
      expect(find.text('Reports'), findsWidgets);
      expect(find.text('Alerts'), findsWidgets);
      expect(find.text('More'), findsOneWidget);

      // Tap 'More' to open the modal bottom sheet
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      expect(find.text('Activity & Audit Trail'), findsOneWidget);
      expect(find.text('Security Center'), findsOneWidget);
      expect(find.text('Owner Settings'), findsOneWidget);
      expect(find.text('Executive Profile & Account'), findsOneWidget);
      expect(find.text('End Session (Sign Out)'), findsOneWidget);
    });

    testWidgets('Shows wide NavigationRail on desktop/tablet width 1024', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrapWithOverrides(const OwnerShellScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });
  });
}
