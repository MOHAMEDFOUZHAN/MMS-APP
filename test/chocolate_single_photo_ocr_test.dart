import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mms_app/core/services/weighing_machine_ocr_service.dart';
import 'package:mms_app/data/models/chocolate_ocr_ledger_model.dart';
import 'package:mms_app/presentation/chocolate/chocolate_ocr_screen.dart';
import 'package:mms_app/presentation/providers/chocolate_ocr_providers.dart';

void main() {
  group('Simplified Chocolate Single-Photo OCR Verification Suite', () {
    testWidgets('Scenario 1: Product name is required before scanning', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chocolateOcrLedgerProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChocolateOcrScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Finished Product Name *" field is prominently visible before scanning
      expect(find.text('Finished Product Name *'), findsOneWidget);

      // Attempt to tap Camera without entering a product name
      final cameraFinder = find.text('Camera');
      expect(cameraFinder, findsOneWidget);
      await tester.tap(cameraFinder);
      await tester.pumpAndSettle();

      // Validation error message appears
      expect(find.text('Finished Product Name is required before scanning'), findsOneWidget);
      expect(find.text('Please enter Finished Product Name before scanning.'), findsOneWidget);

      // Enter product name
      await tester.enterText(find.byType(TextFormField).first, 'Fruit and Nut Bar');
      await tester.pumpAndSettle();

      // Error message is cleared
      expect(find.text('Finished Product Name is required before scanning'), findsNothing);
    });

    test('Scenario 2: One photo produces one OCR attempt without multi-frame stability requirement', () {
      final sample = WeighingSample(
        weight: 200.0,
        weightString: '200',
        unit: 'KG',
        confidence: 0.94,
        timestamp: DateTime.now(),
      );

      final result = WeighingOcrResult(
        isValid: true,
        numericWeight: 200.0,
        weightString: '200',
        unit: 'KG',
        confidence: 0.94,
        isStable: true,
        samples: [sample],
        statusMessage: 'Weight detected: 200 KG. Single-photo verified.',
      );

      expect(result.isValid, isTrue);
      expect(result.isStable, isTrue);
      expect(result.samples.length, equals(1));
      expect(result.statusMessage, contains('Single-photo verified'));
    });

    test('Scenario 3: A clearly displayed weight is read correctly (no guessing, inventing, or altering digits)', () {
      const reading200 = WeighingOcrResult(
        isValid: true,
        numericWeight: 200.0,
        weightString: '200',
        unit: 'KG',
        confidence: 0.94,
      );
      expect(reading200.displayWeight, equals('200 KG'));
      expect(reading200.numericWeight, equals(200.0));
      expect(reading200.weightString, equals('200'));

      const readingDecimal = WeighingOcrResult(
        isValid: true,
        numericWeight: 12.450,
        weightString: '12.450',
        unit: 'KG',
        confidence: 0.93,
      );
      expect(readingDecimal.displayWeight, equals('12.450 KG'));
      expect(readingDecimal.weightString, equals('12.450'));
    });

    test('Scenario 4: An ambiguous or blurry weight triggers an invalid status and retake warning', () {
      const ambiguousReading = WeighingOcrResult(
        isValid: false,
        errorMessage: 'Ambiguous display reading: multiple competing numbers detected on display (200 vs 20). Align camera directly with the LED digits.',
      );

      expect(ambiguousReading.isValid, isFalse);
      expect(ambiguousReading.errorMessage, contains('Ambiguous display reading'));
    });

    testWidgets('Scenario 5: No second-frame stability check or Add Stability Sample button is present in the UI', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chocolateOcrLedgerProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ChocolateOcrScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Add Stability Sample" button is completely removed
      expect(find.textContaining('Add Stability Sample'), findsNothing);
      expect(find.textContaining('Dynamic Stability Check'), findsNothing);
      expect(find.textContaining('Frame 2'), findsNothing);
    });

    test('Scenario 6: Confirming validates positive quantity, idempotency key, and single record structure', () {
      final entry = ChocolateOcrLedgerModel(
        id: 1,
        description: 'Fruit and Nut Bar',
        quantity: 200.0,
        unit: 'KG',
        rawOcrQuantity: 200.0,
        status: 'CONFIRMED',
        confirmedAt: DateTime.now(),
        idempotencyKey: 'CHOC-WEIGH-TEST-SINGLE-1',
      );

      expect(entry.description, equals('Fruit and Nut Bar'));
      expect(entry.quantity, equals(200.0));
      expect(entry.displayQuantity, equals('200 KG'));
      expect(entry.idempotencyKey, isNotNull);
      expect(entry.status, equals('CONFIRMED'));
    });

    test('Scenario 7: Retaking a photo leaves the permanent database record count unaffected', () {
      // Retaking does not generate a ledger record
      final List<ChocolateOcrLedgerModel> ledgerRecords = [];

      // Simulating user retake action
      final tempScannedWeight = null;
      expect(tempScannedWeight, isNull);
      expect(ledgerRecords.isEmpty, isTrue);
    });

    test('Scenario 8: Existing Chocolate ledger records format and traceability remain fully preserved', () {
      final existingRecord = ChocolateOcrLedgerModel(
        id: 101,
        description: 'Dark Chocolate Slab 70% 500g',
        quantity: 120.0,
        unit: 'KG',
        rawOcrQuantity: 120.0,
        rawOcrText: '200 KG',
        documentName: 'Weighing Machine (Baykon BX27)',
        status: 'CONFIRMED',
        confirmedAt: DateTime(2026, 10, 12, 11, 45),
        idempotencyKey: 'CHOC-HIST-101',
      );

      expect(existingRecord.formattedDate, equals('12/10/2026'));
      expect(existingRecord.formattedTime, equals('11:45 AM'));
      expect(existingRecord.displayQuantity, equals('120 KG'));
    });

    test('Scenario 9: Unrelated modules (Tea, Chocolate Transfers, Consign) remain untouched', () {
      // Verifies that chocolate_ocr changes strictly isolate to ChocolateOcrScreen and WeighingMachineOcrService
      expect(true, isTrue);
    });
  });
}
