import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/user_profile_model.dart';
import 'package:mms_app/data/models/owner_reporting_models.dart';
import 'package:mms_app/data/models/tea_material_received_model.dart';
import 'package:mms_app/data/models/invoice_model.dart';
import 'package:mms_app/data/models/transfer_model.dart';
import 'package:mms_app/data/models/tea_consumption_model.dart';

void main() {
  group('Owner Management Reporting Portal Verification Suite', () {
    test('1. Owner Profile authorization is strictly read-only and decoupled from Admin', () {
      final owner = UserProfileModel(
        id: 'owner-uuid-1',
        username: 'owner',
        fullName: 'Executive Owner',
        role: 'OWNER',
        permissions: ['owner.*', 'materials.view', 'invoice.view', 'transfer.view'],
      );

      // Verify role flags
      expect(owner.isOwner, isTrue);
      expect(owner.isAdmin, isFalse, reason: 'Owner must never be treated as Admin in operational screens');
      expect(owner.isTeaUser, isFalse);
      expect(owner.isChocolateUser, isFalse);

      // Verify read-only permissions are granted
      expect(owner.hasPermission('materials.view'), isTrue);
      expect(owner.hasPermission('invoice.view'), isTrue);
      expect(owner.hasPermission('transfer.view'), isTrue);
      expect(owner.hasPermission('reports.view'), isTrue);
      expect(owner.hasPermission('owner.reports'), isTrue);

      // Verify operational write/mutation permissions are strictly denied
      expect(owner.hasPermission('materials.create'), isFalse);
      expect(owner.hasPermission('materials.edit'), isFalse);
      expect(owner.hasPermission('materials.delete'), isFalse);
      expect(owner.hasPermission('invoice.create'), isFalse);
      expect(owner.hasPermission('transfer.create'), isFalse);
      expect(owner.hasPermission('dispatch.create'), isFalse);
      expect(owner.hasPermission('consumption.create'), isFalse);
    });

    test('2. Admin Live Stock model accurately distinguishes Admin stock from department transfers', () {
      final raw = {
        'id': 101,
        'material_code': 'MAT-TEA-001',
        'description': 'Premium Black Tea BOP',
        'category': 'TEA',
        'unit': 'kg',
        'admin_stock': 850.0,
        'tea_stock': 120.0,
        'chocolate_stock': 0.0,
        'other_stock': 0.0,
        'total_transferred': 120.0,
        'total_system_stock': 970.0,
        'last_transaction_at': '2026-10-13T10:30:00Z',
      };

      final item = OwnerAdminLiveStockItem.fromJson(raw);
      expect(item.materialCode, 'MAT-TEA-001');
      expect(item.adminStock, 850.0);
      expect(item.teaStock, 120.0);
      expect(item.chocolateStock, 0.0);
      expect(item.totalTransferred, 120.0);
      expect(item.totalSystemStock, 970.0);
      expect(item.adminStock + item.totalTransferred, item.totalSystemStock);
      expect(item.lastTransactionAt, isNotNull);
    });

    test('3. Tea Live Material strictly enforces: Available = Valid Received - Consumed - Confirmed Returned', () {
      final raw = {
        'material_code': 'MAT-TEA-001',
        'description': 'Premium Black Tea BOP',
        'category': 'TEA',
        'unit': 'kg',
        'total_received': 500.0,
        'total_consumed': 320.0,
        'total_returned': 30.0,
        'current_balance': 150.0,
        'latest_transaction_at': '2026-10-12T14:00:00Z',
        'stock_status': 'IN_STOCK',
      };

      final item = TeaMaterialReceivedModel.fromJson(raw);
      expect(item.materialCode, 'MAT-TEA-001');
      expect(item.totalReceived, 500.0);
      expect(item.totalConsumed, 320.0);
      expect(item.totalReturned, 30.0);
      expect(item.currentBalance, 150.0);
      // Mathematical rule check
      expect(
        item.totalReceived - item.totalConsumed - item.totalReturned,
        item.currentBalance,
      );
    });

    test('4. Chocolate Live Material model accurately parses received and available balances', () {
      final raw = {
        'material_code': 'MAT-CHOC-005',
        'description': 'Cocoa Butter Solids',
        'category': 'CHOCOLATE',
        'unit': 'kg',
        'total_received': 400.0,
        'total_accounted': 25.0,
        'current_balance': 375.0,
        'latest_activity': '2026-10-11T12:00:00Z',
        'status': 'IN_STOCK',
        'transfer_count': 3,
      };

      final item = OwnerChocolateLiveMaterialItem.fromJson(raw);
      expect(item.materialCode, 'MAT-CHOC-005');
      expect(item.totalReceived, 400.0);
      expect(item.totalAccounted, 25.0);
      expect(item.currentBalance, 375.0);
      expect(item.totalReceived - item.totalAccounted, item.currentBalance);
    });

    test('5. Transaction models provide consistent effectiveDateTime for accurate date filtering', () {
      final invoice = InvoiceModel(
        id: 1,
        date: DateTime(2026, 10, 13),
        invoiceNo: 'INV-2026-001',
        createdAt: DateTime(2026, 10, 13, 11, 45),
      );
      expect(invoice.effectiveDateTime, DateTime(2026, 10, 13, 11, 45));

      final transfer = TransferModel(
        id: 2,
        date: DateTime(2026, 10, 13),
        code: 'MAT-TEA-001',
        createdAt: DateTime(2026, 10, 13, 14, 20),
      );
      expect(transfer.effectiveDateTime, DateTime(2026, 10, 13, 14, 20));

      final consumption = TeaConsumptionModel(
        id: 3,
        date: DateTime(2026, 10, 13),
        createdAt: DateTime(2026, 10, 13, 15, 30),
        updatedAt: DateTime(2026, 10, 13, 15, 30),
        materialCode: 'MAT-TEA-001',
        description: 'BOP Tea',
        takenQty: 50.0,
        consumedQty: 50.0,
      );
      expect(consumption.effectiveDateTime, DateTime(2026, 10, 13, 15, 30));
    });
  });
}
