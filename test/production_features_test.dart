import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/services/connection_service.dart';
import 'package:mms_app/core/services/pending_operations_service.dart';
import 'package:mms_app/data/repositories/auth_repository.dart';
import 'package:mms_app/data/models/notification_model.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/core/constants/factory_constants.dart';
import 'package:mms_app/core/formatters/app_date_formatter.dart';
import 'package:mms_app/presentation/providers/app_providers.dart';

void main() {
  group('1. Offline Handling & Pending Operations Tests', () {
    test('PendingOperation serialization and deserialization retains all fields', () {
      final now = DateTime.now();
      final op = PendingOperation(
        localOperationId: 'OP-LOCAL-001',
        operationType: 'invoice_create',
        module: 'invoices',
        payload: {
          'invoice': {'invoice_no': 'INV-TEST-001', 'total': 1500.0},
          'items': [
            {'material': 'MAT-01', 'qty': 10}
          ]
        },
        createdAt: now,
        userId: 'user-uuid-123',
        deviceId: 'DEVICE-UNIT-TEST',
        retryCount: 2,
        status: 'error',
        lastError: 'SocketException: Connection refused',
        idempotencyKey: 'IDEMP-DEVICE-001-INV-12345',
      );

      final json = op.toJson();
      final restored = PendingOperation.fromJson(json);

      expect(restored.localOperationId, 'OP-LOCAL-001');
      expect(restored.operationType, 'invoice_create');
      expect(restored.module, 'invoices');
      expect(restored.payload['invoice']['invoice_no'], 'INV-TEST-001');
      expect(restored.deviceId, 'DEVICE-UNIT-TEST');
      expect(restored.retryCount, 2);
      expect(restored.status, 'error');
      expect(restored.lastError, contains('SocketException'));
      expect(restored.idempotencyKey, 'IDEMP-DEVICE-001-INV-12345');
    });

    test('PendingOperation copyWith handles retry count and status change', () {
      final op = PendingOperation(
        localOperationId: 'OP-1',
        operationType: 'dispatch_create',
        module: 'dispatches',
        payload: {'qty': 50},
        createdAt: DateTime.now(),
        deviceId: 'DEV-1',
        idempotencyKey: 'IDEMP-1',
        status: 'pending',
      );

      final updated = op.copyWith(status: 'syncing', retryCount: 1);
      expect(updated.status, 'syncing');
      expect(updated.retryCount, 1);
      expect(updated.idempotencyKey, 'IDEMP-1');
    });
  });

  group('2. Connection Monitoring Tests', () {
    test('ConnectionStatus values and state enumeration', () {
      final status = ConnectionStatus(
        state: AppConnectionState.online,
        message: 'ONLINE',
        lastChecked: DateTime.now(),
        pendingCount: 0,
      );

      expect(status.state, AppConnectionState.online);
      expect(status.message, 'ONLINE');

      final offline = status.copyWith(
        state: AppConnectionState.offline,
        message: 'OFFLINE — Changes will sync when connection returns',
        pendingCount: 3,
      );
      expect(offline.state, AppConnectionState.offline);
      expect(offline.pendingCount, 3);
      expect(offline.message, contains('OFFLINE'));

      final syncing = status.copyWith(
        state: AppConnectionState.syncing,
        message: 'SYNCING (3 pending)...',
      );
      expect(syncing.state, AppConnectionState.syncing);

      final syncError = status.copyWith(
        state: AppConnectionState.syncError,
        message: 'SYNC_ERROR — Tap to view pending',
      );
      expect(syncError.state, AppConnectionState.syncError);
    });
  });

  group('3. Authentication & Username Mapping Tests', () {
    final authRepo = AuthRepository();

    test('Maps username "bm" to Supabase Auth email representation "bm@benchmarkmms.com"', () {
      final mapped = authRepo.mapUsernameToEmail('bm');
      expect(mapped, 'bm@benchmarkmms.com');
    });

    test('Preserves full email address if provided directly', () {
      final mapped = authRepo.mapUsernameToEmail('operator@factory.com');
      expect(mapped, 'operator@factory.com');
    });

    test('Trims and lowercases user input', () {
      final mapped = authRepo.mapUsernameToEmail('  BM  ');
      expect(mapped, 'bm@benchmarkmms.com');
    });

    test('UserProfileModel parses role and permissions correctly', () {
      final json = {
        'id': 'eca755a9-04cb-4e33-b8e2-fbc0c50cab01',
        'username': 'bm',
        'full_name': 'Benchmark Manager',
        'role': 'ADMIN',
        'permissions': [
          'materials.view',
          'materials.create',
          'invoice.view',
          'invoice.create',
          'transfer.view',
          'dispatch.view',
          'reports.view',
        ],
      };

      final profile = UserProfileModel.fromJson(json);
      expect(profile.username, 'bm');
      expect(profile.role, 'ADMIN');
      expect(profile.isAdmin, true);
      expect(profile.hasPermission('invoice.create'), true);
      expect(profile.hasPermission('unknown.permission'), true); // Admin has all permissions
    });

    test('Staff role has restricted granular permissions', () {
      final json = {
        'id': 'user-staff-id',
        'username': 'staff1',
        'full_name': 'Factory Staff',
        'role': 'STAFF',
        'permissions': ['materials.view', 'transfer.view'],
      };

      final profile = UserProfileModel.fromJson(json);
      expect(profile.isAdmin, false);
      expect(profile.hasPermission('materials.view'), true);
      expect(profile.hasPermission('users.manage'), false);
    });
  });

  group('4. Notification & Alert Models Tests', () {
    test('NotificationModel parses reorder and out of stock alerts correctly', () {
      final json = {
        'id': 101,
        'type': 'out_of_stock',
        'title': 'Out of Stock: 501',
        'message': 'Material 501 is completely out of stock.',
        'severity': 'CRITICAL',
        'reference_type': 'material',
        'reference_id': '501',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final notif = NotificationModel.fromJson(json);
      expect(notif.id, 101);
      expect(notif.type, 'out_of_stock');
      expect(notif.severity, 'CRITICAL');
      expect(notif.referenceType, 'material');
      expect(notif.referenceId, '501');
      expect(notif.isRead, false);
    });
  });

  group('5. Centralized UOM & Tea Grades Dropdowns', () {
    test('Standard UOM list contains 16 verified units', () {
      expect(FactoryConstants.uomList.length, 16);
      expect(FactoryConstants.units.contains('kg'), true);
      expect(FactoryConstants.units.contains('bags'), true);
      expect(FactoryConstants.units.contains('litre'), true);
    });

    test('Standard Tea Grades list contains 16 grades', () {
      expect(FactoryConstants.gradeList.length, 16);
      expect(FactoryConstants.grades.contains('BOP'), true);
      expect(FactoryConstants.grades.contains('BP'), true);
      expect(FactoryConstants.grades.contains('PF'), true);
      expect(FactoryConstants.grades.contains('DUST'), true);
    });

    test('Normalize UOM gracefully resolves aliases', () {
      expect(FactoryConstants.normalizeUomCode('KG'), 'kg');
      expect(FactoryConstants.normalizeUomCode('litre'), 'litre');
      expect(FactoryConstants.normalizeUomCode('custom-pack'), 'custom-pack');
    });
  });

  group('6. AppDateFormatter DD/MM/YYYY Tests', () {
    test('Formats DateTime to DD/MM/YYYY', () {
      final dt = DateTime(2026, 9, 30);
      expect(AppDateFormatter.format(dt), '30/09/2026');
    });

    test('Parses valid DD/MM/YYYY to DateTime', () {
      final dt = AppDateFormatter.tryParse('30/09/2026');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 9);
      expect(dt.day, 30);
    });

    test('Handles null, invalid strings, and ISO strings gracefully', () {
      expect(AppDateFormatter.format(null), '-');
      expect(AppDateFormatter.format('2026-09-30T10:00:00'), '30/09/2026');
      expect(AppDateFormatter.tryParse('31/02/2026'), isNull);
      expect(AppDateFormatter.tryParse('15/08/2026'), isNotNull);
    });
  });

  group('7. Filter Classes Equality and HashCode Tests', () {
    test('BatchesFilter equality and copy behavior', () {
      final f1 = BatchesFilter(search: 'lot1', fromDate: DateTime(2026, 9, 1), toDate: DateTime(2026, 9, 30));
      final f2 = BatchesFilter(search: 'lot1', fromDate: DateTime(2026, 9, 1), toDate: DateTime(2026, 9, 30));
      final f3 = BatchesFilter(search: 'lot2', fromDate: DateTime(2026, 9, 1), toDate: DateTime(2026, 9, 30));

      expect(f1 == f2, true);
      expect(f1.hashCode == f2.hashCode, true);
      expect(f1 == f3, false);
    });

    test('InvoicesFilter, TransfersFilter, DispatchesFilter equality', () {
      final inv1 = InvoicesFilter(search: 'INV-1');
      final inv2 = InvoicesFilter(search: 'INV-1');
      expect(inv1 == inv2, true);

      final tr1 = TransfersFilter(search: 'TR-1');
      final tr2 = TransfersFilter(search: 'TR-1');
      expect(tr1 == tr2, true);

      final disp1 = DispatchesFilter(search: 'DISP-1');
      final disp2 = DispatchesFilter(search: 'DISP-1');
      expect(disp1 == disp2, true);
    });
  });
}
