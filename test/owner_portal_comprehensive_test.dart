import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/owner_dashboard_model.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/presentation/owner/owner_login_screen.dart';
import 'package:mms_app/presentation/owner/owner_reports_hub_screen.dart';
import 'package:mms_app/presentation/providers/owner_providers.dart';

void main() {
  group('1. Owner Profile & Permission Tests', () {
    test('Owner user has isOwner == true and read-only reporting permissions', () {
      final ownerProfile = UserProfileModel(
        id: 'owner-uuid-1',
        username: 'owner',
        fullName: 'Executive Management',
        role: 'OWNER',
        permissions: ['owner.*', 'reports.*'],
      );

      expect(ownerProfile.isOwner, isTrue);
      expect(ownerProfile.isAdmin, isFalse);
      expect(ownerProfile.hasPermission('reports.view'), isTrue);
    });

    test('Normal Operator / Staff user has isOwner == false', () {
      final staffProfile = UserProfileModel(
        id: 'staff-uuid-2',
        username: 'staff1',
        fullName: 'Factory Staff',
        role: 'STAFF',
        permissions: ['materials.view'],
      );

      expect(staffProfile.isOwner, isFalse);
      expect(staffProfile.isAdmin, isFalse);
      expect(staffProfile.hasPermission('materials.view'), isTrue);
      expect(staffProfile.hasPermission('owner.portal'), isFalse);
    });
  });

  group('2. Owner Date Filter Tests', () {
    test('Date filter ranges calculate accurately without logic errors', () {
      const allTime = OwnerDateFilter(type: OwnerDateFilterType.allTime);
      expect(allTime.range.from, isNull);
      expect(allTime.range.to, isNull);
      expect(allTime.label, 'All Time');

      const todayFilter = OwnerDateFilter(type: OwnerDateFilterType.today);
      expect(todayFilter.range.from, isNotNull);
      expect(todayFilter.range.to, isNotNull);
      expect(todayFilter.label, 'Today');

      const last7Days = OwnerDateFilter(type: OwnerDateFilterType.last7Days);
      final range7 = last7Days.range;
      expect(range7.to!.difference(range7.from!).inDays, equals(7));
      expect(last7Days.label, '7 Days');

      const last30Days = OwnerDateFilter(type: OwnerDateFilterType.last30Days);
      final range30 = last30Days.range;
      expect(range30.to!.difference(range30.from!).inDays, equals(30));
    });
  });

  group('3. Owner Dashboard Model Serialization Tests', () {
    test('OwnerDashboardSummary handles empty and full JSON robustly', () {
      final emptyJson = <String, dynamic>{};
      final summary = OwnerDashboardSummary.fromJson(emptyJson);

      expect(summary.kpi.totalMaterials, equals(0));
      expect(summary.kpi.totalStorageStock, equals(0.0));
      expect(summary.today.todayPurchasesVal, equals(0.0));
      expect(summary.health.healthyStock, equals(0));
      expect(summary.storage.topProducts, isEmpty);
      expect(summary.materials.highestStock, isEmpty);
      expect(summary.recentActivity, isEmpty);
      expect(summary.alerts, isEmpty);
    });

    test('OwnerDashboardSummary correctly parses populated server JSON', () {
      final sampleJson = {
        'timestamp': '2026-10-05T14:30:00Z',
        'kpi': {
          'total_materials': 151,
          'active_storage_products': 42,
          'total_storage_stock': 12500.5,
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
          'total_storage_stock': 12500.5,
          'active_batches': 94,
          'depleted_batches': 15,
          'today_stock_in': 1200.0,
          'today_dispatch': 950.0,
          'top_products': [],
          'lowest_products': [],
          'expiring_batches': [],
          'distribution': [],
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
          'distribution': [],
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
          'purchase_trend': [],
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
          'dispatch_trend': [],
        },
        'transfers': {
          'today_transfers_out': 400.0,
          'today_transfers_ret': 50.0,
          'total_transfers_out': 4200.0,
          'total_transfers_ret': 800.0,
          'net_consumed': 3400.0,
          'top_departments': [],
          'most_transferred_materials': [],
          'transfer_trend': [],
        },
        'top_lists': {
          'reorder_risk': [],
          'highest_storage': [],
          'highest_materials': [],
          'top_dispatched': [],
        },
        'expiry_monitor': {
          'invoice_materials': [],
          'storage_products': [],
          'invoice_threshold_days': 45,
          'storage_threshold_days': 20,
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
            'title': 'Expired Raw Material',
            'message': 'Lot 44 expired',
            'reference_type': 'material',
            'reference_id': 'MAT-01',
          }
        ],
      };

      final summary = OwnerDashboardSummary.fromJson(sampleJson);
      expect(summary.kpi.totalMaterials, equals(151));
      expect(summary.kpi.totalStorageStock, equals(12500.5));
      expect(summary.kpi.activeBatchesCnt, equals(94));
      expect(summary.today.todayStockInQty, equals(1200.0));
      expect(summary.transfers.netConsumed, equals(3400.0));
      expect(summary.expiryMonitor.invoiceThresholdDays, equals(45));
      expect(summary.expiryMonitor.storageThresholdDays, equals(20));
      expect(summary.recentActivity.first.timeAmPm, equals('10:45 AM'));
      expect(summary.alerts.first.severity, equals('CRITICAL'));
    });
  });

  group('4. Owner Login UI Tests', () {
    testWidgets('OwnerLoginScreen renders executive branding and fields without emojis', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OwnerLoginScreen(),
          ),
        ),
      );

      // Verify Executive Title
      expect(find.text('BENCHMARK MMS'), findsOneWidget);
      expect(find.text('MANAGEMENT ACCESS'), findsOneWidget);

      // Verify Mandatory Security Message (No emojis)
      expect(find.text('Authorized management access only.'), findsOneWidget);

      // Verify Input Labels & Buttons
      expect(find.text('MANAGEMENT USERNAME / ID'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('Operator Login'), findsOneWidget);
    });
  });

  group('5. Owner Reports Hub UI Tests', () {
    testWidgets('OwnerReportsHubScreen displays all 8 core reports and operational registers', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OwnerReportsHubScreen(),
          ),
        ),
      );

      // Verify 8 Core Reports presence
      expect(find.text('Material Directory / Wall Chart'), findsOneWidget);
      expect(find.text('Daily Stock Ledger'), findsOneWidget);
      expect(find.text('Transfers by Department'), findsOneWidget);
      expect(find.text('Reorder Warning Report'), findsOneWidget);
      expect(find.text('Stock Availability & Dispatch Summary'), findsOneWidget);
      expect(find.text('Out of Stock Report'), findsOneWidget);
      expect(find.text('Expiring Items Monitor'), findsOneWidget);
      expect(find.text('Material Utilization Report (MUR)'), findsOneWidget);

      // Verify Additional Operational Registers
      expect(find.text('Purchase Invoices Register'), findsOneWidget);
      expect(find.text('Finished Goods Dispatch Register'), findsOneWidget);
      expect(find.text('Internal Transfers & Returns'), findsOneWidget);
      expect(find.text('Stock Adjustments Audit'), findsOneWidget);
      expect(find.text('Approved Vendors Directory'), findsOneWidget);
    });
  });
}
