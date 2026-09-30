import 'package:flutter_test/flutter_test.dart';

class TestBatch {
  final String id;
  final String batchNo;
  double availableQuantity;
  final DateTime receivedDate;

  TestBatch({
    required this.id,
    required this.batchNo,
    required this.availableQuantity,
    required this.receivedDate,
  });
}

class TestAllocation {
  final String batchId;
  final double quantityDeducted;

  TestAllocation({required this.batchId, required this.quantityDeducted});
}

/// Simulation of atomic create_dispatch_fifo logic matching PostgreSQL functions.sql
List<TestAllocation> simulateFifoDispatch(List<TestBatch> sortedBatches, double requestedQty) {
  final allocations = <TestAllocation>[];
  var remaining = requestedQty;

  for (final batch in sortedBatches) {
    if (remaining <= 0) break;
    if (batch.availableQuantity <= 0) continue;

    final deduct = (batch.availableQuantity >= remaining) ? remaining : batch.availableQuantity;
    batch.availableQuantity -= deduct;
    remaining -= deduct;

    allocations.add(TestAllocation(batchId: batch.id, quantityDeducted: deduct));
  }

  if (remaining > 0.0001) {
    throw Exception('Insufficient total stock across active batches. Shortfall: $remaining');
  }

  return allocations;
}

/// Simulation of atomic delete_dispatch restoring batch quantities
void simulateFifoReversal(List<TestBatch> batches, List<TestAllocation> allocations) {
  for (final alloc in allocations) {
    final batch = batches.firstWhere((b) => b.id == alloc.batchId);
    batch.availableQuantity += alloc.quantityDeducted;
  }
}

void main() {
  group('FIFO Dispatch Logic Tests (Prompt Section 73)', () {
    test('Critical FIFO Test: 180 kg across Batches A (100kg), B (150kg), C (200kg)', () {
      final batches = [
        TestBatch(id: 'A', batchNo: 'BATCH-A', availableQuantity: 100.0, receivedDate: DateTime(2026, 1, 1)),
        TestBatch(id: 'B', batchNo: 'BATCH-B', availableQuantity: 150.0, receivedDate: DateTime(2026, 1, 2)),
        TestBatch(id: 'C', batchNo: 'BATCH-C', availableQuantity: 200.0, receivedDate: DateTime(2026, 1, 3)),
      ];

      // Dispatch 180 kg
      final allocations = simulateFifoDispatch(batches, 180.0);

      expect(allocations.length, 2);
      expect(allocations[0].batchId, 'A');
      expect(allocations[0].quantityDeducted, 100.0);
      expect(allocations[1].batchId, 'B');
      expect(allocations[1].quantityDeducted, 80.0);

      // Verify batch quantities after FIFO consumption
      expect(batches[0].availableQuantity, 0.0);
      expect(batches[1].availableQuantity, 70.0);
      expect(batches[2].availableQuantity, 200.0);

      // Verify dispatch reversal restores exact quantities
      simulateFifoReversal(batches, allocations);
      expect(batches[0].availableQuantity, 100.0);
      expect(batches[1].availableQuantity, 150.0);
      expect(batches[2].availableQuantity, 200.0);
    });

    test('Throws exception when requested dispatch exceeds total available inventory', () {
      final batches = [
        TestBatch(id: 'A', batchNo: 'BATCH-A', availableQuantity: 50.0, receivedDate: DateTime(2026, 1, 1)),
      ];

      expect(() => simulateFifoDispatch(batches, 100.0), throwsA(isA<Exception>()));
    });

    test('Exact single batch deduction leaves other batches untouched', () {
      final batches = [
        TestBatch(id: 'A', batchNo: 'BATCH-A', availableQuantity: 100.0, receivedDate: DateTime(2026, 1, 1)),
        TestBatch(id: 'B', batchNo: 'BATCH-B', availableQuantity: 150.0, receivedDate: DateTime(2026, 1, 2)),
      ];

      final allocations = simulateFifoDispatch(batches, 50.0);
      expect(allocations.length, 1);
      expect(allocations[0].batchId, 'A');
      expect(allocations[0].quantityDeducted, 50.0);
      expect(batches[0].availableQuantity, 50.0);
      expect(batches[1].availableQuantity, 150.0);
    });
  });
}
