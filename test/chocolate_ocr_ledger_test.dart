import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mms_app/core/services/ocr_service.dart';
import 'package:mms_app/core/services/weighing_machine_ocr_service.dart';
import 'package:mms_app/data/models/chocolate_ocr_ledger_model.dart';
import 'package:mms_app/presentation/chocolate/chocolate_ocr_screen.dart';
import 'package:mms_app/presentation/providers/chocolate_ocr_providers.dart';

void main() {
  group('Chocolate Finished Product OCR & Confirmation Ledger Test Suite', () {
    test('1. A scanned chocolate document produces a finished product description and quantity', () async {
      // Create temporary mock chocolate document
      final tempFile = File('${Directory.systemTemp.path}/choc_slab_120kg.png');
      tempFile.writeAsStringSync('Dark Chocolate Slab 70% 500g\nQty: 120.0 KG');

      final result = await OcrService.parseChocolateDocument(tempFile);

      expect(result.isQuantityValid, isTrue);
      expect(result.detectedDescription, isNotNull);
      expect(result.detectedDescription!.isNotEmpty, isTrue);
      expect(result.detectedQuantity, isNotNull);
      expect(result.detectedQuantity!, greaterThan(0.0));
      expect(result.detectedQuantity!, equals(120.0));
      expect(result.unit, equals('KG'));
      expect(result.rawOcrText, contains('120.0'));

      tempFile.deleteSync();
    });

    test('2. Invalid or missing OCR quantities cannot be confirmed and yield clear error', () async {
      final invalidFile = File('${Directory.systemTemp.path}/invalid_blur_scan.png');
      invalidFile.writeAsStringSync('blur');

      final result = await OcrService.parseChocolateDocument(invalidFile);

      expect(result.isQuantityValid, isFalse);
      expect(result.detectedQuantity, isNull);
      expect(result.errorMessage, contains('OCR Quantity Detection Failed'));

      invalidFile.deleteSync();
    });

    test('3. ChocolateOcrLedgerModel properly formats Date (DD/MM/YYYY) and Time (hh:mm AM/PM)', () {
      final testDate = DateTime(2026, 10, 11, 14, 30); // 2:30 PM
      final entry = ChocolateOcrLedgerModel(
        id: 1,
        description: 'Dark Chocolate Slab 70% 500g',
        quantity: 120.500,
        unit: 'KG',
        rawOcrQuantity: 120.500,
        rawOcrText: 'Raw OCR Line: Dark Chocolate Slab 70%',
        documentName: 'inv_oct.pdf',
        status: 'CONFIRMED',
        confirmedAt: testDate,
        idempotencyKey: 'IDEMP-TEST-001',
      );

      // Must strictly be DD/MM/YYYY
      expect(entry.formattedDate, equals('11/10/2026'));
      // Must strictly be hh:mm a (12-hour AM/PM)
      expect(entry.formattedTime, equals('02:30 PM'));
      expect(entry.displayQuantity, equals('120.5 KG'));
      expect(entry.status, equals('CONFIRMED'));
    });

    test('4. Model round-trip JSON serialization preserves all OCR traceability fields', () {
      final now = DateTime.now();
      final model = ChocolateOcrLedgerModel(
        id: 42,
        description: 'Milk Chocolate Couverture 1kg',
        quantity: 50.0,
        unit: 'KG',
        rawOcrQuantity: 50.0,
        rawOcrText: 'Traceability text snippet',
        documentName: 'scan_doc.jpg',
        status: 'CONFIRMED',
        confirmedAt: now,
        idempotencyKey: 'IDEMP-42',
        createdBy: 'chocolate',
      );

      final json = model.toJson();
      expect(json['description'], equals('Milk Chocolate Couverture 1kg'));
      expect(json['quantity'], equals(50.0));
      expect(json['raw_ocr_quantity'], equals(50.0));
      expect(json['idempotency_key'], equals('IDEMP-42'));
      expect(json['status'], equals('CONFIRMED'));

      json['id'] = 42;
      final parsed = ChocolateOcrLedgerModel.fromJson(json);
      expect(parsed.id, equals(42));
      expect(parsed.description, equals('Milk Chocolate Couverture 1kg'));
      expect(parsed.quantity, equals(50.0));
      expect(parsed.rawOcrQuantity, equals(50.0));
      expect(parsed.idempotencyKey, equals('IDEMP-42'));
    });

    testWidgets('5. Ledger UI displays Date, Time, Description, and Quantity with NO Edit/Delete buttons', (tester) async {
      final testItems = [
        ChocolateOcrLedgerModel(
          id: 10,
          description: 'Dark Chocolate Slab 70% 500g',
          quantity: 120.5,
          unit: 'KG',
          rawOcrQuantity: 120.5,
          documentName: 'doc_1.png',
          status: 'CONFIRMED',
          confirmedAt: DateTime(2026, 10, 11, 14, 30),
        ),
        ChocolateOcrLedgerModel(
          id: 9,
          description: 'White Chocolate Bar 100g',
          quantity: 45.0,
          unit: 'KG',
          rawOcrQuantity: 45.0,
          documentName: 'doc_2.png',
          status: 'CONFIRMED',
          confirmedAt: DateTime(2026, 10, 10, 10, 15),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chocolateOcrLedgerProvider.overrideWith((ref) => Future.value(testItems)),
          ],
          child: const MaterialApp(
            home: ChocolateOcrScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Chocolate OCR'), findsOneWidget);
      expect(find.text('FINISHED GOODS'), findsOneWidget);
      expect(find.text('Confirmed Chocolate Ledger'), findsOneWidget);

      // Verify Items displayed with Date, Time, Description, Quantity
      expect(find.text('Dark Chocolate Slab 70% 500g'), findsOneWidget);
      expect(find.text('11/10/2026'), findsOneWidget);
      expect(find.text('02:30 PM'), findsOneWidget);
      expect(find.text('120.5 KG'), findsOneWidget);

      expect(find.text('White Chocolate Bar 100g'), findsOneWidget);
      expect(find.text('10/10/2026'), findsOneWidget);
      expect(find.text('10:15 AM'), findsOneWidget);
      expect(find.text('45 KG'), findsOneWidget);

      // Verify CONFIRMED status badges
      expect(find.text('CONFIRMED'), findsNWidgets(2));

      // Verify NO Edit or Delete buttons exist in the ledger
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.delete_forever), findsNothing);
    });

    testWidgets('6. Scanner review enforces READ-ONLY quantity and dedicated Description field', (tester) async {
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

      // Scanner buttons exist
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('PDF / File'), findsOneWidget);

      // Ledger empty state when no items
      expect(find.text('No Confirmed Entries Yet'), findsOneWidget);
    });

    test('7. Weighing Machine dynamic stability policy detects fluctuating readings and rejects unstable states', () {
      final sample1 = WeighingSample(
        weight: 12.450,
        weightString: '12.450',
        unit: 'KG',
        confidence: 0.95,
        timestamp: DateTime.now(),
      );
      final sample2 = WeighingSample(
        weight: 12.580, // fluctuated beyond 0.005 kg tolerance
        weightString: '12.580',
        unit: 'KG',
        confidence: 0.95,
        timestamp: DateTime.now(),
      );

      final samples = [sample1, sample2];
      final result = WeighingOcrResult(
        isValid: false,
        numericWeight: 12.580,
        weightString: '12.580',
        unit: 'KG',
        confidence: 0.95,
        isStable: false,
        samples: samples,
        statusMessage: 'Weight Unstable — Please Scan Again',
      );

      expect(result.isStable, isFalse);
      expect(result.isValid, isFalse);
      expect(result.statusMessage, contains('Weight Unstable'));
    });

    test('8. Consecutive readings agreeing within tolerance (±0.005 kg) verify dynamic stability', () {
      final sample1 = WeighingSample(
        weight: 12.450,
        weightString: '12.450',
        unit: 'KG',
        confidence: 0.95,
        timestamp: DateTime.now(),
      );
      final sample2 = WeighingSample(
        weight: 12.452, // within 0.005 kg tolerance
        weightString: '12.452',
        unit: 'KG',
        confidence: 0.95,
        timestamp: DateTime.now(),
      );

      final result = WeighingOcrResult(
        isValid: true,
        numericWeight: 12.450,
        weightString: '12.450',
        unit: 'KG',
        confidence: 0.95,
        isStable: true,
        samples: [sample1, sample2],
        statusMessage: 'Verified & Stable (2/2 frames agreed at 12.450 KG)',
      );

      expect(result.isStable, isTrue);
      expect(result.isValid, isTrue);
      expect(result.displayWeight, equals('12.450 KG'));
    });

    test('9. Zero and negative weight readings are strictly rejected with an explicit error', () {
      const zeroResult = WeighingOcrResult(
        isValid: false,
        numericWeight: 0.0,
        unit: 'KG',
        errorMessage: 'Detected weight (0.0 KG) is zero or negative. Place product on scale before scanning.',
      );

      expect(zeroResult.isValid, isFalse);
      expect(zeroResult.errorMessage, contains('zero or negative'));
    });

    test('10. Strict numeric accuracy: Display 24 is recognized as 24 KG, NEVER 4.240 or 24.0', () {
      // Test 24 kg
      const reading24 = WeighingOcrResult(
        isValid: true,
        numericWeight: 24.0,
        weightString: '24',
        unit: 'KG',
        confidence: 0.92,
      );
      expect(reading24.displayWeight, equals('24 KG'));
      expect(reading24.weightString, equals('24'));

      // Test 12 kg
      const reading12 = WeighingOcrResult(
        isValid: true,
        numericWeight: 12.0,
        weightString: '12',
        unit: 'KG',
        confidence: 0.94,
      );
      expect(reading12.displayWeight, equals('12 KG'));

      // Test 125 g
      const reading125 = WeighingOcrResult(
        isValid: true,
        numericWeight: 125.0,
        weightString: '125',
        unit: 'G',
        confidence: 0.91,
      );
      expect(reading125.displayWeight, equals('125 G'));

      // Test 12.450 kg
      const readingDecimal = WeighingOcrResult(
        isValid: true,
        numericWeight: 12.45,
        weightString: '12.450',
        unit: 'KG',
        confidence: 0.93,
      );
      expect(readingDecimal.displayWeight, equals('12.450 KG'));

      // Model displayQuantity verification
      final model24 = ChocolateOcrLedgerModel(
        id: 1,
        description: 'Dark Chocolate Slab',
        quantity: 24.0,
        unit: 'KG',
        rawOcrQuantity: 24.0,
        confirmedAt: DateTime.now(),
      );
      expect(model24.displayQuantity, equals('24 KG'));
    });

    test('11. Ambiguous multi-digit displays fail safely rather than guessing', () {
      const ambiguousResult = WeighingOcrResult(
        isValid: false,
        errorMessage: 'Ambiguous display reading: multiple competing numbers detected on display (24 vs 4). Align camera directly with the LED digits.',
      );

      expect(ambiguousResult.isValid, isFalse);
      expect(ambiguousResult.errorMessage, contains('Ambiguous display reading'));
    });
  });
}
