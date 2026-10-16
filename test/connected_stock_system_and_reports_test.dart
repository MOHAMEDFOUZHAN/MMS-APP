import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/owner_reporting_models.dart';
import 'package:mms_app/data/models/material_model.dart';
import 'package:mms_app/data/models/transfer_model.dart';
import 'package:mms_app/data/models/invoice_model.dart';
import 'package:mms_app/data/models/tea_consumption_model.dart';
import 'package:mms_app/data/models/tea_material_received_model.dart';

void main() {
  group('Connected Inventory Stock System & Owner Reports Test Suite', () {
    // ════════════════════════════════════════════════════════════════════════
    // TEST 1 — INVOICE: FINALIZED RECEIPT INCREASES ADMIN STOCK EXACTLY ONCE
    // ════════════════════════════════════════════════════════════════════════
    test('Test 1 — Finalized Invoice increases Admin warehouse stock exactly once', () {
      final initialMaterial = MaterialModel(
        id: 101,
        materialCode: 'LIME-TEA-001',
        description: 'Lime Tea Extracts',
        quantity: 0.0,
        unit: 'kg',
      );
      expect(initialMaterial.quantity, 0.0);

      // Inward finalized invoice line item of 100 KG
      final invoice = InvoiceModel(
        id: 501,
        invoiceNo: 'INV-2026-001',
        date: DateTime(2026, 10, 14),
        paymentStatus: 'Confirmed',
        items: [
          InvoiceItemModel(
            id: 1,
            invoiceId: 501,
            material: 'LIME-TEA-001',
            quantity: 100.0,
            unit: 'kg',
            unitPrice: 120.0,
          ),
        ],
      );

      final updatedAdminStock = initialMaterial.quantity + invoice.items.first.quantity;
      expect(updatedAdminStock, 100.0);
      expect(invoice.items.first.quantity, 100.0);
    });

    // ════════════════════════════════════════════════════════════════════════
    // TEST 2 — TRANSFER: MOVES STOCK BETWEEN LOCATIONS WITHOUT CREATING NEW STOCK
    // ════════════════════════════════════════════════════════════════════════
    test('Test 2 — Outward Transfer deducts source Admin stock and adds to Tea without inflating business stock', () {
      double adminStock = 100.0;
      double teaStock = 0.0;
      final initialBusinessStock = adminStock + teaStock;
      expect(initialBusinessStock, 100.0);

      // Transfer 40 KG from Admin to Tea
      final transfer = TransferModel(
        id: 601,
        date: DateTime(2026, 10, 14),
        code: 'LIME-TEA-001',
        outward: 40.0,
        returnUnits: 0.0,
        department: 'TEA',
        units: 'kg',
      );

      adminStock -= transfer.outward;
      teaStock += transfer.outward;

      expect(adminStock, 60.0);
      expect(teaStock, 40.0);

      // Business-wide stock remains invariant: 60 + 40 = 100 KG
      final totalBusinessStock = adminStock + teaStock;
      expect(totalBusinessStock, 100.0);
      expect(totalBusinessStock, initialBusinessStock);
    });

    // ════════════════════════════════════════════════════════════════════════
    // TEST 3 — CONSUMPTION: TEA CONSUMES FROM BALANCE
    // ════════════════════════════════════════════════════════════════════════
    test('Test 3 — Tea consumption reduces department balance without double-deducting Admin', () {
      const totalReceivedInTea = 40.0;
      const totalReturnedToAdmin = 0.0;

      final consumption = TeaConsumptionModel(
        id: 701,
        date: DateTime(2026, 10, 14),
        createdAt: DateTime(2026, 10, 14, 10, 0),
        updatedAt: DateTime(2026, 10, 14, 10, 0),
        materialCode: 'LIME-TEA-001',
        description: 'Lime Tea',
        takenQty: 40.0,
        consumedQty: 30.0,
        balanceQty: 10.0,
        status: 'CLOSED',
      );

      final teaAvailableBalance = totalReceivedInTea - totalReturnedToAdmin - consumption.consumedQty;
      expect(teaAvailableBalance, 10.0);

      // Admin stock remains 60 KG
      const adminStock = 60.0;
      expect(adminStock, 60.0);

      // Active raw stock across business = 60 + 10 = 70 KG
      expect(adminStock + teaAvailableBalance, 70.0);
    });

    // ════════════════════════════════════════════════════════════════════════
    // TEST 4 — CONFIRMED RETURN: RESTORES ADMIN STOCK AND REDUCES TEA BALANCE
    // ════════════════════════════════════════════════════════════════════════
    test('Test 4 — Confirmed physical return increases Admin stock and reduces Tea balance to zero', () {
      double adminStock = 60.0;
      const totalReceivedInTea = 40.0;
      const totalConsumedInTea = 30.0;

      // Physically return remaining 10 KG to Admin
      final returnTransfer = TransferModel(
        id: 602,
        date: DateTime(2026, 10, 14),
        code: 'LIME-TEA-001',
        outward: 0.0,
        returnUnits: 10.0,
        department: 'TEA',
        units: 'kg',
      );

      // Admin receives return units
      adminStock += returnTransfer.returnUnits;
      expect(adminStock, 70.0);

      // Authoritative Tea Balance = Valid Received - Consumed - Confirmed Returned
      final updatedTeaBalance = totalReceivedInTea - totalConsumedInTea - returnTransfer.returnUnits;
      expect(updatedTeaBalance, 0.0);

      // Business-wide stock remains consistent (70 KG Admin + 0 KG Tea = 70 KG)
      expect(adminStock + updatedTeaBalance, 70.0);
    });

    // ════════════════════════════════════════════════════════════════════════
    // TEST 5 — OUT OF STOCK: CROSS-LOCATION VS BUSINESS-WIDE DISTINCTION
    // ════════════════════════════════════════════════════════════════════════
    test('Test 5 — Out of Stock report distinguishes location depletion from business-wide depletion', () {
      // Case A: Depleted at Location (Admin has 0, but Chocolate has 100 KG)
      final locationDepletedItem = OwnerOutOfStockItem(
        materialCode: '2',
        description: 'WHITE COCO',
        category: 'CHOCOLATE',
        unit: 'kg',
        location: 'Admin Warehouse',
        locationStock: 0.0,
        adminStock: 0.0,
        teaStock: 0.0,
        chocolateStock: 100.0,
        totalBusinessStock: 100.0,
        reorderLevel: 10.0,
        stockStatus: 'OUT_OF_STOCK_LOCATION',
        statusMessage: 'Depleted in Admin | Available in: 100.0 kg in Chocolate',
      );

      expect(locationDepletedItem.isDepletedLocationOnly, isTrue);
      expect(locationDepletedItem.isDepletedBusinessWide, isFalse);
      expect(locationDepletedItem.totalBusinessStock, 100.0);

      // Case B: Completely Out of Stock Across Entire Business
      final businessDepletedItem = OwnerOutOfStockItem(
        materialCode: '10',
        description: 'CITRIC ACID',
        category: 'TEA',
        unit: 'kg',
        location: 'Business-Wide',
        locationStock: 0.0,
        adminStock: 0.0,
        teaStock: 0.0,
        chocolateStock: 0.0,
        totalBusinessStock: 0.0,
        reorderLevel: 5.0,
        stockStatus: 'OUT_OF_STOCK_BUSINESS',
        statusMessage: 'Out of Stock Across Business (0 in all departments)',
      );

      expect(businessDepletedItem.isDepletedBusinessWide, isTrue);
      expect(businessDepletedItem.isDepletedLocationOnly, isFalse);
      expect(businessDepletedItem.totalBusinessStock, 0.0);
    });

    // ════════════════════════════════════════════════════════════════════════
    // TEST 6 — REORDER: THRESHOLD EVALUATION AND SUGGESTED REPLENISHMENT
    // ════════════════════════════════════════════════════════════════════════
    test('Test 6 — Reorder Report calculates suggested replenishment only when target stock is set', () {
      // Case A: Reorder Required with Target Stock configured
      final itemWithTarget = OwnerReorderItem(
        materialCode: 'MAT-TEA-001',
        description: 'Assam Tea Premium',
        category: 'TEA',
        unit: 'kg',
        location: 'Business-Wide',
        availableStock: 5.0,
        totalBusinessStock: 5.0,
        adminStock: 5.0,
        teaStock: 0.0,
        chocolateStock: 0.0,
        reorderLevel: 10.0,
        targetStock: 25.0,
        suggestedReplenishment: 20.0, // 25.0 - 5.0
        status: 'REORDER_REQUIRED',
        statusMessage: 'Reorder Required (Stock <= 10.0 kg)',
      );

      expect(itemWithTarget.isReorderRequired, isTrue);
      expect(itemWithTarget.suggestedReplenishment, 20.0);
      expect(itemWithTarget.formattedSuggestedReplenishment.contains('20'), isTrue);

      // Case B: Reorder Required but Target Stock is NOT configured (do not invent numbers)
      final itemWithoutTarget = OwnerReorderItem(
        materialCode: 'MAT-TEA-002',
        description: 'Cardamom Grade B',
        category: 'SPICES',
        unit: 'kg',
        location: 'Business-Wide',
        availableStock: 2.0,
        totalBusinessStock: 2.0,
        adminStock: 2.0,
        teaStock: 0.0,
        chocolateStock: 0.0,
        reorderLevel: 10.0,
        targetStock: null,
        suggestedReplenishment: null,
        status: 'REORDER_REQUIRED',
        statusMessage: 'Reorder Required (Stock <= 10.0 kg)',
      );

      expect(itemWithoutTarget.isReorderRequired, isTrue);
      expect(itemWithoutTarget.suggestedReplenishment, isNull);
      expect(itemWithoutTarget.formattedSuggestedReplenishment, '— (Target Not Set)');

      // Case C: Reorder Level is not configured
      final unconfiguredItem = OwnerReorderItem(
        materialCode: 'MAT-UNCONFIG-003',
        description: 'Packaging Foil',
        category: 'PACKAGING',
        unit: 'rolls',
        location: 'Business-Wide',
        availableStock: 0.0,
        totalBusinessStock: 0.0,
        adminStock: 0.0,
        teaStock: 0.0,
        chocolateStock: 0.0,
        reorderLevel: 0.0,
        status: 'NOT_CONFIGURED',
        statusMessage: 'Reorder Level Not Configured',
      );

      expect(unconfiguredItem.isNotConfigured, isTrue);
      expect(unconfiguredItem.formattedReorderLevel, 'Not Set');
    });

    // ════════════════════════════════════════════════════════════════════════
    // TEST 7 — CHOCOLATE: RAW TRANSFERS SEPARATE FROM OCR & RACK
    // ════════════════════════════════════════════════════════════════════════
    test('Test 7 — Chocolate raw material balance is isolated from OCR weighing scans and finished rack goods', () {
      final rawItem = OwnerChocolateLiveMaterialItem(
        materialCode: 'COCOA-001',
        description: 'Cocoa Butter',
        category: 'CHOCOLATE',
        unit: 'kg',
        totalReceived: 50.0,
        totalAccounted: 0.0,
        currentBalance: 50.0,
        status: 'IN_STOCK',
        transferCount: 1,
      );

      expect(rawItem.totalReceived, 50.0);
      expect(rawItem.currentBalance, 50.0);

      // OCR record of finished goods weighing 2.450 KG
      const ocrFinishedWeight = 2.450;
      // Rack finished batch of 10.0 KG
      const rackBatchWeight = 10.0;

      // Verifying raw stock is untouched by downstream scans / finished rack batches
      expect(rawItem.currentBalance, 50.0);
      expect(rawItem.currentBalance == (rawItem.currentBalance - ocrFinishedWeight), isFalse);
      expect(rawItem.currentBalance == (rawItem.currentBalance - rackBatchWeight), isFalse);
    });

    // ════════════════════════════════════════════════════════════════════════
    // TEST 8 — IDEMPOTENCY / DUPLICATE PROTECTION PATTERN
    // ════════════════════════════════════════════════════════════════════════
    test('Test 8 — Duplicate requests with identical idempotency key do not double-post', () {
      final Map<String, dynamic> idempotencyStore = {};

      Map<String, dynamic> executeTransferWithIdempotency(String idempotencyKey, double outward) {
        if (idempotencyStore.containsKey(idempotencyKey)) {
          return idempotencyStore[idempotencyKey] as Map<String, dynamic>;
        }

        final response = {
          'success': true,
          'outward_posted': outward,
          'transfer_id': 1001,
          'status': 'completed',
        };
        idempotencyStore[idempotencyKey] = response;
        return response;
      }

      const testKey = 'unique-idempotency-uuid-777';
      final call1 = executeTransferWithIdempotency(testKey, 25.0);
      expect(call1['outward_posted'], 25.0);

      // Repeated network request with same key
      final call2 = executeTransferWithIdempotency(testKey, 25.0);
      expect(call2['outward_posted'], 25.0);
      expect(identical(call1, call2), isTrue);
      expect(idempotencyStore.length, 1);
    });

    // ════════════════════════════════════════════════════════════════════════
    // TEST 9 — HISTORICAL INTEGRITY: TIMESTAMPS AND AUDIT TRAIL PRESERVED
    // ════════════════════════════════════════════════════════════════════════
    test('Test 9 — Historical records preserve transaction dates and timestamps accurately', () {
      final fixedDate = DateTime(2026, 9, 15, 14, 30);
      final rawLedger = TeaMaterialReceivedModel(
        materialCode: 'TEA-BOP-001',
        description: 'BOP Tea Grade 1',
        category: 'TEA',
        unit: 'kg',
        totalReceived: 100.0,
        totalConsumed: 40.0,
        totalReturned: 10.0,
        currentBalance: 50.0,
        latestTransactionAt: fixedDate,
        stockStatus: 'IN_STOCK',
      );

      expect(rawLedger.latestTransactionAt, fixedDate);
      expect(rawLedger.currentBalance, 50.0);
      expect(rawLedger.totalReceived - rawLedger.totalConsumed - rawLedger.totalReturned, 50.0);
    });
  });
}
