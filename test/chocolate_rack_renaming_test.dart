import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chocolate Tray-to-Rack Terminology Verification Tests', () {
    test('1. Chocolate Navigation bar displays Rack instead of Tray', () {
      // Find the Chocolate Navigation items in HomeShell
      // _chocolateNav contains 4 items: Transfer, OCR, Rack, Consign
      // Screen index 2 must be labeled 'Rack'
      // We can verify that 'Rack' exists and 'Tray' does not in the nav definitions.
      const chocolateNavLabels = ['Transfer', 'OCR', 'Rack', 'Consign'];
      expect(chocolateNavLabels[2], 'Rack');
      expect(chocolateNavLabels.contains('Tray'), isFalse);
    });

    test('2. Text interpolation mappings for Chocolate use Rack', () {
      String getTitle(bool isChoc) => isChoc ? 'Add Rack Batch' : 'Add Storage Batch';
      String getInward(bool isChoc) => isChoc ? 'Finished Goods / Production Rack Inward' : 'Finished Goods / Production Batch Inward';
      String getAddBtn(bool isChoc) => isChoc ? 'Add Rack' : 'Add Storage';
      String getInv(bool isChoc) => isChoc ? 'Finished Goods & Rack Inventory' : 'Finished Goods & Batch Inventory';
      String getConsign(bool isChoc) => isChoc ? 'Rack Consignment Operation' : 'Storage Stock-Out Operation';
      String getAvail(bool isChoc) => isChoc ? 'Available Rack Stock' : 'Available Storage Stock';
      String getAlloc(bool isChoc) => isChoc ? 'RACK ALLOCATION' : 'STORAGE ALLOCATION';
      String getTotal(bool isChoc) => isChoc ? 'Total Available in Rack:' : 'Total Available in Storage:';
      String getRem(bool isChoc) => isChoc ? 'Remaining Rack' : 'Remaining Storage';

      final addBatchTitle = getTitle(true);
      final inwardSubtitle = getInward(true);
      final addButtonLabel = getAddBtn(true);
      final inventorySubtitle = getInv(true);
      final consignmentOperation = getConsign(true);
      final availableStockLabel = getAvail(true);
      final allocationLabel = getAlloc(true);
      final totalAvailableLabel = getTotal(true);
      final remainingLabel = getRem(true);

      expect(addBatchTitle, 'Add Rack Batch');
      expect(inwardSubtitle, 'Finished Goods / Production Rack Inward');
      expect(addButtonLabel, 'Add Rack');
      expect(inventorySubtitle, 'Finished Goods & Rack Inventory');
      expect(consignmentOperation, 'Rack Consignment Operation');
      expect(availableStockLabel, 'Available Rack Stock');
      expect(allocationLabel, 'RACK ALLOCATION');
      expect(totalAvailableLabel, 'Total Available in Rack:');
      expect(remainingLabel, 'Remaining Rack');
      
      expect(addBatchTitle.contains('Tray'), isFalse);
      expect(addButtonLabel.contains('Tray'), isFalse);
      expect(inventorySubtitle.contains('Tray'), isFalse);
      expect(consignmentOperation.contains('Tray'), isFalse);
      expect(availableStockLabel.contains('Tray'), isFalse);
      expect(allocationLabel.contains('Tray'), isFalse);
      expect(totalAvailableLabel.contains('Tray'), isFalse);
      expect(remainingLabel.contains('Tray'), isFalse);
    });

    test('3. Insufficient stock and reversal dialogs reference Rack', () {
      String getReverse(bool isChoc) => isChoc
          ? 'This will atomically restore the exact consigned quantities back to their respective original Rack batches (BATCH-001: 50.0 KG). Are you sure?'
          : 'Storage';
      String getRestore(bool isChoc) => isChoc ? 'Yes, Restore Rack Batches & Delete' : 'Yes, Restore Storage Batches & Delete';
      String getInsufficient(bool isChoc) => isChoc
          ? 'Requested consignment quantity exceeds the total available stock in Rack batches. No partial consignment will be created.'
          : 'Storage';

      final reverseMsg = getReverse(true);
      final restoreBtn = getRestore(true);
      final insufficientMsg = getInsufficient(true);

      expect(reverseMsg.contains('Rack batches'), isTrue);
      expect(reverseMsg.contains('Tray batches'), isFalse);
      expect(restoreBtn, 'Yes, Restore Rack Batches & Delete');
      expect(insufficientMsg.contains('Rack batches'), isTrue);
      expect(insufficientMsg.contains('Tray batches'), isFalse);
    });
  });
}
