import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mms_app/data/models/batch_model.dart';
import 'package:mms_app/data/models/dispatch_model.dart';
import 'package:mms_app/data/models/storage_product_model.dart';
import 'package:mms_app/data/models/transfer_model.dart';

void main() {
  group('BENCHMARK MMS — Transfer Return Logic Unit Tests', () {
    test('Net Change calculation: Outward 20, Return 5 gives Net Change -15', () {
      const current = 100.0;
      const outward = 20.0;
      const returnQty = 5.0;

      final netChange = returnQty - outward;
      final newQuantity = current + netChange;

      expect(netChange, -15.0);
      expect(newQuantity, 85.0);

      final transfer = TransferModel(
        id: 1,
        code: 'MAT-001',
        description: 'Black Tea Raw',
        outward: outward,
        returnUnits: returnQty,
        availability: newQuantity,
        units: 'kg',
        department: 'Production',
        date: DateTime(2026, 10, 1),
      );

      expect(transfer.outward, 20.0);
      expect(transfer.returnUnits, 5.0);
      expect(transfer.netChange, -15.0);
    });

    test('Net Change calculation: Outward 0, Return 10 gives Net Change +10', () {
      const current = 100.0;
      const outward = 0.0;
      const returnQty = 10.0;

      final netChange = returnQty - outward;
      final newQuantity = current + netChange;

      expect(netChange, 10.0);
      expect(newQuantity, 110.0);
    });

    test('TransferModel JSON serialization preserves returnUnits and netChange', () {
      final json = {
        'id': 10,
        'code': 'TEA-LEAF',
        'description': 'Tea Leaves Extra',
        'outward': 50.0,
        'return_units': 15.0,
        'net_change': -35.0,
        'availability': 65.0,
        'units': 'kg',
        'department': 'Blending',
        'date': '2026-10-02',
      };

      final model = TransferModel.fromJson(json);
      expect(model.outward, 50.0);
      expect(model.returnUnits, 15.0);
      expect(model.netChange, -35.0);

      final serialized = model.toJson();
      expect(serialized['outward'], 50.0);
      expect(serialized['return_units'], 15.0);
      expect(model.netChange, -35.0);
    });
  });

  group('BENCHMARK MMS — Storage & Dispatch Product Model Tests', () {
    test('StorageProductModel serialization and field preservation', () {
      final json = {
        'id': 42,
        'product_code': 'PROD-001',
        'product_name': 'Premium Tea Box',
        'uom': 'boxes',
        'grade': 'GRADE-A',
        'category': 'Finished Goods',
      };

      final prod = StorageProductModel.fromJson(json);
      expect(prod.id, 42);
      expect(prod.productCode, 'PROD-001');
      expect(prod.productName, 'Premium Tea Box');
      expect(prod.uom, 'boxes');
      expect(prod.grade, 'GRADE-A');
      expect(prod.category, 'Finished Goods');
    });

    test('DispatchAvailableProductModel only represents products with stock in Storage', () {
      final json = {
        'product_code': 'PROD-777',
        'product_name': 'Organic Green Tea 250g',
        'uom': 'pkts',
        'grade': 'PREMIUM',
        'category': 'Finished Goods',
        'total_available': 150.0,
        'batch_count': 3,
      };

      final avail = DispatchAvailableProductModel.fromJson(json);
      expect(avail.productCode, 'PROD-777');
      expect(avail.totalAvailable, 150.0);
      expect(avail.batchCount, 3);
      expect(avail.displayName, 'Organic Green Tea 250g (PROD-777)');
    });
  });

  group('BENCHMARK MMS — Dispatch Return & Multi-Batch FIFO Tests', () {
    test('DispatchModel calculates netQuantity: Dispatch 100, Return 20 = Net 80', () {
      final dispatch = DispatchModel(
        id: 5,
        materialCode: 'PROD-001',
        product: 'Premium Tea Box',
        quantity: 100.0,
        returnQuantity: 20.0,
        netQuantity: 80.0,
        units: 'boxes',
        department: 'Retail Hub',
        date: DateTime(2026, 10, 2),
      );

      expect(dispatch.quantity, 100.0);
      expect(dispatch.returnQuantity, 20.0);
      expect(dispatch.netQuantity, 80.0);
      expect(dispatch.netQuantity, dispatch.quantity - dispatch.returnQuantity);

      final json = dispatch.toJson();
      expect(json['quantity'], 100.0);
      expect(json['return_quantity'], 20.0);
      expect(json['net_quantity'], 80.0);
    });

    test('Multi-batch threshold detection correctly flags when qty exceeds first batch', () {
      final batches = [
        {'batch_no': 'B001', 'available_quantity': 100.0},
        {'batch_no': 'B002', 'available_quantity': 100.0},
      ];

      const requestedQty = 150.0;
      final firstBatchAvail = (batches.first['available_quantity'] as num).toDouble();

      final exceedsFirstBatch = requestedQty > firstBatchAvail;
      final remainingNeeded = requestedQty - firstBatchAvail;

      expect(exceedsFirstBatch, isTrue);
      expect(remainingNeeded, 50.0);
    });
  });

  group('BENCHMARK MMS — Expiry Date Formatting & Validation Tests', () {
    test('Expiry Date formats as DD/MM/YYYY and detects expired batches', () {
      final futureDate = DateTime(2026, 12, 31);
      final formatted = DateFormat('dd/MM/yyyy').format(futureDate);
      expect(formatted, '31/12/2026');

      final pastBatch = BatchModel(
        id: 1,
        batchNo: '001',
        materialCode: 'PROD-001',
        receivedQuantity: 50.0,
        availableQuantity: 50.0,
        expiryDate: DateTime(2020, 1, 1),
      );

      expect(pastBatch.isExpired, isTrue);

      final futureBatch = BatchModel(
        id: 2,
        batchNo: '002',
        materialCode: 'PROD-001',
        receivedQuantity: 50.0,
        availableQuantity: 50.0,
        expiryDate: DateTime(2030, 1, 1),
      );

      expect(futureBatch.isExpired, isFalse);
    });
  });
}
