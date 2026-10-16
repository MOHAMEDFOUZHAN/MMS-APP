import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/chocolate_ocr_ledger_model.dart';
import 'package:mms_app/data/models/storage_product_model.dart';
import 'package:mms_app/data/models/batch_model.dart';
import 'package:mms_app/data/models/dispatch_model.dart';

void main() {
  group('Chocolate OCR, Tray, and Consign Integration Tests', () {
    test('1. ChocolateOcrLedgerModel properly generates productCode and preserves confirmed weight', () {
      final ocrJson = {
        'id': 101,
        'description': 'Dark Chocolate 500g',
        'quantity': 25.5,
        'unit': 'KG',
        'raw_ocr_quantity': 25.5,
        'status': 'CONFIRMED',
        'confirmed_at': '2026-10-13T10:00:00Z',
        'idempotency_key': 'CHOC-TEST-001',
      };

      final model = ChocolateOcrLedgerModel.fromJson(ocrJson);

      expect(model.id, 101);
      expect(model.description, 'Dark Chocolate 500g');
      expect(model.productCode, 'TRAY-DARK-CHOCOLATE-500G');
      expect(model.quantity, 25.5);
      expect(model.unit, 'KG');
      expect(model.status, 'CONFIRMED');
      expect(model.displayQuantity, '25.5 KG');

      final serialized = model.toJson();
      expect(serialized['product_code'], 'TRAY-DARK-CHOCOLATE-500G');
      expect(serialized['quantity'], 25.5);
      expect(serialized['status'], 'CONFIRMED');
    });

    test('2. Tray BatchModel preserves ocrLedgerId link and serializes correctly', () {
      final batch = BatchModel(
        id: 201,
        batchNo: '42',
        batchDate: DateTime(2026, 10, 13),
        materialCode: 'TRAY-DARK-CHOCOLATE-500G',
        description: 'Dark Chocolate 500g',
        category: 'CHOCOLATE',
        receivedQuantity: 25.5,
        availableQuantity: 25.5,
        uom: 'kg',
        department: 'Chocolate',
        ocrLedgerId: 101,
      );

      expect(batch.ocrLedgerId, 101);
      expect(batch.category, 'CHOCOLATE');
      expect(batch.availableQuantity, 25.5);

      final json = batch.toJson();
      expect(json['ocr_ledger_id'], 101);
      expect(json['category'], 'CHOCOLATE');

      final deserialized = BatchModel.fromJson({
        ...json,
        'id': 201,
      });
      expect(deserialized.ocrLedgerId, 101);
      expect(deserialized.materialCode, 'TRAY-DARK-CHOCOLATE-500G');
    });

    test('3. Consign DispatchModel preserves ocrLedgerId link and serializes correctly', () {
      final dispatch = DispatchModel(
        id: 301,
        date: DateTime(2026, 10, 13),
        materialCode: 'TRAY-DARK-CHOCOLATE-500G',
        product: 'Dark Chocolate 500g',
        category: 'CHOCOLATE',
        quantity: 25.5,
        returnQuantity: 0.0,
        units: 'kg',
        department: 'Chocolate',
        ocrLedgerId: 101,
      );

      expect(dispatch.ocrLedgerId, 101);
      expect(dispatch.category, 'CHOCOLATE');
      expect(dispatch.netQuantity, 25.5);

      final json = dispatch.toJson();
      expect(json['ocr_ledger_id'], 101);

      final deserialized = DispatchModel.fromJson({
        ...json,
        'id': 301,
      });
      expect(deserialized.ocrLedgerId, 101);
      expect(deserialized.product, 'Dark Chocolate 500g');
    });

    test('4. Product Search and Alphabetical Sorting behavior for Tray and Consign', () {
      final products = [
        StorageProductModel(
          id: 1,
          productCode: 'TRAY-WHITE-BAR',
          productName: 'White Bar Chocolate',
          category: 'CHOCOLATE',
        ),
        StorageProductModel(
          id: 2,
          productCode: 'TRAY-ALMOND-SLAB',
          productName: 'Almond Slab 200g',
          category: 'CHOCOLATE',
        ),
        StorageProductModel(
          id: 3,
          productCode: 'TRAY-DARK-CHOCOLATE',
          productName: 'Dark Chocolate 500g',
          category: 'CHOCOLATE',
        ),
      ];

      // Alphabetical sort by product name
      products.sort((a, b) => a.productName.toLowerCase().compareTo(b.productName.toLowerCase()));

      expect(products[0].productName, 'Almond Slab 200g');
      expect(products[1].productName, 'Dark Chocolate 500g');
      expect(products[2].productName, 'White Bar Chocolate');

      // Search by partial query (case-insensitive name or code)
      final search1 = products.where(
        (p) => p.productName.toLowerCase().contains('dark') || p.productCode.toLowerCase().contains('dark'),
      ).toList();
      expect(search1.length, 1);
      expect(search1.first.productName, 'Dark Chocolate 500g');

      // Search by code
      final search2 = products.where(
        (p) => p.productName.toLowerCase().contains('almond') || p.productCode.toLowerCase().contains('almond'),
      ).toList();
      expect(search2.length, 1);
      expect(search2.first.productCode, 'TRAY-ALMOND-SLAB');

      // Empty search returns all products in alphabetical order
      final emptySearch = products.where(
        (p) => ''.isEmpty || p.productName.toLowerCase().contains('') || p.productCode.toLowerCase().contains(''),
      ).toList();
      expect(emptySearch.length, 3);
      expect(emptySearch.first.productName, 'Almond Slab 200g');

      // Non-matching search returns empty without error
      final noResult = products.where(
        (p) => p.productName.toLowerCase().contains('nonexistent') || p.productCode.toLowerCase().contains('nonexistent'),
      ).toList();
      expect(noResult.isEmpty, true);
    });

    test('5. Confirmed OCR scans feeding into Consign available products', () {
      final availableFromTray = [
        DispatchAvailableProductModel(
          productCode: 'TRAY-MILK-CHOC',
          productName: 'Milk Chocolate Bar',
          uom: 'kg',
          grade: 'STANDARD',
          category: 'CHOCOLATE',
          totalAvailable: 50.0,
          batchCount: 2,
        ),
      ];

      final confirmedOcr = [
        ChocolateOcrLedgerModel(
          id: 501,
          description: 'White bar',
          quantity: 244.0,
          unit: 'KG',
          rawOcrQuantity: 244.0,
          confirmedAt: DateTime.now(),
        ),
      ];

      // Integration: confirmed OCR product is added if not yet in tray
      for (final scan in confirmedOcr) {
        if (!availableFromTray.any((p) => p.productName.trim().toLowerCase() == scan.description.trim().toLowerCase())) {
          availableFromTray.add(DispatchAvailableProductModel(
            productCode: scan.productCode,
            productName: scan.description,
            uom: scan.unit.toLowerCase(),
            grade: 'STANDARD',
            category: 'CHOCOLATE',
            totalAvailable: 0.0,
            batchCount: 0,
          ));
        }
      }

      // Sorted alphabetically
      availableFromTray.sort((a, b) => a.productName.toLowerCase().compareTo(b.productName.toLowerCase()));

      expect(availableFromTray.length, 2);
      expect(availableFromTray[0].productName, 'Milk Chocolate Bar');
      expect(availableFromTray[1].productName, 'White bar');
      expect(availableFromTray[1].productCode, 'TRAY-WHITE-BAR');
    });
  });
}
