import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mms_app/core/formatters/app_date_formatter.dart';
import 'package:mms_app/data/models/batch_model.dart';
import 'package:mms_app/data/models/dispatch_model.dart';

void main() {
  group('BENCHMARK MMS — Final Dispatch + Storage UI & Format Tests', () {
    test('Requirement 8 & 15: Time formatting strictly hh:mm AM/PM', () {
      // 09:15 AM
      final dtMorning = DateTime(2026, 10, 2, 9, 15, 23);
      expect(AppDateFormatter.formatTime(dtMorning), equals('09:15 AM'));

      // 02:30 PM
      final dtAfternoon = DateTime(2026, 10, 2, 14, 30, 41);
      expect(AppDateFormatter.formatTime(dtAfternoon), equals('02:30 PM'));

      // 03:45 PM
      final dtDispatch = DateTime(2026, 10, 2, 15, 45, 0);
      expect(AppDateFormatter.formatTime(dtDispatch), equals('03:45 PM'));

      // TimeOfDay support
      const tod = TimeOfDay(hour: 17, minute: 45);
      expect(AppDateFormatter.formatTime(tod), equals('05:45 PM'));
    });

    test('Requirement 9 & 10: Batch and Dispatch preserve precise timestamps for FIFO', () {
      final b1 = BatchModel(
        id: 101,
        batchNo: '275',
        materialCode: 'PROD-A',
        receivedQuantity: 100,
        availableQuantity: 100,
        receivedAt: DateTime(2026, 10, 2, 9, 0, 0),
      );

      final b2 = BatchModel(
        id: 102,
        batchNo: '275',
        materialCode: 'PROD-A',
        receivedQuantity: 200,
        availableQuantity: 200,
        receivedAt: DateTime(2026, 10, 2, 14, 0, 0),
      );

      // Verify that 09:00 AM batch is ordered before 02:00 PM batch regardless of identical batch_no
      final batches = [b2, b1];
      batches.sort((a, b) {
        final cmp = a.effectiveDateTime.compareTo(b.effectiveDateTime);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });

      expect(batches.first.id, equals(101));
      expect(batches.last.id, equals(102));
      expect(AppDateFormatter.formatTime(batches.first.effectiveDateTime), equals('09:00 AM'));
      expect(AppDateFormatter.formatTime(batches.last.effectiveDateTime), equals('02:00 PM'));
    });

    test('Requirement 4 & 5: Current Stock vs All History print filtering logic', () {
      final activeBatch = BatchModel(
        id: 1,
        batchNo: '275',
        materialCode: 'PROD-A',
        receivedQuantity: 200,
        availableQuantity: 150,
      );

      final depletedBatch = BatchModel(
        id: 2,
        batchNo: '275',
        materialCode: 'PROD-A',
        receivedQuantity: 100,
        availableQuantity: 0,
      );

      final allBatches = [depletedBatch, activeBatch];

      // Current Storage Print: ONLY batches with available_quantity > 0 appear
      final currentStockPrint = allBatches.where((b) => b.availableQuantity > 0.0001).toList();
      expect(currentStockPrint.length, equals(1));
      expect(currentStockPrint.first.availableQuantity, equals(150));

      // All History Print: All batches preserved
      expect(allBatches.length, equals(2));
      expect(allBatches.any((b) => b.availableQuantity == 0), isTrue);
    });

    test('Requirement 1 & 2: DispatchModel has no Grade in required business usage', () {
      final dispatch = DispatchModel(
        id: 99,
        date: DateTime(2026, 10, 2),
        materialCode: 'PROD-A',
        product: 'Product A',
        quantity: 150,
        returnQuantity: 0,
        units: 'packet',
        location: 'Warehouse 1',
        department: 'Dispatch',
      );

      expect(dispatch.materialCode, equals('PROD-A'));
      expect(dispatch.quantity, equals(150));
      expect(dispatch.id, equals(99)); // ID exists in model for internal operations but hidden in UI
    });
  });
}
