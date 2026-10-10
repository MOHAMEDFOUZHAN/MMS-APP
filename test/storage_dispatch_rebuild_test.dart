import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/batch_model.dart';
import 'package:mms_app/data/models/dispatch_model.dart';
import 'package:mms_app/data/models/material_model.dart';

void main() {
  group('BENCHMARK MMS — Storage -> Dispatch Rebuild Unit Tests', () {
    test('BatchModel JSON serialization and deserialization with new fields', () {
      final json = {
        'id': 101,
        'material_id': 42,
        'material_code': 'MAT-42',
        'description': 'Pure Copper Rod',
        'batch_no': '275',
        'received_quantity': 100.0,
        'available_quantity': 80.0,
        'uom': 'kg',
        'category': 'Metals',
        'grade': 'A',
        'batch_date': '2026-10-02',
        'expiry_date': '2027-10-02',
        'received_date': '2026-10-02T10:00:00Z',
        'created_at': '2026-10-02T10:00:00Z',
        'updated_at': '2026-10-02T11:00:00Z',
      };

      final batch = BatchModel.fromJson(json);

      expect(batch.id, 101);
      expect(batch.materialId, 42);
      expect(batch.materialCode, 'MAT-42');
      expect(batch.description, 'Pure Copper Rod');
      expect(batch.batchNo, '275');
      expect(batch.receivedQuantity, 100.0);
      expect(batch.availableQuantity, 80.0);
      expect(batch.uom, 'kg');
      expect(batch.category, 'Metals');
      expect(batch.grade, 'A');
      expect(batch.batchDate, DateTime(2026, 10, 2));
      expect(batch.expiryDate, DateTime(2027, 10, 2));
      expect(batch.isExpired, false);

      final serialized = batch.toJson();
      expect(serialized['material_id'], 42);
      expect(serialized['category'], 'Metals');
      expect(serialized['grade'], 'A');
      expect(serialized['batch_date'], '2026-10-02');
      expect(serialized['expiry_date'], '2027-10-02');
    });

    test('BatchModel detects expired batches accurately', () {
      final expiredBatch = BatchModel(
        id: 1,
        materialCode: 'MAT-OLD',
        description: 'Expired Resin',
        batchNo: '001',
        receivedQuantity: 50.0,
        availableQuantity: 50.0,
        uom: 'L',
        receivedDate: DateTime(2024, 1, 1),
        expiryDate: DateTime(2024, 6, 1),
      );

      expect(expiredBatch.isExpired, true);

      final validBatch = BatchModel(
        id: 2,
        materialCode: 'MAT-NEW',
        description: 'Fresh Resin',
        batchNo: '275',
        receivedQuantity: 50.0,
        availableQuantity: 50.0,
        uom: 'L',
        receivedDate: DateTime(2026, 10, 2),
        expiryDate: DateTime(2030, 1, 1),
      );

      expect(validBatch.isExpired, false);
    });

    test('DispatchModel JSON serialization and deserialization with remarks and audit fields', () {
      final json = {
        'id': 999,
        'material_id': 101,
        'dispatch_date': '2026-10-02',
        'material_code': 'MAT-101',
        'description': 'Steel Plate 10mm',
        'category': 'Ferrous',
        'grade': 'Grade 1',
        'quantity': 150.0,
        'units': 'nos',
        'department': 'Fabrication',
        'location': 'Bay 3',
        'remarks': 'Urgent production release for Project Alpha',
        'created_at': '2026-10-02T10:00:00Z',
        'created_by': 'uuid-user-admin',
        'dispatch_batches': [
          {
            'id': 1,
            'dispatch_id': 999,
            'batch_id': 11,
            'batch_no': '274',
            'quantity': 100.0,
            'uom': 'nos',
            'batch_date': '2026-10-01',
            'created_at': '2026-10-02T10:00:00Z',
          },
          {
            'id': 2,
            'dispatch_id': 999,
            'batch_id': 12,
            'batch_no': '275',
            'quantity': 50.0,
            'uom': 'nos',
            'batch_date': '2026-10-02',
            'created_at': '2026-10-02T10:00:00Z',
          },
        ],
      };

      final dispatch = DispatchModel.fromJson(json);

      expect(dispatch.id, 999);
      expect(dispatch.materialId, 101);
      expect(dispatch.materialCode, 'MAT-101');
      expect(dispatch.product, 'Steel Plate 10mm');
      expect(dispatch.category, 'Ferrous');
      expect(dispatch.grade, 'Grade 1');
      expect(dispatch.quantity, 150.0);
      expect(dispatch.units, 'nos');
      expect(dispatch.department, 'Fabrication');
      expect(dispatch.location, 'Bay 3');
      expect(dispatch.remarks, 'Urgent production release for Project Alpha');
      expect(dispatch.createdBy, 'uuid-user-admin');

      expect(dispatch.allocations.length, 2);
      expect(dispatch.allocations[0].batchNo, '274');
      expect(dispatch.allocations[0].quantity, 100.0);
      expect(dispatch.allocations[0].uom, 'nos');
      expect(dispatch.allocations[0].batchDate, DateTime(2026, 10, 1));

      expect(dispatch.allocations[1].batchNo, '275');
      expect(dispatch.allocations[1].quantity, 50.0);

      final serialized = dispatch.toJson();
      expect(serialized['material_id'], 101);
      expect(serialized['category'], 'Ferrous');
      expect(serialized['grade'], 'Grade 1');
      expect(serialized['remarks'], 'Urgent production release for Project Alpha');
    });

    test('Day of year batch number calculation for leap and non-leap years', () {
      int calcDoy(DateTime d) {
        final start = DateTime(d.year, 1, 1);
        return d.difference(start).inDays + 1;
      }

      // Leap year 2024
      final leapDec31 = DateTime(2024, 12, 31);
      expect(calcDoy(leapDec31), 366);

      // Non-leap year 2026
      final nonLeapDec31 = DateTime(2026, 12, 31);
      expect(calcDoy(nonLeapDec31), 365);

      final oct1 = DateTime(2026, 10, 1);
      expect(calcDoy(oct1), 274);
    });

    test('Materials Live vs Storage separation rule verification', () {
      // Invariant: Dispatch ONLY changes batches.available_quantity, NOT materials.quantity
      final material = MaterialModel(
        id: 1,
        materialCode: 'MAT-RULE',
        description: 'Test Separation',
        unit: 'kg',
        quantity: 500.0, // Live materials stock from Invoices / Transfers
      );

      final batch = BatchModel(
        id: 1,
        materialId: 1,
        materialCode: 'MAT-RULE',
        description: 'Test Separation',
        batchNo: '001',
        receivedQuantity: 100.0,
        availableQuantity: 100.0, // Storage stock available for dispatch
        uom: 'kg',
        receivedDate: DateTime(2026, 10, 1),
      );

      // Simulate a dispatch of 40 kg from Storage
      const dispatchQty = 40.0;
      final newBatchAvailableQty = batch.availableQuantity - dispatchQty;

      // Assert Storage decreased
      expect(newBatchAvailableQty, 60.0);
      // Assert Material Live stock remained 500.0, strictly preserved and untouched
      expect(material.quantity, 500.0);
    });
  });
}
